#import <Foundation/Foundation.h>
#import "Headers/PSSpecifier.h"
#import "Headers/UIImage.h"

%hook PSSpecifier

%new
- (void)pl_setupIcon {
  NSBundle *bundle = [NSBundle bundleWithPath:[self propertyForKey:@"lazy-bundle"]];
  if (bundle) [self setupIconImageWithBundle:bundle];
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