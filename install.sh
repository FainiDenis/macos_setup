#!/bin/zsh

# Description: This script automates the setup of a macOS environment with improved error handling.

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Load configuration with error checking
if [[ -f "./config" ]]; then
    source ./config
else
    echo "Error: Configuration file './config' not found!"
    exit 1
fi

# COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Script failed at line $line_number with exit code $exit_code"
    exit $exit_code
}

# Set up error trap
trap 'handle_error $LINENO' ERR

# Functions
keep_sudo_alive() {
    log_info "Requesting sudo privileges..."
    
    if ! sudo -v; then
        log_error "Failed to obtain sudo privileges"
        return 1
    fi
    
    # Keep sudo alive in background
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
    
    log_info "Sudo privileges obtained and kept alive"
}

update_macos() {
    log_info "Checking for macOS updates..."
    
    if ! command -v softwareupdate &>/dev/null; then
        log_error "softwareupdate command not found"
        return 1
    fi
    
    if sudo softwareupdate -l 2>/dev/null | grep -q "No new software available"; then
        log_info "No macOS updates available"
    else
        log_info "Installing macOS updates..."
        if ! sudo softwareupdate -i -a; then
            log_error "Failed to install macOS updates"
            return 1
        fi
    fi
}

install_homebrew() {
    log_info "Installing Homebrew..."
    
    # Check if Homebrew is already installed
    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed"
        return 0
    fi
    
    # Install Homebrew
    if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        log_error "Failed to install Homebrew"
        return 1
    fi
    
    # Add Homebrew to PATH
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${HOME}/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "${HOME}/.zprofile"
        eval "$(/usr/local/bin/brew shellenv)"
    else
        log_error "Homebrew installation location not found"
        return 1
    fi
    
    # Verify installation
    log_info "Verifying Homebrew installation..."
    if ! brew update && brew doctor; then
        log_warn "Homebrew doctor reported issues, but continuing..."
    fi
    
    export HOMEBREW_NO_INSTALL_CLEANUP=1
    log_info "Homebrew installed successfully"
}

install_brewfile() {
    if [[ ! -f "./Brewfile" ]]; then
        log_error "Brewfile not found in current directory"
        return 1
    fi
    
    log_info "Installing packages from Brewfile..."
    
    if ! brew bundle --file="./Brewfile"; then
        log_error "Failed to install from Brewfile"
        return 1
    fi
    
    log_info "Brewfile installation completed"
}

install_formulae() {
    if [[ -z "${FORMULAE:-}" ]] || [[ ${#FORMULAE[@]} -eq 0 ]]; then
        log_warn "No formulae specified in configuration"
        return 0
    fi
    
    log_info "Installing formulae..."
    local failed_formulae=()
    
    for formula in "${FORMULAE[@]}"; do
        log_info "Installing formula: $formula"
        if ! brew install "$formula"; then
            log_error "Failed to install formula: $formula"
            failed_formulae+=("$formula")
        fi
    done
    
    if [[ ${#failed_formulae[@]} -gt 0 ]]; then
        log_warn "Failed to install formulae: ${failed_formulae[*]}"
    fi
}

install_casks() {
    if [[ -z "${CASKS:-}" ]] || [[ ${#CASKS[@]} -eq 0 ]]; then
        log_warn "No casks specified in configuration"
        return 0
    fi
    
    log_info "Installing casks..."
    local failed_casks=()
    
    for cask in "${CASKS[@]}"; do
        log_info "Installing cask: $cask"
        if ! sudo brew install --cask "$cask"; then
            log_error "Failed to install cask: $cask"
            failed_casks+=("$cask")
        fi
    done
    
    if [[ ${#failed_casks[@]} -gt 0 ]]; then
        log_warn "Failed to install casks: ${failed_casks[*]}"
    fi
}

install_app_store_apps() {
    if [[ -z "${APPSTORE:-}" ]] || [[ ${#APPSTORE[@]} -eq 0 ]]; then
        log_warn "No App Store apps specified in configuration"
        return 0
    fi
    
    # Check if mas is installed
    if ! command -v mas &>/dev/null; then
        log_error "mas (Mac App Store CLI) is not installed. Install it first with: brew install mas"
        return 1
    fi
    
    # Check if signed into App Store
    if ! mas account &>/dev/null; then
        log_error "Not signed into Mac App Store. Please sign in first."
        return 1
    fi
    
    log_info "Installing App Store apps..."
    local failed_apps=()
    
    for app in "${APPSTORE[@]}"; do
        log_info "Installing App Store app: $app"
        if ! mas install "$app"; then
            log_error "Failed to install App Store app: $app"
            failed_apps+=("$app")
        fi
    done
    
    if [[ ${#failed_apps[@]} -gt 0 ]]; then
        log_warn "Failed to install App Store apps: ${failed_apps[*]}"
    fi
}

install_vscode_extensions() {
    if [[ -z "${VSCODE:-}" ]] || [[ ${#VSCODE[@]} -eq 0 ]]; then
        log_warn "No VSCode extensions specified in configuration"
        return 0
    fi
    
    # Check if code command is available
    if ! command -v code &>/dev/null; then
        log_error "VSCode 'code' command not found. Make sure VSCode is installed and added to PATH."
        return 1
    fi
    
    log_info "Installing VSCode extensions..."
    local failed_extensions=()
    
    for extension in "${VSCODE[@]}"; do
        log_info "Installing VSCode extension: $extension"
        if ! code --install-extension "$extension"; then
            log_error "Failed to install VSCode extension: $extension"
            failed_extensions+=("$extension")
        fi
    done
    
    if [[ ${#failed_extensions[@]} -gt 0 ]]; then
        log_warn "Failed to install VSCode extensions: ${failed_extensions[*]}"
    fi
}

set_java_home() {
    if [[ -z "${JAVA_HOME:-}" ]]; then
        log_warn "JAVA_HOME not set in configuration, skipping Java configuration"
        return 0
    fi
    
    if [[ -z "${ZSHRC_FILE:-}" ]]; then
        ZSHRC_FILE="${HOME}/.zshrc"
    fi
    
    log_info "Configuring Java environment..."
    
    # Check if Java is actually installed at the specified path
    if [[ ! -d "$JAVA_HOME" ]]; then
        log_error "Java installation not found at $JAVA_HOME"
        return 1
    fi
    
    # Check if already configured
    if ! grep -q "export JAVA_HOME=$JAVA_HOME" "$ZSHRC_FILE" 2>/dev/null; then
        echo "export JAVA_HOME=$JAVA_HOME" >> "$ZSHRC_FILE"
        echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> "$ZSHRC_FILE"
        log_info "Java environment configured in $ZSHRC_FILE"
    else
        log_info "Java environment already configured"
    fi
}

check_and_install_maven() {
    # Check if Maven variables are set
    if [[ -z "${MAVEN_VERSION:-}" ]] || [[ -z "${MAVEN_BIN_URL:-}" ]] || [[ -z "${MAVEN_HOME:-}" ]] || [[ -z "${MAVEN_INSTALL_DIR:-}" ]]; then
        log_warn "Maven configuration variables not set, skipping Maven installation"
        return 0
    fi
    
    if [[ -z "${ZSHRC_FILE:-}" ]]; then
        ZSHRC_FILE="${HOME}/.zshrc"
    fi
    
    if command -v mvn &>/dev/null; then
        local installed_version
        installed_version=$(mvn --version 2>/dev/null | head -n 1 | awk '{print $3}')
        log_info "Maven already installed (version $installed_version)"
        return 0
    fi
    
    log_info "Installing Maven $MAVEN_VERSION..."
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    local maven_zip="$temp_dir/maven.zip"
    
    # Download Maven
    if ! curl -L "$MAVEN_BIN_URL" -o "$maven_zip"; then
        log_error "Failed to download Maven from $MAVEN_BIN_URL"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Create install directory
    if ! sudo mkdir -p "$MAVEN_INSTALL_DIR"; then
        log_error "Could not create Maven install directory: $MAVEN_INSTALL_DIR"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract Maven
    if ! sudo unzip -q "$maven_zip" -d "$temp_dir"; then
        log_error "Failed to extract Maven"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Remove existing installation
    if [[ -d "$MAVEN_HOME" ]]; then
        sudo rm -rf "$MAVEN_HOME"
    fi
    
    # Move Maven to final location
    if ! sudo mv "$temp_dir/apache-maven-$MAVEN_VERSION" "$MAVEN_HOME"; then
        log_error "Could not move Maven to $MAVEN_HOME"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Configure environment
    if ! grep -q "export MAVEN_HOME=$MAVEN_HOME" "$ZSHRC_FILE" 2>/dev/null; then
        echo "export MAVEN_HOME=$MAVEN_HOME" >> "$ZSHRC_FILE"
        echo 'export PATH="$MAVEN_HOME/bin:$PATH"' >> "$ZSHRC_FILE"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Verify installation
    if "$MAVEN_HOME/bin/mvn" --version &>/dev/null; then
        log_info "Maven $MAVEN_VERSION installed successfully"
    else
        log_error "Maven installation verification failed"
        return 1
    fi
}

cleanup() {
    log_info "Cleaning up Homebrew..."
    
    if ! command -v brew &>/dev/null; then
        log_warn "Homebrew not found, skipping cleanup"
        return 0
    fi
    
    if ! brew update; then
        log_warn "Failed to update Homebrew"
    fi
    
    if ! brew upgrade; then
        log_warn "Failed to upgrade Homebrew packages"
    fi
    
    if ! brew cleanup; then
        log_warn "Failed to cleanup Homebrew"
    fi
    
    if ! brew doctor; then
        log_warn "Homebrew doctor reported issues"
    fi
    
    # Set up auto-update if configured
    if [[ -n "${HOMEBREW_UPDATE_FREQUENCY:-}" ]]; then
        mkdir -p ~/Library/LaunchAgents
        
        if brew tap homebrew/autoupdate 2>/dev/null; then
            # Convert frequency to the correct format for brew autoupdate
            if ! brew autoupdate start "${HOMEBREW_UPDATE_FREQUENCY}" --upgrade --cleanup --immediate; then
                log_warn "Failed to set up Homebrew auto-update"
            else
                log_info "Homebrew auto-update configured for every ${HOMEBREW_UPDATE_FREQUENCY} seconds"
            fi
        else
            log_warn "Failed to tap homebrew/autoupdate"
        fi
    fi
}

configure_dock() {
    # Check if dockutil is available
    if ! command -v dockutil &>/dev/null; then
        log_warn "dockutil not found, skipping dock configuration"
        return 0
    fi
    
    log_info "Configuring dock..."
    
    # Replace dock items
    if [[ -n "${DOCK_REPLACE:-}" ]] && [[ ${#DOCK_REPLACE[@]} -gt 0 ]]; then
        for item in "${DOCK_REPLACE[@]}"; do
            if [[ "$item" == *"|"* ]]; then
                IFS="|" read -r add_app replace_app <<<"$item"
                if [[ -n "$add_app" ]] && [[ -n "$replace_app" ]]; then
                    if ! dockutil --add "$add_app" --replacing "$replace_app" &>/dev/null; then
                        log_warn "Failed to replace dock item: $replace_app with $add_app"
                    fi
                fi
            fi
        done
    fi
    
    # Add dock items
    if [[ -n "${DOCK_ADD:-}" ]] && [[ ${#DOCK_ADD[@]} -gt 0 ]]; then
        for app in "${DOCK_ADD[@]}"; do
            if ! dockutil --add "$app" &>/dev/null; then
                log_warn "Failed to add dock item: $app"
            fi
        done
    fi
    
    # Remove dock items
    if [[ -n "${DOCK_REMOVE:-}" ]] && [[ ${#DOCK_REMOVE[@]} -gt 0 ]]; then
        for app in "${DOCK_REMOVE[@]}"; do
            if ! dockutil --remove "$app" &>/dev/null; then
                log_warn "Failed to remove dock item: $app"
            fi
        done
    fi
    
    log_info "Dock configuration completed"
}

configure_git() {
    if [[ -z "${GIT_USERNAME:-}" ]] || [[ -z "${GIT_EMAIL:-}" ]]; then
        log_warn "Git username or email not configured, skipping Git setup"
        return 0
    fi
    
    log_info "Configuring Git..."
    
    if ! command -v git &>/dev/null; then
        log_error "Git not found"
        return 1
    fi
    
    git config --global user.name "$GIT_USERNAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global color.ui true
    
    log_info "Git configuration completed"
}

install_ohmyzsh() {
    # Check if Oh My Zsh is already installed
    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        log_info "Oh My Zsh already installed"
        return 0
    fi
    
    log_info "Installing Oh My Zsh..."
    
    if ! sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        log_error "Failed to install Oh My Zsh"
        return 1
    fi
    
    log_info "Oh My Zsh installed successfully"
}

configure_macos_settings() {
    if [[ -z "${SETTINGS:-}" ]] || [[ ${#SETTINGS[@]} -eq 0 ]]; then
        log_warn "No macOS settings specified in configuration"
        return 0
    fi
    
    log_info "Configuring macOS settings..."
    local failed_settings=()
    
    # Create screenshot directory if specified
    if [[ -n "${SCREENSHOT_DIR:-}" ]]; then
        mkdir -p "$SCREENSHOT_DIR" 2>/dev/null || log_warn "Failed to create screenshot directory"
    fi
    
    # Create additional directories
    if [[ -n "${DIRECTORIES_TO_CREATE:-}" ]] && [[ ${#DIRECTORIES_TO_CREATE[@]} -gt 0 ]]; then
        for dir in "${DIRECTORIES_TO_CREATE[@]}"; do
            if ! mkdir -p "$dir" 2>/dev/null; then
                log_warn "Failed to create directory: $dir"
            fi
        done
    fi
    
    # Apply system settings
    for setting in "${SETTINGS[@]}"; do
        log_info "Applying setting: ${setting:0:50}..."
        if ! eval "$setting" 2>/dev/null; then
            log_warn "Failed to apply setting: $setting"
            failed_settings+=("$setting")
        fi
    done
    
    # Restart affected services
    log_info "Restarting Finder and Dock to apply changes..."
    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
    
    if [[ ${#failed_settings[@]} -gt 0 ]]; then
        log_warn "Failed to apply ${#failed_settings[@]} settings"
    else
        log_info "All macOS settings applied successfully"
    fi
}

reboot_system() {
    echo
    log_info "Setup completed! Press any key to reboot the system..."
    read -k1 -s
    
    if ! sudo reboot; then
        log_error "Failed to reboot system"
        return 1
    fi
}

main() {
    log_info "Starting macOS setup script..."
    
    # Keep sudo alive
    if ! keep_sudo_alive; then
        log_error "Failed to obtain sudo privileges"
        exit 1
    fi
    
    # Update macOS
    update_macos || log_warn "macOS update step failed, continuing..."
    
    # Install Homebrew
    if ! install_homebrew; then
        log_error "Homebrew installation failed"
        exit 1
    fi
    
    # Install packages
    if [[ -f "./Brewfile" ]]; then
        install_brewfile || log_warn "Brewfile installation had issues, continuing..."
    else
        install_formulae || log_warn "Formula installation had issues, continuing..."
        install_casks || log_warn "Cask installation had issues, continuing..."
        install_app_store_apps || log_warn "App Store installation had issues, continuing..."
        install_vscode_extensions || log_warn "VSCode extension installation had issues, continuing..."
    fi
    
    # Configuration steps
    cleanup || log_warn "Cleanup had issues, continuing..."
    set_java_home || log_warn "Java configuration had issues, continuing..."
    check_and_install_maven || log_warn "Maven installation had issues, continuing..."
    configure_macos_settings || log_warn "macOS settings configuration had issues, continuing..."
    configure_dock || log_warn "Dock configuration had issues, continuing..."
    configure_git || log_warn "Git configuration had issues, continuing..."
    install_ohmyzsh || log_warn "Oh My Zsh installation had issues, continuing..."
    
    log_info "macOS setup completed!"
    #reboot_system
}

# Call the main function to execute the script
main "$@"