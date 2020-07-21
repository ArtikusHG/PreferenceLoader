INSTALL_TARGET_PROCESSES = Preferences

ARCHS = arm64
THEOS_DEVICE_IP = 192.168.0.18

TARGET = iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PreferenceLoader

PreferenceLoader_FILES = Tweak.xm
PreferenceLoader_CFLAGS = -fobjc-arc
PreferenceLoader_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
