extern NSString *const PLFilterKey;

@interface NSDictionary (libprefs)
+ (NSDictionary *)dictionaryWithFile:(NSString *)path;
@end

@interface PSSpecifier (libprefs)
+ (BOOL)environmentPassesPreferenceLoaderFilter:(NSDictionary *)filter;
@property (nonatomic, retain, readonly) NSBundle *preferenceLoaderBundle;
@end

@interface PSListController (libprefs)
- (NSArray *)specifiersFromEntry:(NSDictionary *)entry sourcePreferenceLoaderBundlePath:(NSString *)sourceBundlePath title:(NSString *)title;
@end

@interface SimpleBundleController : PSListController
@end
