#include <Preferences/PSSpecifier.h>
#include <substrate.h>
#import "prefs.h"

@interface PSListController (Preferences)
- (void)lazyLoadBundle:(PSSpecifier *)sender;
@end

extern "C" NSArray *SpecifiersFromPlist(NSDictionary *plist, PSSpecifier *previousSpecifier, id target, NSString *plistName, NSBundle *bundle, NSString *title, NSString *specifierID, PSListController *callerList, NSMutableArray **bundleControllers);

NSString *const PLFilterKey = @"pl_filter";

@implementation NSDictionary (libprefs)

+ (NSDictionary *)dictionaryWithFile:(NSString *)path {
  if (@available(iOS 11, *)) return [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
  return [NSDictionary dictionaryWithContentsOfFile:path];
}

@end

@implementation PLLocalizedListController

- (NSDictionary *)localizedDictionaryForDictionary:(NSDictionary *)dict {
  NSMutableDictionary *newDict = [NSMutableDictionary new];
	for (NSString *key in dict) {
    NSString *value = [dict objectForKey:key];
    [newDict setObject:[self.bundle localizedStringForKey:value value:value table:nil] forKey:key];
  }
  return newDict;
}

- (NSArray *)specifiers {
  if (!_specifiers) {
    self.title = [self.bundle localizedStringForKey:self.title value:self.title table:nil];
    _specifiers = [super specifiers];
    NSArray *localizableKeys = @[@"label", @"value", @"headerDetailText", @"placeholder", @"suffix", @"staticTextMessage", @"prompt", @"title", @"okTitle", @"cancelTitle"];
    for (PSSpecifier *specifier in _specifiers) {
      for (NSString *key in specifier.properties.allKeys) {
        NSString *value = [specifier propertyForKey:key];
        if ([localizableKeys containsObject:key]) [specifier setProperty:[self.bundle localizedStringForKey:value value:value table:nil] forKey:key];
      }
      // note to future self: i got confused and added if (!specifier.name) (and such for identifier) checks. this is here for a reason! the name is set from the label, because it (the label, unlike the name) is getting localized!
      specifier.name = [specifier propertyForKey:@"label"];
      specifier.identifier = [specifier propertyForKey:@"label"];
      if (specifier.titleDictionary) specifier.titleDictionary = [self localizedDictionaryForDictionary:specifier.titleDictionary];
      if (specifier.shortTitleDictionary) specifier.shortTitleDictionary = [self localizedDictionaryForDictionary:specifier.shortTitleDictionary];
    }
  }
  return _specifiers;
}

@end

@implementation PLCustomListController

- (NSBundle *)bundle { return self.specifier.preferenceLoaderBundle; }

- (NSArray *)specifiers {
	if (!_specifiers) {
    _specifiers = [NSMutableArray new];
    NSString *path = [NSString stringWithFormat:@"%@/%@.plist", self.bundle.bundlePath, [self.specifier propertyForKey:@"pl_alt_plist_name"]];
    NSDictionary *alternatePlist = [NSDictionary dictionaryWithFile:path];
    self.title = alternatePlist[@"title"] ? : self.specifier.name;
    if (NSArray *items = [self.specifier propertyForKey:@"items"]) {
      // the following four lines should actually be able to be deleted *in theory*, since the exact same purpose is served by the PSListController hook in Tweak.xm; it doesn't get injected for some reason, however changing PSListController to PSCustomListController in the hook somehow works fine. /shrug/
      for (NSDictionary *item in items) {
        PSSpecifier *specifier = [self specifiersFromEntry:item sourcePreferenceLoaderBundlePath:nil title:nil][0];
        [_specifiers addObject:specifier];
      }
    } else _specifiers = [self loadSpecifiersFromPlistName:[self.specifier propertyForKey:@"pl_alt_plist_name"] target:self];
  }
	return _specifiers;
}

@end

@implementation PSSpecifier (libprefs)

+ (BOOL)environmentPassesPreferenceLoaderFilter:(NSDictionary *)filter {
	if (!filter || filter.count == 0) return YES;
	NSArray *versions = [filter objectForKey:@"CoreFoundationVersion"];
	if (versions.count == 1) return (kCFCoreFoundationVersionNumber >= [versions[0] floatValue]);
	else if (versions.count == 2) return (kCFCoreFoundationVersionNumber >= [versions[0] floatValue] && kCFCoreFoundationVersionNumber < [versions[1] floatValue]);
	return YES;
}

- (NSBundle *)preferenceLoaderBundle { return [self propertyForKey:@"pl_bundle"]; }

@end

@implementation PSListController (libprefs)

- (NSArray *)specifiersFromEntry:(NSDictionary *)entry sourcePreferenceLoaderBundlePath:(NSString *)sourceBundlePath title:(NSString *)title {
  NSBundle *bundle;
  NSMutableArray *potentialPaths = [NSMutableArray new];
  if (entry[@"bundlePath"]) [potentialPaths addObject:entry[@"bundlePath"]];
  if (entry[@"bundle"]) {
    [potentialPaths addObject:[NSString stringWithFormat:@"/Library/PreferenceBundles/%@.bundle", entry[@"bundle"]]];
    [potentialPaths addObject:[NSString stringWithFormat:@"/System/Library/PreferenceBundles/%@.bundle", entry[@"bundle"]]];
  }
  if (sourceBundlePath) [potentialPaths addObject:sourceBundlePath];
  for (NSString *path in potentialPaths) if ((bundle = [NSBundle bundleWithPath:path])) break;
	NSMutableArray *bundleControllers = [MSHookIvar<NSArray *>(self, "_bundleControllers") mutableCopy];

  NSArray *specs = SpecifiersFromPlist(@{ @"items" : @[entry] }, nil, self, title, bundle, NULL, NULL, self, &bundleControllers);
	if (specs.count == 0) return nil;

  for (PSSpecifier *specifier in specs) {
    if (!specifier.name) specifier.name = title;
    if (!specifier.identifier) specifier.identifier = title;

    if (entry[@"bundle"] && [[entry objectForKey:@"isController"] boolValue]) {
      [specifier setProperty:bundle.bundlePath forKey:@"lazy-bundle"];
      specifier.controllerLoadAction = @selector(pl_lazyLoadBundle:);
      // without this check it would set it to PLCustomListController or PLLocalizedListController for example if it was PSListItemController :c
    } else if (!specifier.detailControllerClass) {
      // yes, the title. the title is the *fallback* title, and the fallback title is what? bravo, the plist filename! (w/o the extension)
      [specifier setProperty:title forKey:@"pl_alt_plist_name"];
      specifier.detailControllerClass = [sourceBundlePath.lastPathComponent isEqualToString:@"Preferences"] ? [PLCustomListController class] : [PLLocalizedListController class];
    }
    [specifier setProperty:[NSBundle bundleWithPath:sourceBundlePath] forKey:@"pl_bundle"];
  }
	return specs;
}

- (void)pl_lazyLoadBundle:(PSSpecifier *)sender {
  NSError *error;
  if ([[NSBundle bundleWithPath:[sender propertyForKey:@"lazy-bundle"]] loadAndReturnError:&error]) [self lazyLoadBundle:sender];
  else {
    UITableViewCell *cell = [sender propertyForKey:@"cellObject"];
    [self.table deselectRowAtIndexPath:[self.table indexPathForCell:cell] animated:YES];
    if (@available(iOS 8, *)) {
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:error.description preferredStyle:UIAlertControllerStyleAlert];
      [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
      [self presentViewController:alert animated:YES completion:nil];
    } else {
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:error.description delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
      [alert show];
    }
  }
}

@end
