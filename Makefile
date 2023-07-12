ifeq ($(RELEASE),1)
	FINALPACKAGE = 1
endif

ifeq ($(ROOTLESS),1)
	THEOS_PACKAGE_SCHEME=rootless
endif

ARCHS := arm64 arm64e

TARGET := iphone:clang:latest:7.0

THEOS_DEVICE_IP=192.168.11.9
THEOS_DEVICE_PORT=22

SDK_PATH = $(THEOS)/sdks/iPhoneOS14.5.sdk/
SYSROOT = $(SDK_PATH)

INSTALL_TARGET_PROCESSES = Discord

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = K2genmity
K2genmity_FILES = Tweak.xm
K2genmity_CFLAGS = -fobjc-arc
K2genmity_FRAMEWORKS = UIKit Foundation


include $(THEOS_MAKE_PATH)/tweak.mk

# include $(THEOS_MAKE_PATH)/aggregate.mk
