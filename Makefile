# RemoteTerminal Makefile
# Quick commands for building and running the iOS SSH client

.PHONY: setup build run run-device xcode clean config status help

# Default target
.DEFAULT_GOAL := help

# Setup project (first time)
setup:
	@./start.sh setup

# Build project
build:
	@./start.sh build

# Build release
release:
	@./start.sh build Release

# Run on simulator
run:
	@./start.sh run

# Run on device
run-device:
	@./start.sh run -d

# Open in Xcode
xcode:
	@./start.sh xcode

# Clean build files
clean:
	@./start.sh clean

# Configure signing
config:
	@./start.sh config

# Show status
status:
	@./start.sh status

# Generate Xcode project only
generate:
	@xcodegen generate

# Install pods only
pods:
	@pod install

# Help
help:
	@echo "RemoteTerminal - iOS SSH Terminal Client"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  setup       First-time setup (generate project, install deps)"
	@echo "  build       Build the project (Debug)"
	@echo "  release     Build the project (Release)"
	@echo "  run         Build and run on simulator"
	@echo "  run-device  Build and run on connected device"
	@echo "  xcode       Open project in Xcode"
	@echo "  clean       Clean build files"
	@echo "  config      Configure signing"
	@echo "  status      Show project status"
	@echo "  generate    Regenerate Xcode project from project.yml"
	@echo "  pods        Install CocoaPods dependencies"
	@echo ""
	@echo "Quick start:"
	@echo "  make setup  # First time"
	@echo "  make run    # Run on simulator"
	@echo ""
