APP_NAME = DevMirror
BUNDLE_DIR = $(APP_NAME).app
CONFIGURATION ?= debug

.PHONY: build test clean package install run

build:
	swift build -c $(CONFIGURATION)

test:
	swift test

clean:
	swift package clean
	rm -rf $(BUNDLE_DIR)

package: build
	rm -rf $(BUNDLE_DIR)
	mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	mkdir -p $(BUNDLE_DIR)/Contents/Resources
	cp .build/$(CONFIGURATION)/$(APP_NAME) $(BUNDLE_DIR)/Contents/MacOS/
	cp Resources/Info.plist $(BUNDLE_DIR)/Contents/
	if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(BUNDLE_DIR)/Contents/Resources/; fi
	touch $(BUNDLE_DIR)

install: package
	cp -rf $(BUNDLE_DIR) /Applications/

run: package
	open $(BUNDLE_DIR)
