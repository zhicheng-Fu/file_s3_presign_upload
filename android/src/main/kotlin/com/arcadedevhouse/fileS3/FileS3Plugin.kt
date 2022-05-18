package com.arcadedevhouse.fileS3

import android.content.Context
import android.content.pm.PackageManager
import android.util.Base64
import androidx.annotation.NonNull
import com.amazonaws.HttpMethod
import com.amazonaws.auth.BasicAWSCredentials
import com.amazonaws.http.HttpHeader
import com.amazonaws.regions.Region
import com.amazonaws.services.s3.AmazonS3Client
import com.amazonaws.services.s3.model.GeneratePresignedUrlRequest
import com.amazonaws.services.s3.util.Mimetypes
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import okhttp3.*
import java.io.File
import java.io.IOException
import java.net.URL
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.ThreadPoolExecutor
import kotlin.collections.ArrayList


/** FileS3Plugin */
class FileS3Plugin : FlutterPlugin, MethodCallHandler {

    companion object {
        var META_ACCESS_KEY_NAME = "aws_access_key"

        var META_SECRET_KEY_NAME = "aws_secret_key"
    }

    private lateinit var accessKey: String

    private lateinit var secretKey: String

    private lateinit var channel: MethodChannel

    private lateinit var s3Client: AmazonS3Client

    private val executor = Executors.newFixedThreadPool(2) as ThreadPoolExecutor

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        this.channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.arcadedevhouse.aws/file_s3")
        this.initAWSCredentials(flutterPluginBinding.applicationContext);
        this.s3Client = AmazonS3Client(BasicAWSCredentials(this.accessKey, this.secretKey), Region.getRegion("ap-southeast-2"))
        this.channel.setMethodCallHandler(this)
    }

    private fun initAWSCredentials(applicationContext: Context) {
        val app = applicationContext.packageManager.getApplicationInfo(applicationContext.packageName, PackageManager.GET_META_DATA)
        val bundle = app.metaData
        this.accessKey = bundle.getString(META_ACCESS_KEY_NAME)!!
        this.secretKey = bundle.getString(META_SECRET_KEY_NAME)!!
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        executor.submit {
            when (call.method) {
                "uploadSingle" -> this.uploadSingle(call, result)
                "uploadMult" -> this.uploadMult(call, result);
                else -> result.notImplemented()
            }
        }
    }

    private fun uploadMult(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val resultArray: ArrayList<Any> = ArrayList()
        val countDownLatch = CountDownLatch(arguments.size);
        for (argument in arguments) {
            this.uploadFile(argument as Map<*, *>) { back ->
                resultArray.add(back)
                countDownLatch.countDown()
            }
        }
        countDownLatch.await()
        result.success(resultArray)
    }

    private fun uploadSingle(call: MethodCall, result: Result) {
        val arguments = call.arguments as Map<*, *>
        val countDownLatch = CountDownLatch(1);
        var resultBack: Any? = null;
        this.uploadFile(arguments) { back: Any ->
            resultBack = back;
            countDownLatch.countDown();
        }
        countDownLatch.await();
        result.success(resultBack)
    }

    private fun uploadFile(arguments: Map<*, *>, completion: (Any) -> Unit) {
        val prefix = arguments["prefix"] as String?
        val encodeFile = arguments["file"]!!
        val ext = arguments["ext"] as String
        val bucket = arguments["bucket"] as String
        val newFileProperty = this.renameFile(ext, prefix)
        val url = this.preSignFile(newFileProperty, bucket)
        val data = this.parseFile2Data(encodeFile)
        this.upload(data, url) { isSuccess: Boolean, message: String? ->
            if (isSuccess) {
                completion(mapOf("code" to 200, "result" to newFileProperty))
                return@upload;
            }
            completion(mapOf("code" to 500, "message" to message))
        }
    }

    private fun upload(data: ByteArray, url: URL, completion: (Boolean, String?) -> Unit) {
        val client = OkHttpClient()
        val request = Request
                .Builder()
                .addHeader(HttpHeader.CONTENT_TYPE, Mimetypes.MIMETYPE_OCTET_STREAM)
                .put(RequestBody.create(contentType = null, content = data, offset = 0, byteCount = data.size))
                .url(url)
                .build()
        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                completion(true, null)
            }

            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    completion(false, response.message)
                    return
                }
                completion(true, null)
            }
        })

    }

    private fun parseFile2Data(encodeFile: Any): ByteArray {
        if (encodeFile is String) {
            return Base64.decode(encodeFile, Base64.DEFAULT)
        }
        if (encodeFile is ByteArray) {
            return encodeFile
        }
        throw RuntimeException("Can not convert file to data.")
    }

    private fun preSignFile(newFileProperty: Map<String, String>, bucket: String): URL {
        val fullName = newFileProperty["fullName"]
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.HOUR, 1);
        return this.s3Client.generatePresignedUrl(GeneratePresignedUrlRequest(bucket, fullName, HttpMethod.PUT)
                .withExpiration(calendar.time))
    }

    private fun renameFile(ext: String, prefix: String?): Map<String, String> {
        val uuid = UUID.randomUUID().toString();
        val fullName = if (prefix == null || prefix.isEmpty()) {
            "$uuid.$ext";
        } else {
            prefix + File.separator + uuid + "." + ext;
        }
        return mapOf("uuid" to uuid, "fullName" to fullName)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
