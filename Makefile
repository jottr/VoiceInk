# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/VoiceInk-Dependencies
BUILD_DIR := $(CURDIR)/build
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework
WHISPER_VERSION    := v1.8.3
WHISPER_XCFW_URL   := https://github.com/ggml-org/whisper.cpp/releases/download/$(WHISPER_VERSION)/whisper-$(WHISPER_VERSION)-xcframework.zip

.PHONY: all clean distclean whisper setup build local install check healthcheck help dev run

# Default target
all: check build

# Development workflow
dev: build run

# Prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v curl >/dev/null 2>&1 || { echo "curl is not installed"; exit 1; }
	@command -v unzip >/dev/null 2>&1 || { echo "unzip is not installed"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is not installed (need Xcode)"; exit 1; }
	@command -v swift >/dev/null 2>&1 || { echo "swift is not installed"; exit 1; }
	@echo "Prerequisites OK"

healthcheck: check

# Build process
whisper:
	@mkdir -p $(WHISPER_CPP_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Downloading whisper.xcframework $(WHISPER_VERSION)..."; \
		curl -L -o /tmp/whisper-xcframework.zip $(WHISPER_XCFW_URL); \
		unzip -o /tmp/whisper-xcframework.zip -d $(WHISPER_CPP_DIR); \
		rm /tmp/whisper-xcframework.zip; \
		echo "whisper.xcframework ready at $(FRAMEWORK_PATH)"; \
	else \
		echo "whisper.xcframework already exists at $(FRAMEWORK_PATH), skipping download"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

build: setup
	xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug CODE_SIGN_IDENTITY="" build

# Build for local use without Apple Developer certificate
local: check setup
	@echo "Building VoiceInk for local use (no Apple Developer certificate required)..."
	xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug \
		-xcconfig LocalBuild.xcconfig \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=YES \
		DEVELOPMENT_TEAM="" \
		CODE_SIGN_ENTITLEMENTS=$(CURDIR)/VoiceInk/VoiceInk.local.entitlements \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) LOCAL_BUILD' \
		build
	@APP_PATH=$$(find "$$HOME/Library/Developer/Xcode/DerivedData" -name "VoiceInk.app" -path "*/Debug/*" -type d | head -1) && \
	if [ -n "$$APP_PATH" ]; then \
		echo "Copying VoiceInk.app to $(BUILD_DIR)..."; \
		mkdir -p $(BUILD_DIR); \
		rm -rf "$(BUILD_DIR)/VoiceInk.app"; \
		ditto "$$APP_PATH" "$(BUILD_DIR)/VoiceInk.app"; \
		xattr -cr "$(BUILD_DIR)/VoiceInk.app"; \
		echo ""; \
		echo "Build complete! App saved to: build/VoiceInk.app"; \
		echo "Run with:     open build/VoiceInk.app"; \
		echo "Install with: make install"; \
		echo ""; \
		echo "Limitations of local builds:"; \
		echo "  - No iCloud dictionary sync"; \
		echo "  - No automatic updates (pull new code and rebuild to update)"; \
	else \
		echo "Error: Could not find built VoiceInk.app in DerivedData."; \
		exit 1; \
	fi

# Install locally-built app to ~/Applications
install:
	@if [ ! -d "$(BUILD_DIR)/VoiceInk.app" ]; then \
		echo "No build found. Run 'make local' first."; \
		exit 1; \
	fi
	@mkdir -p "$$HOME/Applications"
	@rm -rf "$$HOME/Applications/VoiceInk.app"
	@ditto "$(BUILD_DIR)/VoiceInk.app" "$$HOME/Applications/VoiceInk.app"
	@xattr -cr "$$HOME/Applications/VoiceInk.app"
	@echo "Installed to ~/Applications/VoiceInk.app"
	@echo "Run with: open ~/Applications/VoiceInk.app"

# Run application
run:
	@if [ -d "$(BUILD_DIR)/VoiceInk.app" ]; then \
		echo "Opening build/VoiceInk.app..."; \
		open "$(BUILD_DIR)/VoiceInk.app"; \
	elif [ -d "$$HOME/Applications/VoiceInk.app" ]; then \
		echo "Opening ~/Applications/VoiceInk.app..."; \
		open "$$HOME/Applications/VoiceInk.app"; \
	else \
		echo "Looking for VoiceInk.app in DerivedData..."; \
		APP_PATH=$$(find "$$HOME/Library/Developer/Xcode/DerivedData" -name "VoiceInk.app" -type d | head -1) && \
		if [ -n "$$APP_PATH" ]; then \
			echo "Found app at: $$APP_PATH"; \
			open "$$APP_PATH"; \
		else \
			echo "VoiceInk.app not found. Please run 'make local' first."; \
			exit 1; \
		fi; \
	fi

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR) $(BUILD_DIR)
	@echo "Clean complete"

# Help
help:
	@echo "Available targets:"
	@echo "  check/healthcheck  Check if required CLI tools are installed"
	@echo "  whisper            Download whisper.xcframework $(WHISPER_VERSION) from GitHub releases"
	@echo "  setup              Copy whisper XCFramework to VoiceInk project"
	@echo "  build              Build the VoiceInk Xcode project"
	@echo "  local              Build for local use (output: build/VoiceInk.app)"
	@echo "  install            Copy build/VoiceInk.app to ~/Applications"
	@echo "  run                Launch the built VoiceInk app"
	@echo "  dev                Build and run the app (for development)"
	@echo "  all                Run full build process (default)"
	@echo "  clean              Remove build artifacts"
	@echo "  help               Show this help message"