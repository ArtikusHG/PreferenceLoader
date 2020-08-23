## Before you complain about indentation: it *is* broken. Atom editor is very weird with this stuff. One day I'll redo it by hand, but not now.

# PreferenceLoader

This is a PreferenceLoader alternative I started off for fun and knowledge, but soon ended up making it into a finished tweak. When I was starting this, I didn't really have any complains about Dustin Howett's tweak, but now I actually have a few:

- **A lot** of unnecessary hooking, such as the ```[NSBundle bundleWithPath:]``` hook, ```- (void)lazyLoadBundle:``` hook, hooks for iOS versions lower than 6 which are barely used now, etc.

- Lack of source code for the latest version: the one available on BigBoss is 2.2.4, while the one on GitHub is still 2.2.0, not even updated for iOS >= 9.

- It doesn't mask icons. Yes, this is not something it's supposed to provide, but it's really a pain to mask all these images manually :/. And keep in mind, the masks change almost every update...

- It doesn't have a default (blank) icon to be shown for bundles without one, therefore breaking the layout and aesthetic of the Settings app in such cases.

***

# How is this project different

- Barely hooks anything besides ```- (NSArray *)specifiers```

- Provides source code that will be kept maintained unless the project dies out

- Masks icons and has a default icon for bundles which don't provide one (btw, icon made by [@Xeviks](https://twitter.com/Xeviks))

- Provides more elegant error handling, with an alert displayed instead of a bundle with the error text

- Almost ~~three~~ two times smaller than the original (~~199~~ 300 lines vs. 549)

- Only supports versions starting from iOS 7 (should mostly work on lower ones, but I didn't test that), which lets the project focus on more modern versions instead of keeping lots of legacy code for iOS 3.2

***

# About "[Simple approach](https://iphonedevwiki.net/index.php/PreferenceLoader#Simple_Approach)" bundles

This probably isn't the best place for a rant, but: **do not use simple approach bundles**.

The concept of a simple approach bundle is not actually creating a bundle, but instead creating a single .plist file with both the ```entry``` and ```items``` keys being kept in one file, thus the developer not having to create an actual preference bundle, but rather just letting PreferenceLoader load the specifiers by itself. While this is not necessarily bad, it made me increase the code size **twice**. So, this is why I dislike "simple approach" bundles:

They're **not** native iOS preference bundles. Therefore, PreferenceLoader has to take handle of loading and localizing the bundle manually. And, uh, come on, they're not even effective! Adding a simple respring button with such a bundle is literally impossible! Not even talking about properly overriding the setter and getter methods.

So, yeah, don't use simple approach bundles. I've never seen them being used in a modern tweak (probably because the theos template for a modern preference bundle provides and actual *bundle* template), but still, don't use them.

***

# My bundle doesn't work!

If you are sure that this version of PreferenceLoader is the cause and your bundle works fine on the regular version, you can DM me on [Twitter](https://twitter.com/ArtikusHG), sending me the info about your problem (the name / package of the tweak, what exactly doesn't work, its behavior on the regular PreferenceLoader, your device and iOS version, and other whatever stuff you think is useful). I implemented support for all bundle formats I could find, filtering, tested this on three different versions and devices, with 30+ different bundles, but I still can't be sure, right?

Though, if your bundle works properly with the regular PreferenceLoader, it should work fine with mine with no changes. My tweak provides pretty much the same things that Dustin Howett's one does, so you're most likely fine.
