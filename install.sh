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

set_java_home() {
  echo
  echo "${GREEN}Setting JAVA_HOME...${NC}"
  echo "export JAVA_HOME=$JAVA_HOME" >> "$ZSHRC_FILE"
  echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> "$ZSHRC_FILE"
}

check_and_install_maven() {

  if ! command -v mvn &>/dev/null; then
    echo "${GREEN}Downloading and installing Maven...${NC}"
    if curl -L "$MAVEN_BIN_URL" -o /tmp/maven.zip; then
        sudo mkdir -p "$MAVEN_INSTALL_DIR" || { echo "${RED}Failed${NC}" "Could not create Maven install directory"; exit 1; }

        if sudo unzip -q /tmp/maven.zip -d /tmp; then
            # Remove existing directory if it exists
            sudo rm -rf "$MAVEN_HOME"
            
            # Move the unzipped directory to the correct location
            sudo mv "/tmp/apache-maven-$MAVEN_VERSION" "$MAVEN_HOME" || { echo "${RED}Failed${NC}" "Could not move Maven directory"; exit 1; }

            # Add Maven to PATH in .zshrc if not already present
            if ! grep -q "export MAVEN_HOME=$MAVEN_HOME" "$ZSHRC_FILE"; then
                echo "export MAVEN_HOME=$MAVEN_HOME" >> "$ZSHRC_FILE"
                echo 'export PATH="$MAVEN_HOME/bin:$PATH"' >> "$ZSHRC_FILE"
            fi
            
            # Clean up
            rm -f /tmp/maven.zip
            
            # Verify installation
            if "$MAVEN_HOME/bin/mvn" --version &>/dev/null; then
                echo "${GREEN}Maven $MAVEN_VERSION installed successfully${NC}"
            else
                echo "${RED}Maven installation verification failed${NC}"
                exit 1
            fi
        else
            echo "${RED}Failed to unzip Maven${NC}"
            exit 1
        fi
    else
        echo "${RED}Failed to download Maven${NC}"
        exit 1
    fi
else
    installed_version=$(mvn --version 2>/dev/null | head -n 1 | awk '{print $3}')
    echo "${GREEN}Maven already installed (version $installed_version)${NC}"
fi

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
  set_java_home
  check_and_install_maven
  configure_macOS_settings
  configure_dock
  configure_git
  install_ohmyzsh
  reboot_system
}

# Call the main function to execute the script
main
