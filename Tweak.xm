#include <Preferences/PSSpecifier.h>
#include "prefs.h"

@interface UIImage (Private)
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

%hook PSUIPrefsListController

// ok, gonna comment so me from the future doesn't get lost in this :c
- (NSArray *)specifiers {
  // otherwise, it crashes. this is the very first invoke of _specifiers.
  if (MSHookIvar<NSArray *>(self, "_specifiers")) return %orig;

  NSMutableArray *specs = [NSMutableArray new];
  NSString *dir = @"/Library/PreferenceLoader/Preferences";
  // subpathsOfDirectory, unlike contentsOfDirectory, is recursive. commenting this cuz i got confused why this was used in the original and made a ton of костыли
  for (NSString *file in [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:dir error:nil]) {
    if (![file.pathExtension isEqualToString:@"plist"]) continue;

    NSDictionary *entry;
    NSString *path = [dir stringByAppendingPathComponent:file];
    entry = [NSDictionary dictionaryWithFile:path][@"entry"];
    if (!entry) continue;
    if (![PSSpecifier environmentPassesPreferenceLoaderFilter:[entry objectForKey:@"pl_filter"]]) continue;

    PSSpecifier *specifier = [self specifiersFromEntry:entry sourcePreferenceLoaderBundlePath:path.stringByDeletingLastPathComponent title:file.lastPathComponent.stringByDeletingPathExtension][0];
    UIImage *icon = [specifier propertyForKey:@"iconImage"] ? : [UIImage imageWithContentsOfFile:@"/Library/PreferenceLoader/Default.png"];
    if (icon) {
      UIGraphicsBeginImageContextWithOptions(CGSizeMake(29, 29), NO, [UIScreen mainScreen].scale);
      CGRect iconRect = CGRectMake(0, 0, 29, 29);
      NSBundle *mobileIconsBundle = [NSBundle bundleWithIdentifier:@"com.apple.mobileicons.framework"];
      UIImage *mask = [UIImage imageNamed:@"TableIconMask" inBundle:mobileIconsBundle];
      if (mask) CGContextClipToMask(UIGraphicsGetCurrentContext(), iconRect, mask.CGImage);
      //[[UIColor whiteColor] setFill];
      //UIRectFill(iconRect);
      [icon drawInRect:iconRect];
      icon = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();
      [specifier setProperty:icon forKey:@"iconImage"];
    }
    // to prevent crashes check this thing
    if (specifier) [specs addObject:specifier];
  }

  if (specs.count == 0) return %orig;
  [specs sortUsingComparator:^NSComparisonResult(PSSpecifier *a, PSSpecifier *b) {
    return [a.name localizedCaseInsensitiveCompare:b.name];
  }];
  [specs insertObject:[%c(PSSpecifier) emptyGroupSpecifier] atIndex:0];
  NSMutableArray *mutableSpecifiers = [%orig mutableCopy];
  [mutableSpecifiers addObjectsFromArray:specs];
  MSHookIvar<NSArray *>(self, "_specifiers") = mutableSpecifiers;
  return MSHookIvar<NSArray *>(self, "_specifiers");
}

%end

// loading specifiers from the items of a PSSpecifier for PSListController (again, WHO THE SHIT DOES THAT?????)
%hook PSListController

- (NSArray *)specifiers {
  if (MSHookIvar<NSArray *>(self, "_specifiers")) return %orig;
  if (NSArray *items = [self.specifier propertyForKey:@"items"]) {
    exit(0);
    if (items.count == 0) return %orig;
    NSMutableArray *specs = [NSMutableArray new];
    for (NSDictionary *item in items) {
      PSSpecifier *specifier = [self specifiersFromEntry:item sourcePreferenceLoaderBundlePath:nil title:nil][0];
      [specs addObject:specifier];
    }
    if (specs.count != 0) {
      MSHookIvar<NSArray *>(self, "_specifiers") = specs;
      return MSHookIvar<NSArray *>(self, "_specifiers");
    }
  }
  return %orig;
}

%end

%ctor {
  dlopen("/usr/lib/libprefs.dylib", RTLD_LAZY);
  Class prefsControllerClass = %c(PSUIPrefsListController) ? : %c(PrefsListController);
  %init(PSUIPrefsListController = prefsControllerClass);
}
