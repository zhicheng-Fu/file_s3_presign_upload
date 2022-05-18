import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

abstract class InvokeParam {
  getFile();

  late final String prefix;

  late final String ext;

  late final String bucket;

  InvokeParam({String? prefix, required String ext, required String bucket}) {
    this.prefix = prefix ?? '';
    this.bucket = bucket;
    this.ext = ext;
  }

  Map<String, dynamic> toMap() {
    return {"prefix": prefix, "ext": this.ext, "bucket": this.bucket, "file": getFile()};
  }
}

class Base64Param extends InvokeParam {
  late final String file;

  Base64Param({String? prefix, required String ext, required String bucket, required String file}) : super(prefix: prefix, ext: ext, bucket: bucket) {
    this.file = file;
  }

  @override
  getFile() {
    return this.file;
  }
}

class Uint8ListParam extends InvokeParam {
  late final Uint8List file;

  Uint8ListParam({String? prefix, required String ext, required String bucket, required Uint8List file}) : super(prefix: prefix, ext: ext, bucket: bucket) {
    this.file = file;
  }

  @override
  getFile() {
    return this.file;
  }
}

class Response {
  late final int code;

  late final ExecuteResult? result;

  late final String? message;

  Response({required int code, ExecuteResult? result, String? message}) {
    this.code = code;
    this.result = result;
    this.message = message;
  }

  static Response fromInvokeResult(dynamic value) {
    return Response(code: value["code"], message: value["message"], result: ExecuteResult.fromInvokeResult(value["result"]));
  }

  @override
  String toString() {
    return "<<Response: {code: $code, msessage: $message, result: $result}>>";
  }
}

class ExecuteResult {
  late final String uuid;

  late final String fullName;

  ExecuteResult({required String uuid, required String fullName}) {
    this.uuid = uuid;
    this.fullName = fullName;
  }

  static ExecuteResult? fromInvokeResult(dynamic value) {
    if (value == null) {
      return null;
    }
    return ExecuteResult(uuid: value["uuid"], fullName: value["fullName"]);
  }

  @override
  String toString() {
    return "<<ExecuteResult: {uuid: $uuid, fullName: $fullName>>";
  }
}

class FileS3 {
  static const MethodChannel _channel = const MethodChannel('com.arcadedevhouse.aws/file_s3');

  static Future<Response> uploadSignle(InvokeParam invokeParam) {
    return _channel.invokeMethod("uploadSingle", invokeParam.toMap()).then((value) => Response.fromInvokeResult(value));
  }

  static Future<List<Response>> uploadMult(List<InvokeParam> invokeParam) {
    return _channel.invokeListMethod("uploadMult", invokeParam.map((e) => e.toMap()).toList()).then((value) => value!.map((e) => Response.fromInvokeResult(e)).toList());
  }
}
