TARGET := iphone:clang:latest:14.0
ARCHS = arm64
THEOS_DEVICE_IP = localhost

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RobloxProfileMenu

RobloxProfileMenu_FILES = Tweak.mm
RobloxProfileMenu_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
