ARCHS = armv7 arm64 arm64e
#ARCHS = arm64
TARGET = iphone:clang:14.4:7.0

DEBUG = 0
FINALPACKAGE = 1

INSTALL_TARGET_PROCESSES = Preferences

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libprefs
libprefs_FILES = libprefs.xm
libprefs_CFLAGS = -fobjc-arc
libprefs_FRAMEWORKS = UIKit
libprefs_PRIVATE_FRAMEWORKS = Preferences
libprefs_COMPATIBILITY_VERSION = 2.2.0
libprefs_LIBRARY_VERSION = $(shell echo "$(THEOS_PACKAGE_BASE_VERSION)" | cut -d'~' -f1)
libprefs_LDFLAGS = -compatibility_version $($(THEOS_CURRENT_INSTANCE)_COMPATIBILITY_VERSION) -current_version $($(THEOS_CURRENT_INSTANCE)_LIBRARY_VERSION)

TWEAK_NAME = PreferenceLoader
PreferenceLoader_FILES = Tweak.xm
PreferenceLoader_CFLAGS = -fobjc-arc
PreferenceLoader_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-libprefs-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/usr/include/libprefs$(ECHO_END)
	$(ECHO_NOTHING)cp prefs.h $(THEOS_STAGING_DIR)/usr/include/libprefs/prefs.h$(ECHO_END)
