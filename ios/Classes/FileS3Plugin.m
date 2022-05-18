#import "FileS3Plugin.h"
#if __has_include(<file_s3/file_s3-Swift.h>)
#import <file_s3/file_s3-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "file_s3-Swift.h"
#endif

@implementation FileS3Plugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFileS3Plugin registerWithRegistrar:registrar];
}
@end
