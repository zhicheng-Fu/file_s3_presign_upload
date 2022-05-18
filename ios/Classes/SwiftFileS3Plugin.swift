import Flutter
import UIKit
import AWSS3
import AWSCore
import UIKit

public class SwiftFileS3Plugin: NSObject, FlutterPlugin {
    
    public final var contentType: String = "application/octet-stream";
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.arcadedevhouse.aws/file_s3", binaryMessenger: registrar.messenger())
        let instance = SwiftFileS3Plugin()
        let accessKey = Bundle.main.object(forInfoDictionaryKey: "aws_access_key") as! String;
        let secretKey = Bundle.main.object(forInfoDictionaryKey: "aws_secret_key") as! String;
        _ = AWSCredentials.init(accessKey: accessKey, secretKey: secretKey, sessionKey: nil, expiration: nil);
        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let configuration = AWSServiceConfiguration.init(region: AWSRegionType.APSoutheast2, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "uploadSingle":
            self.uploadSingle(call, result: result);
        case "uploadMult":
            self.uploadMult(call, result: result);
        default:
            fatalError("No such method.");
        }
        
    }
    
    func renameFile(ext: String, prefix: String?) -> Dictionary<String, String?> {
        let uuid = UUID.init().uuidString;
        let fullName: String;
        if (prefix == nil || prefix?.count == 0) {
            fullName = uuid +  "." + ext;
        } else {
            fullName = prefix! + "/" + uuid + "." + ext;
        }
        return ["uuid": uuid, "fullName":  fullName];
    }
    
    func preSignFile(dic: Dictionary<String, String?>, bucketName: String) -> String {
        let fullName = dic["fullName"]!!;
        let awsS3GetPreSignedURLRequest = AWSS3GetPreSignedURLRequest();
        awsS3GetPreSignedURLRequest.httpMethod = AWSHTTPMethod.PUT;
        awsS3GetPreSignedURLRequest.key = fullName;
        awsS3GetPreSignedURLRequest.bucket = bucketName;
        awsS3GetPreSignedURLRequest.expires = Date(timeIntervalSinceNow: 3600);
        awsS3GetPreSignedURLRequest.contentType = self.contentType;
        var preSignUrl = "";
        AWSS3PreSignedURLBuilder.default().getPreSignedURL(awsS3GetPreSignedURLRequest).continueWith { (task:AWSTask<NSURL>) -> Any? in
            if let error = task.error as NSError? {
                print("Error: \(error)")
                return nil
            }
            preSignUrl = (task.result?.absoluteString)!;
            return nil;
        }
        return preSignUrl;
    }
    
    func upload(data: Data, urlString: String, completion: @escaping (Bool, String?) -> Void) {
        let requestURL = URL(string: urlString)!
        var request = URLRequest(url: requestURL)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(self.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        let task = URLSession.shared.dataTask(with: request, completionHandler: {data, response, error in
            if (error != nil) {
                completion(false, error!.localizedDescription);
                return;
            }
            let httpResponse = response as! HTTPURLResponse;
            if (httpResponse.statusCode != 200) {
                completion(false, httpResponse.description);
                return;
            }
            completion(true, nil);
        })
        task.resume();
    }
    
    func parseFile2Data(encodeFile: Any) -> Data {
        if let base64 = encodeFile as? String {
            return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)!;
        }
        if let unit8 = encodeFile as? FlutterStandardTypedData {
            return Data(unit8.data);
        }
        fatalError("Can not convert file to data.");
    }
    
    public func uploadMult(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
        let argumentList = call.arguments as! Array<Dictionary<String, Any>>;
        let dispatch = DispatchGroup();
        var resultArray: Array<Any> = Array();
        for arguments in argumentList {
            dispatch.enter();
            self.uploadFile(arguments: arguments , completion: { back in
                resultArray.append(back);
                dispatch.leave();
            });
        }
        dispatch.notify(queue: .main, execute: {
            result(resultArray);
        });
    }
    
    public func uploadSingle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Void {
        let arguments = call.arguments as! Dictionary<String, Any>;
        self.uploadFile(arguments: arguments, completion: { back in
            result(back);
        });
    }
    
    public func uploadFile(arguments: Dictionary<String, Any>, completion: @escaping (Any) -> Void) -> Void {
        let prefix = arguments["prefix"] as? String;
        let encodeFile =  arguments["file"];
        let ext = arguments["ext"] as! String;
        let bucket = arguments["bucket"] as! String;
        let newFileProperty = self.renameFile(ext: ext, prefix: prefix);
        let url = self.preSignFile(dic: newFileProperty, bucketName: bucket);
        let data = self.parseFile2Data(encodeFile: encodeFile!);
        self.upload(data: data, urlString: url, completion: {isSuccess, message in
            if (isSuccess) {
                completion(["code": 200, "result":newFileProperty]);
                return;
            }
            completion(["code": 500, "message": message, "result": nil]);
        });
    }
}
