#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface PSUIPrefsListController : PSListController
- (void)lazyLoadBundle:(PSSpecifier *)sender;
@end