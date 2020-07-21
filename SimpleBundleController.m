#import <Preferences/PSSpecifier.h>
#import "SimpleBundleController.h"
#import "NSDictionary+Path.h"

@implementation SimpleBundleController

- (NSBundle *)bundle {
  return [NSBundle bundleWithPath:[[self.specifier propertyForKey:@"pl_simpleBundlePlistPath"] stringByDeletingLastPathComponent]];
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