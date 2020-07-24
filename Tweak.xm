#include <Preferences/PSSpecifier.h>
#include <Preferences/PSTableCell.h>
#include <Preferences/PSViewController.h>
#include <Preferences/PSListController.h>
#include <substrate.h>
#include "prefs.h"

@interface PSSpecifier (PreferenceLoader)
- (void)setupIconImageWithBundle:(NSBundle *)bundle;
- (void)pl_setupIcon;
@end

@interface PSUIPrefsListController : PSListController
- (void)lazyLoadBundle:(PSSpecifier *)sender;
@end

@interface UIImage (Private)
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

%hook PSUIPrefsListController

- (NSArray *)specifiers {
  if (MSHookIvar<NSArray *>(self, "_specifiers") != nil) return %orig;
  NSMutableArray *specs = [NSMutableArray new];
  NSString *dir = @"/Library/PreferenceLoader/Preferences";
  NSArray *subpaths = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:dir error:nil];
  __block NSInteger done = 0;

  for (NSString *file in subpaths) {
    // loading specifiers asynchronously seems to be faster
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSDictionary *entry;
      NSString *path = [dir stringByAppendingPathComponent:file];

      if (![file.pathExtension isEqualToString:@"plist"]) {
        done++;
        return;
      }
      entry = [NSDictionary dictionaryWithFile:path][@"entry"];
      if (!entry) {
        done++;
        return;
      }
      if (![PSSpecifier environmentPassesPreferenceLoaderFilter:[entry objectForKey:@"pl_filter"]]) {
        done++;
        return;
      }

      NSString *bundlePath;
      if ([entry objectForKey:@"bundle"]) {
        NSArray *potentialDirs = @[@"/Library/PreferenceBundles", @"/System/Library/PreferenceBundles"];
        for (NSString *baseDir in potentialDirs) {
          NSString *localPath = [NSString stringWithFormat:@"%@/%@.bundle", baseDir, entry[@"bundle"]];
          if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) bundlePath = localPath;
        }
        if (!bundlePath) {
          done++;
          return;
        }
      }

      BOOL isSimple = NO;
      if ([NSDictionary dictionaryWithFile:path][@"items"] || entry[@"items"]) isSimple = YES;
      PSSpecifier *specifier = [self specifiersFromEntry:entry sourcePreferenceLoaderBundlePath:nil title:[file stringByDeletingPathExtension]][0];
      if ([entry[@"cell"] isEqualToString:@"PSLinkCell"]) {
        if (isSimple) {
          [specifier setProperty:path forKey:@"pl_simpleBundlePlistPath"];
          specifier.controllerLoadAction = @selector(pl_loadSimpleBundle:);
        } else if (bundlePath) {
          [specifier setProperty:bundlePath forKey:@"lazy-bundle"];
          [specifier setProperty:[NSBundle bundleWithPath:bundlePath] forKey:@"pl_bundle"];
          specifier.controllerLoadAction = @selector(pl_lazyLoadBundle:);
        }
        //if (![specifier propertyForKey:@"lazy-bundle"]) [specifier setProperty:[path stringByDeletingLastPathComponent] forKey:@"lazy-bundle"];
      }
      [specifier setProperty:[NSBundle bundleWithPath:[path stringByDeletingLastPathComponent]] forKey:@"pl_bundle"];

      specifier.target = self;
      MSHookIvar<SEL>(specifier, "getter") = @selector(readPreferenceValue:);
      MSHookIvar<SEL>(specifier, "setter") = @selector(setPreferenceValue: specifier:);
      [specifier pl_setupIcon];
      [specs addObject:specifier];
      done++;
    });
  }
  while (done != subpaths.count) {}

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

%new
- (void)pl_lazyLoadBundle:(PSSpecifier *)sender {
  // manually loading the bundle for two reasons: to avoid hooking bundleWithPath: and for easier error handling
  NSError *error;
  if ([[NSBundle bundleWithPath:[sender propertyForKey:@"lazy-bundle"]] loadAndReturnError:&error]) {
    [self lazyLoadBundle:sender];
    return;
  }
  UITableViewCell *cell = [sender propertyForKey:@"cellObject"];
  UIView *view = cell.superview;
  while (![view isKindOfClass:[UITableView class]]) view = view.superview;
  UITableView *tableView = (UITableView *)view;
  [tableView deselectRowAtIndexPath:[tableView indexPathForCell:cell] animated:YES];
  NSString *message = @"The preference bundle could not be loaded. It might be missing, outdated or corrupted. Try to contact the developer (or fix your bundle if that's you). Error message: \n\n";
  if (@available(iOS 8, *)) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:[message stringByAppendingString:error.description] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
  } else {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[message stringByAppendingString:error.description] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
  }
  [self lazyLoadBundle:sender];
}

%new
- (void)pl_loadSimpleBundle:(PSSpecifier *)sender {
  [self lazyLoadBundle:sender];
  MSHookIvar<Class>(sender, "detailControllerClass") = %c(SimpleBundleController);
}

%end

%hook PSSpecifier

%new
- (void)pl_setupIcon {
  if (NSBundle *bundle = [NSBundle bundleWithPath:[self propertyForKey:@"lazy-bundle"]] ? : [self propertyForKey:@"pl_bundle"]) [self setupIconImageWithBundle:bundle];
  UIImage *icon = [self propertyForKey:@"iconImage"] ? : [UIImage imageWithContentsOfFile:@"/Library/PreferenceLoader/Default.png"];
  if (!icon) return;
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(29, 29), NO, [UIScreen mainScreen].scale);
  CGRect iconRect = CGRectMake(0, 0, 29, 29);
  NSBundle *mobileIconsBundle = [NSBundle bundleWithIdentifier:@"com.apple.mobileicons.framework"];
  UIImage *mask = [UIImage imageNamed:@"TableIconMask" inBundle:mobileIconsBundle];
  if (mask) CGContextClipToMask(UIGraphicsGetCurrentContext(), iconRect, mask.CGImage);
  [icon drawInRect:iconRect];
  icon = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  [self setProperty:icon forKey:@"iconImage"];
}

%end

%hook PSViewController

- (void)viewDidAppear:(BOOL)didAppear {
  %orig;
  if (!self.title || self.title.length == 0) self.title = self.specifier.name;
}

%end

// loading specifiers from the items of a PSSpecifier for PSListController (again. WHO THE SHIT DOES THAT?????)
%hook PSListController

- (NSArray *)specifiers {
  if (MSHookIvar<NSArray *>(self, "_specifiers") != nil) return %orig;
  if (NSArray *items = [self.specifier propertyForKey:@"items"]) {
    NSMutableArray *specs = [NSMutableArray new];
    for (NSDictionary *item in items) {
      PSSpecifier *specifier = [self specifiersFromEntry:item sourcePreferenceLoaderBundlePath:nil title:nil][0];
      [specs addObject:specifier];
    }
    if (specs.count != 0) MSHookIvar<NSArray *>(self, "_specifiers") = specs;
  }
  return MSHookIvar<NSArray *>(self, "_specifiers");
}

%end

%ctor {
  dlopen("/usr/lib/libprefs.dylib", RTLD_LAZY);
  // the versions that don't have PSUIPrefsListController will hook PrefsListController instead
  Class prefsControllerClass = %c(PSUIPrefsListController) ? : %c(PrefsListController);
  %init(PSUIPrefsListController = prefsControllerClass);
}
