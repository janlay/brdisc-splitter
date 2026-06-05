SHELL := /bin/bash

PRODUCT_NAME := BRDiscSplitter
APP_NAME := BRDisc Splitter
CONFIG_DEBUG := Debug
CONFIG_RELEASE := Release
PBXPROJ := $(PRODUCT_NAME).xcodeproj/project.pbxproj

BUILD_NUMBER := $(shell grep 'CURRENT_PROJECT_VERSION = [0-9]' $(PBXPROJ) | head -1 | sed 's/.*= *\([^;]*\);/\1/')
VERSION := $(shell cat VERSION)
GIT_SHORT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || printf 'unknown')

.DEFAULT_GOAL := debug

.PHONY: debug release test clean bump sync-version

debug: sync-version
	xcodebuild -scheme $(PRODUCT_NAME) -configuration $(CONFIG_DEBUG) build
	APP_PATH="$$(xcodebuild -scheme $(PRODUCT_NAME) -configuration $(CONFIG_DEBUG) -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR ' | awk '{print $$3}')/$(APP_NAME).app"; \
	open -a "$$APP_PATH"

release: sync-version bump
	xcodebuild -scheme $(PRODUCT_NAME) -configuration $(CONFIG_RELEASE) build
	APP_PATH="$$(xcodebuild -scheme $(PRODUCT_NAME) -configuration $(CONFIG_RELEASE) -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR ' | awk '{print $$3}')/$(APP_NAME).app"; \
	$(MAKE) CONFIGURATION=Release APP_PATH="$$APP_PATH" write-git-hash; \
	open -a "$$APP_PATH"

test: sync-version
	xcodebuild -scheme $(PRODUCT_NAME) -configuration $(CONFIG_DEBUG) test

clean:
	xcodebuild -scheme $(PRODUCT_NAME) clean

bump:
	@OLD=$(BUILD_NUMBER); NEW=$$((OLD + 1)); \
	sed -i '' "s/CURRENT_PROJECT_VERSION = $$OLD;/CURRENT_PROJECT_VERSION = $$NEW;/g" $(PBXPROJ); \
	echo "CFBundleVersion: $$OLD -> $$NEW"

sync-version:
	@sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $(VERSION)/g" $(PBXPROJ)
	@echo "CFBundleShortVersionString: $(VERSION)"

write-git-hash:
	@plist="$(APP_PATH)/Contents/Info.plist"; \
	/usr/libexec/PlistBuddy -c "Set :GitShortHash $(GIT_SHORT_HASH)" "$$plist" 2>/dev/null || \
	  /usr/libexec/PlistBuddy -c "Add :GitShortHash string $(GIT_SHORT_HASH)" "$$plist"
	@echo "Git short hash: $(GIT_SHORT_HASH)"
