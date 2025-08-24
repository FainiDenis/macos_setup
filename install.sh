#!/bin/zsh

# Description: This script automates the setup of a macOS environment.

# Load configuration
source ./config

# COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Functions
keep_sudo_alive() {
  echo "Enter root password:"
  read -s password
  echo $password | sudo -S true

  while true; do
    sudo -n true
    sleep 60
    kill -0 "$" || exit
  done 2>/dev/null &
}

update_macos() {
  echo
  echo "${GREEN}Looking for updates..${NC}"
  echo
  sudo softwareupdate -i -a
}

install_homebrew() {
  echo
  echo "${GREEN}Installing Homebrew${NC}"
  echo
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>${HOME}/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo
  echo "${GREEN}Checking installation..${NC}"
  echo
  brew update && brew doctor
  export HOMEBREW_NO_INSTALL_CLEANUP=1
}

install_brewfile() {
  echo
  echo "${GREEN}Brewfile found. Using it to install packages...${NC}"
  brew bundle
  echo "${GREEN}Installation from Brewfile complete.${NC}"
}

install_formulae() {
  echo
  echo "${GREEN}Installing formulae...${NC}"
  for formula in "${FORMULAE[@]}"; do
    brew install "$formula" || echo "${RED}Failed to install $formula. Continuing...${NC}"
  done
}

install_casks() {
  echo "${GREEN}Installing casks...${NC}"
  for cask in "${CASKS[@]}"; do
    brew install --cask "$cask" || echo "${RED}Failed to install $cask. Continuing...${NC}"
  done
}

install_app_store_apps() {
  brew install mas
    for app in "${APPSTORE[@]}"; do
      mas install "$app" || echo "${RED}Failed to install App Store app $app. Continuing...${NC}"
    done
}

install_vscode_extensions() {
  for extension in "${VSCODE[@]}"; do
    code --install-extension "$extension" || echo "${RED}Failed to install VSCode extension $extension. Continuing...${NC}"
  done
}

cleanup() {
  echo
  echo "${GREEN}Cleaning up...${NC}"
  brew update && brew upgrade && brew cleanup && brew doctor
  mkdir -p ~/Library/LaunchAgents
  brew tap homebrew/autoupdate
  brew autoupdate start $HOMEBREW_UPDATE_FREQUENCY --upgrade --cleanup --immediate --sudo
}

configure_dock() {
  brew install dockutil
  for item in "${DOCK_REPLACE[@]}"; do
    IFS="|" read -r add_app replace_app <<<"$item"
    dockutil --add "$add_app" --replacing "$replace_app" &>/dev/null
  done

  for app in "${DOCK_ADD[@]}"; do
    dockutil --add "$app" &>/dev/null
  done

  for app in "${DOCK_REMOVE[@]}"; do
    dockutil --remove "$app" &>/dev/null
  done
}

configure_git() {
  echo
  echo "${GREEN}SET UP GIT${NC}"
  echo
  git config --global user.name "$GIT_USERNAME"
  git config --global user.email "$GIT_EMAIL"
  git config --global color.ui true
  echo "${GREEN}Completed Git Configuration${NC}"
}

install_ohmyzsh() {
  echo
  echo "${GREEN}Installing ohmyzsh!${NC}"
  echo
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

reboot_system() {
  clear
  echo
  read -s -k $'?Press ANY KEY to REBOOT\n'
  sudo reboot
}

main() {
  keep_sudo_alive
  update_macos
  install_homebrew

  if [ -f "./Brewfile" ]; then
    install_brewfile
  else
    install_formulae
    install_casks
    install_app_store_apps
    install_vscode_extensions
  fi

  cleanup
  configure_macOS_settings
  configure_dock
  configure_git
  install_ohmyzsh
  reboot_system
}

# Call the main function to execute the script
main
