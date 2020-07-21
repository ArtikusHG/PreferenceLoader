#import <Preferences/PSViewController.h>
#import <Preferences/PSSpecifier.h>

%hook PSViewController

- (NSString *)title {
  return (!%orig || %orig.length == 0) ? self.specifier.name : %orig;
}

%end