# macOS Setup Script

A robust, user-friendly Bash script that automates the setup and configuration of a new or reset macOS environment. This script installs essential software, configures system preferences, and sets up a development-ready shell environment.

## ✨ Features

- **Homebrew Management**: Automatically installs or updates Homebrew package manager
- **Package Installation**: Installs essential command-line tools, GUI applications, and Mac App Store apps
- **System Configuration**: Applies optimized macOS system preferences and defaults
- **Shell Setup**: Configures Zsh with popular plugins and Powerlevel10k theme
- **Error Handling**: Comprehensive error handling and cleanup routines

## 📦 Included Software

### Homebrew Packages
- `git` - Version control system
- `curl` - Command-line tool for transferring data
- `python3` - Python programming language
- `tree` - Directory listing utility
- `htop` - Interactive process viewer
- `mas` - Mac App Store command-line interface

### GUI Applications (Cask)
- `firefox` - Web browser
- `rectangle` - Window management tool
- `mountain-duck` - Cloud storage client
- `hazel` - Automated file organization
- `vlc` - Media player
- `appcleaner` - Application uninstaller
- `iterm2` - Terminal emulator
- `stremio` - Media center
- `visual-studio-code` - Code editor
- `libreoffice` - Office suite
- `zoom` - Video conferencing
- `tailscale` - VPN service
- `windows-app` - Windows application support

### Mac App Store Applications
- Shazam (ID: 897118787) - Music identification
- Evermusic (ID: 1564384601) - Music player
- Amperfy Music (ID: 1530145038) - Music streaming client

## 🛠️ System Configuration

The script applies these macOS optimizations:

- Shows hidden files in Finder
- Sets custom screenshot location (~/Documents/Screenshots)
- Enables Dock auto-hide with smaller icons
- Configures mouse and trackpad speed
- Disables .DS_Store files on network drives
- Sets Finder to list view by default

## 🚀 Usage

1. **Review the script** to ensure it meets your needs
2. **Run the script**:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/FainiDenis/macos_setup/main/install.sh)"
   ```
3. **Follow the prompts** and enter your password when required

## ⚙️ Customization

### Adding Packages
Edit the arrays in the script to add your preferred packages:

```bash
HOMEBREW_PACKAGES=(
    your-package-here
)

CASK_PACKAGES=(
    your-cask-package-here
)

MAS_APPS=(
    "app-store-id:App Name"
)
```

### Modifying System Settings
Adjust the `configure_system()` function to change macOS defaults. Refer to [macOS Defaults](https://macos-defaults.com) for available options.

## 🔧 Requirements

- macOS 10.14 or later
- Internet connection
- Administrator privileges

## 🛡️ Safety Features

- **Backup protection**: Existing .zshrc files are backed up before modification
- **Error trapping**: Script exits on critical errors with informative messages
- **Interrupt handling**: Clean exit on user interruption (Ctrl+C)
- **Dependency checking**: Verifies commands are available before use

## 📝 License

MIT License - feel free to modify and distribute as needed.

## ⚠️ Notes

- Some homebrew applications may require sudo password
- Mac App Store installations might prompt for Apple ID authentication
- The script may take 15-30 minutes to complete depending on internet speed
- A system reboot is recommended after completion for all changes to take effect

---

**Always review scripts from external sources before running them on your system.**