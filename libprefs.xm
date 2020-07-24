#include <Preferences/PSListController.h>
#include <Preferences/PSSpecifier.h>
#include <substrate.h>
#import "prefs.h"

NSString *const PLFilterKey = @"pl_filter";

@implementation NSDictionary (libprefs)

+ (NSDictionary *)dictionaryWithFile:(NSString *)path {
  if (@available(iOS 11, *)) return [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
  return [NSDictionary dictionaryWithContentsOfFile:path];
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

- (NSBundle *)preferenceLoaderBundle {
  return [self propertyForKey:@"pl_bundle"];
}

@end

extern "C" NSArray *SpecifiersFromPlist(NSDictionary *plist, PSSpecifier *previousSpecifier, id target, NSString *plistName, NSBundle *bundle, NSString *title, NSString *specifierID, PSListController *callerList, NSMutableArray **bundleControllers);

@implementation PSListController (libprefs)

- (NSArray *)specifiersFromEntry:(NSDictionary *)entry sourcePreferenceLoaderBundlePath:(NSString *)sourceBundlePath title:(NSString *)title {
	NSDictionary *specifierPlist = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:entry, nil], @"items", nil];
  NSBundle *bundle;
  NSMutableArray *potentialPaths = [NSMutableArray new];
  if ([entry objectForKey:@"bundlePath"]) [potentialPaths addObject:entry[@"bundlePath"]];
  if ([entry objectForKey:@"bundle"]) {
    [potentialPaths addObject:[NSString stringWithFormat:@"/Library/PreferenceBundles/%@.bundle", entry[@"bundle"]]];
    [potentialPaths addObject:[NSString stringWithFormat:@"/System/Library/PreferenceBundles/%@.bundle", entry[@"bundle"]]];
	}
  if ([entry objectForKey:@"bundle"]) for (NSString *path in potentialPaths) if ((bundle = [NSBundle bundleWithPath:path])) break;
	NSMutableArray *bundleControllers = [MSHookIvar<NSArray *>(self, "_bundleControllers") mutableCopy];
	NSArray *specs = SpecifiersFromPlist(specifierPlist, nil,  self, title, bundle, NULL, NULL, self, &bundleControllers);
	if (specs.count == 0) return nil;
  for (PSSpecifier *specifier in specs) if (!specifier.name) {
    specifier.name = title;
    specifier.identifier = title;
  }
	return specs;
}

@end

@implementation SimpleBundleController

- (NSBundle *)bundle {
  return self.specifier.preferenceLoaderBundle;
}

- (void)viewDidAppear:(BOOL)didAppear {
  [super viewDidAppear:didAppear];
  NSString *title = [NSDictionary dictionaryWithFile:[self.specifier propertyForKey:@"pl_simpleBundlePlistPath"]][@"title"] ? : self.specifier.name;
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
    NSString *plistPath = [self.specifier propertyForKey:@"pl_simpleBundlePlistPath"];
    NSString *plistName = [[plistPath lastPathComponent] stringByDeletingPathExtension];
    NSMutableArray *specs;
    // who the hell puts items into entry? where is it stated that this is a vaild format? but anyway, we gotta parse that....
    if (NSArray *items = [[NSDictionary dictionaryWithFile:plistPath] objectForKey:@"entry"][@"items"]) {
      specs = [NSMutableArray new];
      for (NSDictionary *item in items) {
        PSSpecifier *specifier = [self specifiersFromEntry:item sourcePreferenceLoaderBundlePath:nil title:nil][0];
        [specs addObject:specifier];
      }
    }
    else specs = [[self loadSpecifiersFromPlistName:plistName target:self] mutableCopy];
    // TODO check iphonedevwiki ALL keys for those with string type value and add appropiate to localize ones here
    NSArray *localizableKeys = @[@"label", @"value", @"headerDetailText", @"placeholder", @"staticTextMessage"];
    for (PSSpecifier *specifier in specs) {
      for (NSString *key in specifier.properties.allKeys) {
        NSString *value = [specifier propertyForKey:key];
        if ([localizableKeys containsObject:key]) [specifier setProperty:[[self bundle] localizedStringForKey:value value:value table:nil] forKey:key];
      }
			specifier.name = [specifier propertyForKey:@"label"];
			specifier.identifier = [specifier propertyForKey:@"label"];
      if (specifier.titleDictionary) specifier.titleDictionary = [self localizedDictionaryForDictionary:specifier.titleDictionary];
      if (specifier.shortTitleDictionary) specifier.shortTitleDictionary = [self localizedDictionaryForDictionary:specifier.shortTitleDictionary];
    }
    _specifiers = [specs copy];
  }
	return _specifiers;
}

@end
