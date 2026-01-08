#!/bin/bash

# RemoteTerminal - iOS SSH Terminal Client
# Automated build and run script

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Print functions
print_info() {
    echo -e "${CYAN}i ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_NAME="RemoteTerminal"
WORKSPACE="${SCRIPT_DIR}/${PROJECT_NAME}.xcworkspace"
PROJECT="${SCRIPT_DIR}/${PROJECT_NAME}.xcodeproj"
SCHEME="${PROJECT_NAME}"
BUILD_DIR="${SCRIPT_DIR}/build"
LOG_FILE="/tmp/remoteterminal-build.log"

# Environment file
ENV_FILE="${SCRIPT_DIR}/.env"

# Load environment variables
load_env() {
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    fi
}

# Save environment variables
save_env() {
    echo "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM" > "$ENV_FILE"
    print_success "Development Team saved to .env"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Xcode installation
check_xcode() {
    if ! command_exists xcodebuild; then
        print_error "Xcode Command Line Tools not installed"
        print_info "Install with: xcode-select --install"
        return 1
    fi

    XCODE_VERSION=$(xcodebuild -version | head -1)
    print_success "$XCODE_VERSION"
    return 0
}

# Check CocoaPods
check_cocoapods() {
    if ! command_exists pod; then
        print_warning "CocoaPods not installed"
        print_info "Installing CocoaPods..."
        sudo gem install cocoapods
        if [ $? -ne 0 ]; then
            print_error "Failed to install CocoaPods"
            return 1
        fi
    fi
    print_success "CocoaPods $(pod --version)"
    return 0
}

# Check XcodeGen
check_xcodegen() {
    if ! command_exists xcodegen; then
        print_warning "XcodeGen not installed"
        print_info "Installing XcodeGen..."
        brew install xcodegen
        if [ $? -ne 0 ]; then
            print_error "Failed to install XcodeGen"
            print_info "Try: brew install xcodegen"
            return 1
        fi
    fi
    print_success "XcodeGen $(xcodegen --version)"
    return 0
}

# Check ios-deploy (optional, for device installation)
check_ios_deploy() {
    if ! command_exists ios-deploy; then
        print_warning "ios-deploy not installed (optional, for device installation)"
        print_info "Install with: brew install ios-deploy"
        return 1
    fi
    print_success "ios-deploy installed"
    return 0
}

# Check all dependencies
check_dependencies() {
    print_header "Checking Dependencies"

    local has_error=0

    check_xcode || has_error=1
    check_cocoapods || has_error=1
    check_xcodegen || has_error=1
    check_ios_deploy  # Optional, don't fail

    if [ $has_error -eq 1 ]; then
        print_error "Some required dependencies are missing"
        exit 1
    fi

    print_success "All required dependencies installed"
}

# Generate Xcode project
generate_project() {
    print_header "Generating Xcode Project"

    cd "$SCRIPT_DIR"

    # Check if project.yml exists
    if [ ! -f "project.yml" ]; then
        print_error "project.yml not found"
        exit 1
    fi

    # Generate project
    xcodegen generate
    if [ $? -ne 0 ]; then
        print_error "Failed to generate Xcode project"
        exit 1
    fi

    print_success "Xcode project generated"
}

# Install CocoaPods dependencies
install_pods() {
    print_header "Installing CocoaPods Dependencies"

    cd "$SCRIPT_DIR"

    # Check if Podfile exists
    if [ ! -f "Podfile" ]; then
        print_error "Podfile not found"
        exit 1
    fi

    pod install
    if [ $? -ne 0 ]; then
        print_error "Failed to install pods"
        exit 1
    fi

    print_success "CocoaPods dependencies installed"
}

# Configure signing
configure_signing() {
    print_header "Configuring Code Signing"

    load_env

    if [ -z "$DEVELOPMENT_TEAM" ]; then
        print_info "No Development Team configured"
        echo ""
        print_info "To find your Team ID:"
        print_info "1. Open Xcode > Preferences > Accounts"
        print_info "2. Select your Apple ID"
        print_info "3. Click 'Manage Certificates' and note your Team ID"
        echo ""
        read -p "Enter your Development Team ID (or press Enter to skip): " team_id

        if [ -n "$team_id" ]; then
            DEVELOPMENT_TEAM="$team_id"
            export DEVELOPMENT_TEAM
            save_env
        else
            print_warning "Skipping signing configuration"
            print_info "You can configure it later by running: ./start.sh config"
            return 0
        fi
    fi

    print_success "Development Team: $DEVELOPMENT_TEAM"
}

# Setup project (first time)
setup_project() {
    print_header "Setting Up RemoteTerminal"

    check_dependencies
    configure_signing
    generate_project
    install_pods

    echo ""
    print_success "Setup complete!"
    echo ""
    print_info "Next steps:"
    print_info "  ./start.sh build    - Build the project"
    print_info "  ./start.sh run      - Build and run on simulator"
    print_info "  ./start.sh run -d   - Build and run on device"
    echo ""
}

# Build project
build_project() {
    local config="${1:-Debug}"

    print_header "Building RemoteTerminal ($config)"

    load_env

    # Use workspace if exists (for CocoaPods)
    if [ -d "$WORKSPACE" ]; then
        BUILD_CMD="xcodebuild -workspace $WORKSPACE -scheme $SCHEME -configuration $config"
    elif [ -d "$PROJECT" ]; then
        BUILD_CMD="xcodebuild -project $PROJECT -scheme $SCHEME -configuration $config"
    else
        print_error "No Xcode project found. Run './start.sh setup' first."
        exit 1
    fi

    # Add team if configured
    if [ -n "$DEVELOPMENT_TEAM" ]; then
        BUILD_CMD="$BUILD_CMD DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM"
    fi

    print_info "Building..."
    $BUILD_CMD build 2>&1 | tee "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        print_error "Build failed. See log: $LOG_FILE"
        exit 1
    fi

    print_success "Build succeeded"
}

# Run on simulator
run_simulator() {
    local config="${1:-Debug}"

    print_header "Running on iOS Simulator"

    load_env

    # Get available simulators
    print_info "Available simulators:"
    xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10

    # Use workspace if exists
    if [ -d "$WORKSPACE" ]; then
        BUILD_CMD="xcodebuild -workspace $WORKSPACE -scheme $SCHEME -configuration $config"
    else
        BUILD_CMD="xcodebuild -project $PROJECT -scheme $SCHEME -configuration $config"
    fi

    # Add team if configured
    if [ -n "$DEVELOPMENT_TEAM" ]; then
        BUILD_CMD="$BUILD_CMD DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM"
    fi

    # Find a booted simulator or boot one
    SIMULATOR_ID=$(xcrun simctl list devices booted -j | python3 -c "import sys, json; devices = json.load(sys.stdin)['devices']; print(next((d['udid'] for v in devices.values() for d in v if d.get('state') == 'Booted'), ''))" 2>/dev/null)

    if [ -z "$SIMULATOR_ID" ]; then
        print_info "No simulator running. Booting iPhone 15 Pro..."
        SIMULATOR_ID=$(xcrun simctl list devices available -j | python3 -c "import sys, json; devices = json.load(sys.stdin)['devices']; print(next((d['udid'] for v in devices.values() for d in v if 'iPhone 15 Pro' in d.get('name', '') and d.get('isAvailable')), ''))" 2>/dev/null)

        if [ -n "$SIMULATOR_ID" ]; then
            xcrun simctl boot "$SIMULATOR_ID"
            open -a Simulator
            sleep 3
        fi
    fi

    print_info "Building and running..."
    $BUILD_CMD -destination "platform=iOS Simulator,id=$SIMULATOR_ID" build 2>&1 | tee "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        print_error "Build failed. See log: $LOG_FILE"
        exit 1
    fi

    # Find and install the app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "RemoteTerminal.app" -path "*Debug-iphonesimulator*" -type d 2>/dev/null | head -1)

    if [ -n "$APP_PATH" ]; then
        print_info "Installing app..."
        xcrun simctl install booted "$APP_PATH"
        print_info "Launching app..."
        xcrun simctl launch booted "com.remoteterminal.app"
        print_success "App launched on simulator"
    else
        print_warning "Could not find built app. Try opening in Xcode."
    fi
}

# Run on device
run_device() {
    local config="${1:-Debug}"

    print_header "Running on iOS Device"

    load_env

    if [ -z "$DEVELOPMENT_TEAM" ]; then
        print_error "Development Team not configured"
        print_info "Run './start.sh config' to configure signing"
        exit 1
    fi

    if ! command_exists ios-deploy; then
        print_error "ios-deploy not installed"
        print_info "Install with: brew install ios-deploy"
        print_info "Or use Xcode to run on device"
        exit 1
    fi

    # Build for device
    if [ -d "$WORKSPACE" ]; then
        BUILD_CMD="xcodebuild -workspace $WORKSPACE -scheme $SCHEME -configuration $config"
    else
        BUILD_CMD="xcodebuild -project $PROJECT -scheme $SCHEME -configuration $config"
    fi

    BUILD_CMD="$BUILD_CMD DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM"
    BUILD_CMD="$BUILD_CMD -destination 'generic/platform=iOS'"

    print_info "Building for device..."
    eval $BUILD_CMD build 2>&1 | tee "$LOG_FILE"

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        print_error "Build failed. See log: $LOG_FILE"
        exit 1
    fi

    # Find the app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "RemoteTerminal.app" -path "*Debug-iphoneos*" -type d 2>/dev/null | head -1)

    if [ -n "$APP_PATH" ]; then
        print_info "Installing on device..."
        ios-deploy --bundle "$APP_PATH" --debug
    else
        print_error "Could not find built app"
        exit 1
    fi
}

# Open in Xcode
open_xcode() {
    print_header "Opening in Xcode"

    if [ -d "$WORKSPACE" ]; then
        open "$WORKSPACE"
        print_success "Opened workspace in Xcode"
    elif [ -d "$PROJECT" ]; then
        open "$PROJECT"
        print_success "Opened project in Xcode"
    else
        print_error "No Xcode project found. Run './start.sh setup' first."
        exit 1
    fi
}

# Clean build
clean_build() {
    print_header "Cleaning Build"

    rm -rf "$BUILD_DIR"
    rm -rf ~/Library/Developer/Xcode/DerivedData/RemoteTerminal-*
    rm -f "$LOG_FILE"

    print_success "Build cleaned"
}

# Show status
show_status() {
    print_header "Project Status"

    load_env

    # Check project files
    if [ -d "$WORKSPACE" ]; then
        print_success "Workspace: $WORKSPACE"
    elif [ -d "$PROJECT" ]; then
        print_success "Project: $PROJECT"
    else
        print_warning "No Xcode project (run './start.sh setup')"
    fi

    # Check Pods
    if [ -d "${SCRIPT_DIR}/Pods" ]; then
        print_success "Pods installed"
    else
        print_warning "Pods not installed"
    fi

    # Check signing
    if [ -n "$DEVELOPMENT_TEAM" ]; then
        print_success "Development Team: $DEVELOPMENT_TEAM"
    else
        print_warning "Development Team not configured"
    fi

    # Version
    if [ -f "${SCRIPT_DIR}/VERSION" ]; then
        VERSION=$(cat "${SCRIPT_DIR}/VERSION")
        print_info "Version: $VERSION"
    fi
}

# Show help
show_help() {
    echo "RemoteTerminal - iOS SSH Terminal Client"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup       First-time setup (generate project, install deps)"
    echo "  build       Build the project"
    echo "  run         Build and run on simulator"
    echo "  run -d      Build and run on connected device"
    echo "  xcode       Open project in Xcode"
    echo "  clean       Clean build files"
    echo "  config      Configure signing"
    echo "  status      Show project status"
    echo "  help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 setup              # First time setup"
    echo "  $0 run                # Run on simulator"
    echo "  $0 run -d             # Run on device"
    echo "  $0 build Release      # Release build"
    echo ""
}

# Main
main() {
    case "$1" in
        setup)
            setup_project
            ;;
        build)
            build_project "$2"
            ;;
        run)
            if [ "$2" = "-d" ] || [ "$2" = "--device" ]; then
                run_device "$3"
            else
                run_simulator "$2"
            fi
            ;;
        xcode)
            open_xcode
            ;;
        clean)
            clean_build
            ;;
        config)
            configure_signing
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            if [ -n "$1" ]; then
                print_error "Unknown command: $1"
                echo ""
            fi
            show_help
            exit 1
            ;;
    esac
}

# Run
main "$@"
