#import "Headers/PSSpecifier.h"
#import "Headers/PSUIPrefsListController.h"
#import "SimpleBundleController.h"
#import "NSDictionary+Path.h"

%hook PSUIPrefsListController

- (NSArray *)specifiers {
  if (MSHookIvar<id>(self, "_specifiers") != nil) return %orig;
  NSMutableArray *specs = [NSMutableArray new];
  NSString *dir = @"/Library/PreferenceLoader/Preferences";
  for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil]) {
    NSDictionary *entry;
    // entry and items in one plist (delet urself if u do this)
    BOOL isSimple = NO;
    NSString *path = [dir stringByAppendingPathComponent:file];
    BOOL isDir;
    [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    if (![file.pathExtension isEqualToString:@"plist"] && !isDir) continue;
    if (isDir) {
      for (NSString *newFile in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil]) {
        if (![newFile.pathExtension isEqualToString:@"plist"]) continue;
        NSString *newPath = [path stringByAppendingPathComponent:newFile];
        entry = [NSDictionary dictionaryWithFile:newPath][@"entry"];
        if (entry && entry.count) path = newPath;
      }
    } else entry = [NSDictionary dictionaryWithFile:path][@"entry"];
    if (!entry) continue;
    if ([NSDictionary dictionaryWithFile:path][@"items"]) isSimple = YES;
    if (entry[@"pl_filter"]) {
      NSArray *versions = [entry[@"pl_filter"] objectForKey:@"CoreFoundationVersion"];
      BOOL pass = NO;
      if (versions.count == 1) pass = (kCFCoreFoundationVersionNumber >= [versions[0] floatValue]);
      else if (versions.count == 2) pass = (kCFCoreFoundationVersionNumber >= [versions[0] floatValue] && kCFCoreFoundationVersionNumber < [versions[1] floatValue]);
      if (!pass) continue;
    }
    PSSpecifier *specifier = [%c(PSSpecifier) new];
    for (NSString *key in entry.allKeys) [specifier setProperty:entry[key] forKey:key];
    specifier.name = entry[@"label"];
    specifier.cellType = [PSTableCell cellTypeFromString:entry[@"cell"]];
    if (![specifier propertyForKey:@"lazy-bundle"]) [specifier setProperty:[path stringByDeletingLastPathComponent] forKey:@"lazy-bundle"];
    if ([entry[@"cell"] isEqualToString:@"PSLinkCell"]) {
      if (isSimple) {
        [specifier setProperty:path forKey:@"pl_simpleBundlePlistPath"];
        specifier.controllerLoadAction = @selector(pl_loadSimpleBundle:);
      } else {
        NSArray *potentialDirs = @[@"/Library/PreferenceBundles", @"/System/Library/PreferenceBundles"];
        for (NSString *baseDir in potentialDirs) {
          NSString *bundlePath = [NSString stringWithFormat:@"%@/%@.bundle", baseDir, entry[@"bundle"]];
          if ([[NSFileManager defaultManager] fileExistsAtPath:bundlePath]) [specifier setProperty:bundlePath forKey:@"lazy-bundle"];
        }
        specifier.controllerLoadAction = @selector(pl_lazyLoadBundle:);
      }
    }
    specifier.target = self;
    MSHookIvar<SEL>(specifier, "getter") = @selector(readPreferenceValue:);
    MSHookIvar<SEL>(specifier, "setter") = @selector(setPreferenceValue: specifier:);
    [specifier pl_setupIcon];
    [specs addObject:specifier];
  }
  if (specs.count == 0) return %orig;
  [specs sortUsingComparator:^NSComparisonResult(PSSpecifier *a, PSSpecifier *b) {
    return [a.name localizedCaseInsensitiveCompare:b.name];
  }];
  [specs insertObject:[%c(PSSpecifier) emptyGroupSpecifier] atIndex:0];
  NSMutableArray *mutableSpecifiers = [%orig mutableCopy];
  [mutableSpecifiers addObjectsFromArray:specs];
  MSHookIvar<NSArray *>(self, "_specifiers") = [mutableSpecifiers copy];
  return MSHookIvar<NSArray *>(self, "_specifiers");
}

%new
- (void)pl_lazyLoadBundle:(PSSpecifier *)sender {
  // manually loading the bundle for two reasons: to avoid hooking bundleWithPath: and for easier error handling
  if ([[NSBundle bundleWithPath:[sender propertyForKey:@"lazy-bundle"]] load]) {
    [self lazyLoadBundle:sender];
    return;
  }
  UITableViewCell *cell = [sender propertyForKey:@"cellObject"];
  UIView *view = cell.superview;
  while (![view isKindOfClass:[UITableView class]]) view = view.superview;
  UITableView *tableView = (UITableView *)view;
  [tableView deselectRowAtIndexPath:[tableView indexPathForCell:cell] animated:YES];
  NSString *message = @"The preference bundle could not be loaded. It might be missing, outdated or corrupted. Try to contact the developer (or fix your bundle if that's you).";
  if (@available(iOS 8, *)) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
  } else {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
  }
}

%new
- (void)pl_loadSimpleBundle:(PSSpecifier *)sender {
  [self lazyLoadBundle:sender];
  MSHookIvar<Class>(sender, "detailControllerClass") = [SimpleBundleController class];
}

%end

%ctor {
  // the versions that don't have PSUIPrefsListController will hook PrefsListController instead
  Class PrefsControllerClass = %c(PSUIPrefsListController) ? : %c(PrefsListController);
  %init(PSUIPrefsListController = PrefsControllerClass);
}
