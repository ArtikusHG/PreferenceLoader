## Before you complain about indentation: it *is* broken. Atom editor is very weird with this stuff. One day I'll redo it by hand, but not now.

# PreferenceLoader

This is a modern lightweight alternative to Dustin Howett's PreferenceLoader. I started this because I was bored, but it later turned out there was *a lot* of stuff from the original that could be improved.

Complaints about the original:

- **A lot** of unnecessary hooking, such as the ```[NSBundle bundleWithPath:]``` hook, ```- (void)lazyLoadBundle:``` hook, etc.

- Way too cluttered with legacy code: it supports iOS 3 and armv6. While this is not necessarily a bad thing, 99% of users won't ever need the iOS 3 support.

- At the moment of making this, the original PreferenceLoader had no error handling. It would just say there was an error, and provide zero details about what exactly happened. By now this has been fixed, but it was still one of the motives for me to write this.

- Not processing icons: while this is supposed to be something that the developers should take care of, many actually don't, and the icons may be oversized, unmasked (not to mention different iOS versions have different masks), and sometimes even missing. This version takes care of all that, resizing and masking the icons to match the system's standards, as well as adding a default icon for those preference bundles that don't have one.

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
