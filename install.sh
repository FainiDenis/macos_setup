#!/usr/bin/env bash

###############################################################################
#  macOS Setup Script
#  This script automates the setup of a new or reset macOS environment
#  by installing essential software and configuring system settings.
#  (c) 2025 • MIT License
###############################################################################

#  Colors / log helpers
GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'
RED=$'\033[0;31m';   YELLOW=$'\033[1;33m'; NC=$'\033[0m'; BOLD=$'\033[1m'

log_info()    { printf '%sℹ️  %s%s\n'  "$BLUE"  "$1" "$NC"; }
log_success() { printf '%s✅ %s%s\n'  "$GREEN" "$1" "$NC"; }
log_warning() { printf '%s⚠️  %s%s\n' "$YELLOW" "$1" "$NC"; }
log_error()   { printf '%s❌ %s%s\n'  "$RED"   "$1" "$NC"; }

#  Robust shell behavior & cleanup
set -Eeuo pipefail

cleanup() {
  tput cnorm || true    # control cursor visibility
}

trap cleanup EXIT
trap 'log_error "Interrupted"; exit 1' INT HUP TERM
trap 'log_error "Line $LINENO (exit $?) – $BASH_COMMAND"; exit 1' ERR

#  Progress-bar helpers
BAR_W=30
show_bar() {
  local pct=$1 msg=$2
  local done=$(( BAR_W * pct / 100 ))
  local todo=$(( BAR_W - done ))
  printf '\r\033[K%s┃%s' "$BLUE" "$NC"
  printf '%*s' "$done" '' | tr ' ' '█'
  printf '%*s' "$todo" '' | tr ' ' '░'
  printf '%s┃ %3d%% %s%s' "$BLUE" "$pct" "$msg" "$NC"
}
newline_below_bar() { printf '\n'; }

#  Application lists
HOMEBREW_PACKAGES=(
    git
    curl
    python3
    tree
    htop
    mas
)

CASK_PACKAGES=(
    firefox
    rectangle
    mountain-duck
    hazel
    vlc
    appcleaner
    iterm2
    stremio
    visual-studio-code
    libreoffice

    # require password
    zoom
    tailscale
    windows-app
    #wireshark
)

MAS_APPS=(
    "897118787:Shazam"
    "1564384601:Evermusic"
    "1530145038:Amperfy Music"
)

#  Welcome
welcome() {
  echo "======================================================"
  log_info   "🎯  macOS Setup Script"
  echo "======================================================"
  log_warning "You'll be prompted for your password when needed."
  echo "1. Please make sure you reviewed this script before running it."
  echo "2. Ensure a stable internet connection"
  echo
  read -p "Press ENTER to continue or CTRL-C to quit…"
}

#  Homebrew – install or update/upgrade
brew_bootstrap() {
  if ! command -v brew &>/dev/null; then
    log_info "Homebrew not found → installing…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ $(uname -m) == arm64 ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    log_info "Homebrew found → updating & upgrading…"
    brew update; brew upgrade; brew cleanup
  fi
}

#  Install Homebrew packages
install_brew_packages() {
  local total=${#HOMEBREW_PACKAGES[@]} current=0 pct
  show_bar 0 "starting…"; newline_below_bar
  
  for package in "${HOMEBREW_PACKAGES[@]}"; do
    current=$((current+1)); pct=$(( current * 100 / total ))
    
    if brew list --formula | grep -q "^$package\$"; then
      show_bar "$pct" "✓ already installed $package"; newline_below_bar; continue
    fi
    
    show_bar "$pct" "↓ $package"; newline_below_bar
    brew install "$package" && show_bar "$pct" "✔︎ $package"; newline_below_bar
  done
}

#  Install Cask packages
install_cask_packages() {
  local total=${#CASK_PACKAGES[@]} current=0 pct
  show_bar 0 "starting…"; newline_below_bar
  
  for package in "${CASK_PACKAGES[@]}"; do
    current=$((current+1)); pct=$(( current * 100 / total ))
    
    if brew list --cask | grep -q "^$package\$"; then
      show_bar "$pct" "✓ already installed $package"; newline_below_bar; continue
    fi
    
    show_bar "$pct" "↓ $package"; newline_below_bar
    brew install --cask "$package" && show_bar "$pct" "✔︎ $package"; newline_below_bar
  done
}

#  Install MAS items
install_mas_items() {
  command -v mas >/dev/null || brew install mas
  
  # Try to get installed apps, but continue if it fails (macOS 14+ issue)
  local installed_apps=()
  if mas list &>/dev/null; then
    installed_apps=($(mas list | awk '{print $1}'))
  else
    log_warning "Cannot read App Store account status; installs may prompt or fail."
  fi

  local total=${#MAS_APPS[@]} current=0 id name pct
  show_bar 0 "starting…"; newline_below_bar
  
  for entry in "${MAS_APPS[@]}"; do
    current=$((current+1)); pct=$(( current * 100 / total ))
    id=${entry%%:*}; name=${entry#*:}

    if [[ " ${installed_apps[@]-} " == *" $id "* ]]; then
      show_bar "$pct" "✓ already installed $name"; newline_below_bar; continue
    fi

    show_bar "$pct" "↓ $name"; newline_below_bar
    if mas install "$id"; then
      show_bar "$pct" "✔︎ $name"; newline_below_bar
    else
      log_warning "failed: $name"
    fi
  done
  
  # Attempt a bulk upgrade; ignore errors
  mas upgrade || true
}

#  Configure macOS settings
configure_system() {
    # https://macos-defaults.com
    log_info "Configuring System Preferences…"
    
    defaults write com.apple.finder AppleShowAllFiles -bool true  # Show hidden files in Finder
    mkdir -p "$HOME/Documents/Screenshots"    # Create screenshots directory
    defaults write com.apple.screencapture location "$HOME/Screenshots"   # Set screenshot location
    defaults write com.apple.dock autohide -bool true # Auto-hide Dock
    defaults write com.apple.dock tilesize -int 30    # Set Dock icon size
    defaults write -g com.apple.mouse.scaling 3.0 # Set mouse speed
    defaults write -g com.apple.trackpad.scaling 3.0 # Set trackpad
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true  # Disable .DS_Store on network drives
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # Set Finder to list view
  
    # Restart affected services
    killall Finder Dock SystemUIServer 2>/dev/null || true
    log_success "System Preferences applied"
}

#  Install Oh My Zsh and plugins
setup_zsh() {
  log_info "Configuring Z-shell…"
  [[ -f ~/.zshrc ]] && mv ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
  prefix=$(brew --prefix)
  cat > ~/.zshrc <<EOF
[[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]] &&
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"

source $prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh
source $prefix/share/powerlevel10k/powerlevel10k.zsh-theme

autoload -U compinit && compinit
alias c='clear' rmm='rm -rf' lss='ls -lah' reload='source ~/.zshrc'
alias t='tmux' e='code' z='zed' mtop='macmon'
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF
  [[ $SHELL != "$(which zsh)" ]] && chsh -s "$(which zsh)"
  log_success "Z-shell configured."
}

#  Main
main() {
  welcome
  newline_below_bar
  
  # Install and configure Homebrew
  brew_bootstrap
  newline_below_bar
  
  # Install packages
  log_info "Installing Homebrew packages…"; newline_below_bar
  install_brew_packages
  newline_below_bar
  
  log_info "Installing Cask packages…"; newline_below_bar
  install_cask_packages
  newline_below_bar
  
  log_info "Installing Mac App Store apps…"; newline_below_bar
  install_mas_items
  newline_below_bar
  
  # Configure system
  configure_system
  newline_below_bar
  
  # Set up shell environment
  setup_zsh
  newline_below_bar
  
  echo -e "\n${GREEN}${BOLD}✨  All done! Please consider rebooting.${NC}"
}

main "$@"