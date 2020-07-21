#include <Preferences/PSSpecifier.h>
#include <Preferences/PSTableCell.h>
#include <Preferences/PSViewController.h>
#include <Preferences/PSListController.h>

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

NSDictionary *dictionaryWithFile(NSString *path) {
  if (@available(iOS 11, *)) return [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
  return [NSDictionary dictionaryWithContentsOfFile:path];
}

@interface SimpleBundleController : PSListController
@end

@implementation SimpleBundleController

- (NSBundle *)bundle {
  return [NSBundle bundleWithPath:[[self.specifier propertyForKey:@"pl_simpleBundlePlistPath"] stringByDeletingLastPathComponent]];
}

- (void)viewDidAppear:(BOOL)didAppear {
  [super viewDidAppear:didAppear];
  NSString *title = dictionaryWithFile([self.specifier propertyForKey:@"pl_simpleBundlePlistPath"])[@"title"] ? : self.specifier.name;
  self.title = [[self bundle] localizedStringForKey:title value:title table:nil];
}

- (NSDictionary *)localizedDictionaryForDictionary:(NSDictionary *)dict {
  NSMutableDictionary *newDict = [NSMutableDictionary new];
	for (NSString *key in dict) {
	   NSString *value = [dict objectForKey:key];
		[newDict setObject:[[self bundle] localizedStringForKey:value value:value table:nil] forKey:key];
  }
  return newDict;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
    NSString *plistName = [[[self.specifier propertyForKey:@"pl_simpleBundlePlistPath"] lastPathComponent] stringByDeletingPathExtension];
    NSMutableArray *specs = [[self loadSpecifiersFromPlistName:plistName target:self] mutableCopy];
    // TODO check iphonedevwiki ALL keys for those with string type value and add appropiate to localize ones here
    NSArray *localizableKeys = @[@"label", @"value", @"headerDetailText", @"placeholder", @"staticTextMessage"];
    for (PSSpecifier *specifier in specs) {
      for (NSString *key in specifier.properties.allKeys) {
        NSString *value = [specifier propertyForKey:key];
        if ([localizableKeys containsObject:key]) [specifier setProperty:[[self bundle] localizedStringForKey:value value:value table:nil] forKey:key];
      }
      specifier.name = [specifier propertyForKey:@"label"];
      if (specifier.titleDictionary) specifier.titleDictionary = [self localizedDictionaryForDictionary:specifier.titleDictionary];
      if (specifier.shortTitleDictionary) specifier.shortTitleDictionary = [self localizedDictionaryForDictionary:specifier.shortTitleDictionary];
    }
    _specifiers = [specs copy];
  }
	return _specifiers;
}

@end

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
        entry = dictionaryWithFile(newPath)[@"entry"];
        if (entry && entry.count) path = newPath;
      }
    } else entry = dictionaryWithFile(path)[@"entry"];
    if (!entry) continue;
    if (dictionaryWithFile(path)[@"items"]) isSimple = YES;
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

%hook PSViewController

- (NSString *)title {
  return (!%orig || %orig.length == 0) ? self.specifier.name : %orig;
}

%end

%hook PSSpecifier

%new
- (void)pl_setupIcon {
  if (NSBundle *bundle = [NSBundle bundleWithPath:[self propertyForKey:@"lazy-bundle"]]) [self setupIconImageWithBundle:bundle];
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

%ctor {
  // the versions that don't have PSUIPrefsListController will hook PrefsListController instead
  Class PrefsControllerClass = %c(PSUIPrefsListController) ? : %c(PrefsListController);
  %init(PSUIPrefsListController = PrefsControllerClass);
}
