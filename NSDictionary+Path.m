#import "NSDictionary+Path.h"

@implementation NSDictionary (File)
+ (instancetype) dictionaryWithFile:(NSString *) path {
  if (@available(iOS 11, *)) return [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
  return [NSDictionary dictionaryWithContentsOfFile:path];
}
@end