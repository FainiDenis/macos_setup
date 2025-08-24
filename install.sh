#!/bin/zsh

# Description: macOS setup script that loads configuration from separate config file
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/FainiDenis/macos_setup/main/install.sh)"

set -euo pipefail

# GitHub Configuration
GITHUB_USER="FainiDenis"
GITHUB_REPO="macos_setup"
GITHUB_BRANCH="main"
CONFIG_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() { echo -e "${2:-$NC}[${1}]${NC} ${3}"; }
log_info() { log "INFO" "$GREEN" "$1"; }
log_warn() { log "WARN" "$YELLOW" "$1"; }
log_error() { log "ERROR" "$RED" "$1" >&2; }
log_step() { log "STEP" "$BLUE" "$1"; }

# Error handling
handle_error() {
    log_error "Script failed at line $1 with exit code $2"
    [[ -n "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR" 2>/dev/null
    exit $2
}

# Temporary config file
TEMP_DIR=$(mktemp -d -t macos-setup-XXXXXX)
CONFIG_FILE="$TEMP_DIR/config"

cleanup() { rm -rf "$TEMP_DIR" 2>/dev/null && log_info "Cleaned temporary files"; }
trap 'cleanup' EXIT
trap 'handle_error $LINENO $?' ERR

# Download configuration
download_config() {
    log_step "Downloading configuration"
    
    if ! curl -fsSL "$CONFIG_URL" -o "$CONFIG_FILE"; then
        log_error "Failed to download config from: $CONFIG_URL"
        log_error "Please check:"
        log_error "  1. Repository exists and is public"
        log_error "  2. File 'config' exists in the repository"
        return 1
    fi
    
    log_info "Configuration downloaded"
}

# Load configuration
load_config() {
    [[ -f "$CONFIG_FILE" ]] || { log_error "Config file not found"; return 1; }
    
    # Source the configuration file
    if ! source "$CONFIG_FILE"; then
        log_error "Failed to load configuration"
        return 1
    fi
    
    # Run validation if available
    if command -v validate_config &>/dev/null; then
        validate_config || { log_error "Configuration validation failed"; return 1; }
    fi
    
    log_info "Configuration loaded successfully"
}

# Display banner
show_banner() {
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}    macOS Automated Setup       ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
    echo -e "${GREEN}Repository:${NC} https://github.com/$GITHUB_USER/$GITHUB_REPO"
    echo -e "${GREEN}System:${NC} $(sw_vers -productName) $(sw_vers -productVersion) ($(uname -m))"
    echo
}

# Confirmation
confirm_execution() {
    echo -e "${YELLOW}This script will:${NC}"
    echo "  • Install Homebrew and packages"
    echo "  • Configure macOS settings"
    echo "  • Set up development environment"
    echo
    
    read -r -p "Continue? (y/N): " REPLY
    [[ $REPLY =~ ^[Yy]$ ]] || { log_info "Setup cancelled"; exit 0; }
}

# Keep sudo alive
keep_sudo_alive() {
    sudo -v || { log_error "Failed to obtain sudo"; return 1; }
    
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
    
    log_info "Sudo privileges obtained"
}

# Install Homebrew
install_homebrew() {
    command -v brew &>/dev/null && { log_info "Homebrew already installed"; return 0; }
    
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        log_error "Failed to install Homebrew"; return 1;
    }
    
    # Add to PATH
    local brew_path="/opt/homebrew/bin/brew"
    [[ -f "$brew_path" ]] || brew_path="/usr/local/bin/brew"
    [[ -f "$brew_path" ]] || { log_error "Homebrew not found"; return 1; }
    
    echo "eval \"\$($brew_path shellenv)\"" >> "${HOME}/.zprofile"
    eval "\$($brew_path shellenv)"
    
    export HOMEBREW_NO_INSTALL_CLEANUP=1
    log_info "Homebrew installed"
}

# Install packages
install_packages() {
    local failed=()
    
    # Install formulae
    [[ -n "${FORMULAE:-}" ]] && for formula in "${FORMULAE[@]}"; do
        brew install "$formula" || { log_warn "Failed: $formula"; failed+=("$formula"); }
    done
    
    # Install regular casks
    [[ -n "${CASKS:-}" ]] && for cask in "${CASKS[@]}"; do
        # Skip sudo casks (handled separately)
        [[ -n "${SUDO_CASKS:-}" && " ${SUDO_CASKS[*]} " =~ " $cask " ]] && continue
        brew install --cask "$cask" || { log_warn "Failed: $cask"; failed+=("$cask"); }
    done
    
    # Install sudo casks with elevated privileges
    [[ -n "${SUDO_CASKS:-}" ]] && for cask in "${SUDO_CASKS[@]}"; do
        log_info "Installing sudo cask: $cask"
        sudo brew install --cask "$cask" || { log_warn "Failed sudo cask: $cask"; failed+=("$cask"); }
    done
    
    # Install App Store apps
    if [[ -n "${APPSTORE:-}" ]] && command -v mas &>/dev/null; then
        for app in "${APPSTORE[@]}"; do
            mas install "$app" || { log_warn "Failed App Store app: $app"; failed+=("$app"); }
        done
    fi
    
    # Install VSCode extensions
    if [[ -n "${VSCODE:-}" ]] && command -v code &>/dev/null; then
        for extension in "${VSCODE[@]}"; do
            code --install-extension "$extension" || { log_warn "Failed VSCode extension: $extension"; failed+=("$extension"); }
        done
    fi
    
    [[ ${#failed[@]} -eq 0 ]] || log_warn "Failed packages: ${failed[*]}"
}

# Configure Git
configure_git() {
    [[ -z "${GIT_USERNAME:-}" || -z "${GIT_EMAIL:-}" ]] && { log_warn "Git not configured"; return 0; }
    
    command -v git &>/dev/null || { log_warn "Git not found"; return 1; }
    
    git config --global user.name "$GIT_USERNAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global color.ui true
    
    log_info "Git configured"
}

# Configure Java
configure_java() {
    [[ -z "${JAVA_HOME:-}" ]] && { log_warn "Java not configured"; return 0; }
    [[ -d "$JAVA_HOME" ]] || { log_warn "Java not found at $JAVA_HOME"; return 1; }
    
    local zshrc="${HOME}/.zshrc"
    if ! grep -q "export JAVA_HOME=$JAVA_HOME" "$zshrc" 2>/dev/null; then
        echo "export JAVA_HOME=$JAVA_HOME" >> "$zshrc"
        echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> "$zshrc"
        log_info "Java environment configured"
    fi
}

# Install Maven
install_maven() {
    [[ -z "${MAVEN_VERSION:-}" || -z "${MAVEN_BIN_URL:-}" || -z "${MAVEN_HOME:-}" ]] && {
        log_warn "Maven not configured"; return 0;
    }
    
    command -v mvn &>/dev/null && { log_info "Maven already installed"; return 0; }
    
    log_step "Installing Maven $MAVEN_VERSION"
    
    local temp_dir=$(mktemp -d)
    local maven_zip="$temp_dir/maven.zip"
    
    curl -L "$MAVEN_BIN_URL" -o "$maven_zip" || { log_error "Failed to download Maven"; return 1; }
    
    sudo mkdir -p "$(dirname "$MAVEN_HOME")" || { log_error "Could not create Maven directory"; return 1; }
    sudo unzip -q "$maven_zip" -d "$(dirname "$MAVEN_HOME")" || { log_error "Failed to extract Maven"; return 1; }
    
    local zshrc="${HOME}/.zshrc"
    if ! grep -q "export MAVEN_HOME=$MAVEN_HOME" "$zshrc" 2>/dev/null; then
        echo "export MAVEN_HOME=$MAVEN_HOME" >> "$zshrc"
        echo 'export PATH="$MAVEN_HOME/bin:$PATH"' >> "$zshrc"
    fi
    
    rm -rf "$temp_dir"
    log_info "Maven installed"
}

# Configure system settings
configure_system() {
    [[ -z "${SETTINGS:-}" ]] && { log_warn "No system settings configured"; return 0; }
    
    # Create directories
    [[ -n "${SCREENSHOT_DIR:-}" ]] && mkdir -p "$SCREENSHOT_DIR"
    [[ -n "${DIRECTORIES_TO_CREATE:-}" ]] && for dir in "${DIRECTORIES_TO_CREATE[@]}"; do
        mkdir -p "$dir" 2>/dev/null || log_warn "Failed to create: $dir"
    done
    
    # Apply settings
    for setting in "${SETTINGS[@]}"; do
        eval "$setting" 2>/dev/null || log_warn "Failed setting: ${setting:0:50}"
    done
    
    # Restart services
    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
    
    log_info "System configured"
}

# Configure Dock
configure_dock() {
    command -v dockutil &>/dev/null || { log_warn "dockutil not found"; return 0; }
    
    # Replace dock items
    [[ -n "${DOCK_REPLACE:-}" ]] && for item in "${DOCK_REPLACE[@]}"; do
        if [[ "$item" == *"|"* ]]; then
            IFS="|" read -r add_app replace_app <<<"$item"
            dockutil --add "$add_app" --replacing "$replace_app" &>/dev/null || 
                log_warn "Failed to replace: $replace_app with $add_app"
        fi
    done
    
    # Add dock items
    [[ -n "${DOCK_ADD:-}" ]] && for app in "${DOCK_ADD[@]}"; do
        dockutil --add "$app" &>/dev/null || log_warn "Failed to add: $app"
    done
    
    # Remove dock items
    [[ -n "${DOCK_REMOVE:-}" ]] && for app in "${DOCK_REMOVE[@]}"; do
        dockutil --remove "$app" &>/dev/null || log_warn "Failed to remove: $app"
    done
    
    log_info "Dock configured"
}

# Cleanup Homebrew
cleanup_brew() {
    command -v brew &>/dev/null || return 0
    
    brew update || log_warn "Failed to update Homebrew"
    brew upgrade || log_warn "Failed to upgrade packages"
    brew cleanup || log_warn "Failed to cleanup"
    
    log_info "Homebrew cleanup completed"
}

# Main execution
main() {
    show_banner
    
    # Download and load configuration
    download_config || exit 1
    load_config || exit 1
    
    confirm_execution
    keep_sudo_alive || exit 1
    
    log_step "Starting setup"
    
    install_homebrew || exit 1
    install_packages
    configure_git
    configure_java
    install_maven
    configure_system
    configure_dock
    cleanup_brew
    
    log_info "Setup completed successfully!"
    log_info "Some changes may require a restart to take effect"
}

main "$@"