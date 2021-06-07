#include <Preferences/PSSpecifier.h>
#include <dlfcn.h>
#include "prefs.h"

@interface UIImage (Private)
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

%hook PSUIPrefsListController

- (NSArray *)specifiers {
  // if the ivar has *not* already been loaded, do hax. if it has, no need for doing hax
  if (MSHookIvar<NSArray *>(self, "_specifiers")) return %orig;

  NSMutableArray *specs = [NSMutableArray new];
  // subpathsOfDirectory, unlike contentsOfDirectory, is recursive, and we need this for plists in folders
  for (NSString *file in [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:@"/Library/PreferenceLoader/Preferences" error:nil]) {
    if (![file.pathExtension isEqualToString:@"plist"]) continue;

    NSString *path = [@"/Library/PreferenceLoader/Preferences" stringByAppendingPathComponent:file];
    NSDictionary *entry = [NSDictionary dictionaryWithFile:path][@"entry"];
    if (!entry || ![PSSpecifier environmentPassesPreferenceLoaderFilter:[entry objectForKey:@"pl_filter"]]) continue;

    PSSpecifier *specifier = [self specifiersFromEntry:entry sourcePreferenceLoaderBundlePath:path.stringByDeletingLastPathComponent title:file.lastPathComponent.stringByDeletingPathExtension][0];
    UIImage *icon = [specifier propertyForKey:@"iconImage"] ? : [UIImage imageWithContentsOfFile:@"/Library/PreferenceLoader/Default.png"];
    if (icon) {
      UIGraphicsBeginImageContextWithOptions(CGSizeMake(29, 29), NO, [UIScreen mainScreen].scale);
      CGRect iconRect = CGRectMake(0, 0, 29, 29);
      UIImage *mask = [UIImage imageNamed:@"TableIconMask" inBundle:[NSBundle bundleWithIdentifier:@"com.apple.mobileicons.framework"]];
      if (mask) CGContextClipToMask(UIGraphicsGetCurrentContext(), iconRect, mask.CGImage);
      [icon drawInRect:iconRect];
      icon = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();
      [specifier setProperty:icon forKey:@"iconImage"];
    }
    // to prevent crashes. DO NOT remove check.
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
  return mutableSpecifiers;
}

%end

// loading specifiers from the items of a PSSpecifier for PSListController
%hook PSListController

- (NSArray *)specifiers {
  if (MSHookIvar<NSArray *>(self, "_specifiers")) return %orig;
  if (NSArray *items = [self.specifier propertyForKey:@"items"]) {
    if (items.count == 0) return %orig;
    NSMutableArray *specs = [NSMutableArray new];
    for (NSDictionary *item in items) {
      PSSpecifier *specifier = [self specifiersFromEntry:item sourcePreferenceLoaderBundlePath:nil title:nil][0];
      [specs addObject:specifier];
    }
    if (specs.count != 0) {
      MSHookIvar<NSArray *>(self, "_specifiers") = specs;
      return specs;
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
