#!/bin/bash

# ref: https://github.com/mathiasbynens/dotfiles/blob/main/.macos

# Source posix functions
if [ -f "$HOME/.dotfiles/posixshells/posix_functions.sh" ]; then
  . "$HOME/.dotfiles/posixshells/posix_functions.sh"
fi

# Source installer functions
if [ -f "$HOME/.dotfiles/posixshells/posix_installers.sh" ]; then
  . "$HOME/.dotfiles/posixshells/posix_installers.sh"
fi

if [ "$OS_FAMILY" = "Darwin" ]; then
  ## Some defaults write require Full Disk Access (FDA)

  install_macRosetta2 # Install Rosetta (lot of utils aren't compiled for ARM in macOS space)

  # macOS: Disable .DSStore on network shares and USB
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

  # macOS: Adjust Spellcheck/typing experience
  #defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  #defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticTextCompletionEnabled -bool false
  # Disable press-and-hold for keys in favor of key repeat
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  # Set a blazingly fast keyboard repeat rate
  defaults write NSGlobalDomain KeyRepeat -int 3
  defaults write NSGlobalDomain InitialKeyRepeat -int 25


  # macOS TextEdit:
  defaults write com.apple.TextEdit RichText -int 0 # Use plain text mode by default
  defaults write com.apple.TextEdit PlainTextEncoding -int 4 # Open and save files as UTF-8 in TextEdit
  defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4 # Open and save files as UTF-8 in TextEdit

  # macOS Mail:
  defaults write com.apple.mail DisableInlineAttachmentViewing -bool true # FDA required - Disable inline attachments (just show the icons)
  defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false # FDA required - Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>` in Mail.app
  defaults write com.apple.mail SuppressAddressHistory -bool true # FDA required - Disable "Previous Recipients" 'feature'

  # macOS: Disable Window Tints based on background
  defaults write -g AppleReduceDesktopTinting -bool yes

  # macOS: Disable screen dimming on battery
  #defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false #doesn't appear to work
  #sudo launchctl stop com.apple.AmbientDisplayAgent
  #sudo launchctl remove com.apple.AmbientDisplayAgent

  # Expand save panel by default
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

  # Expand print panel by default
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  # Save to disk (not to iCloud) by default
  defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

  # Display ASCII control characters using caret notation in standard text views
  # Try e.g. `cd /tmp; unidecode "\x{0000}" > cc.txt; open -e cc.txt`
  defaults write NSGlobalDomain NSTextShowsControlCharacters -bool true

  # Require password immediately after sleep or screen saver begins
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0

  # Dock:
  defaults write com.apple.dock show-recents -bool false # Don’t show recent applications in Dock
  defaults write com.apple.dock autohide -bool true # Automatically hide and show the Dock

  # Finder:
  #sudo chflags nohidden /Volumes # Show the /Volumes folder
  # Use list view in all Finder windows by default, Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  defaults write com.apple.finder _FXSortFoldersFirst -bool true # Keep folders on top when sorting by name
  # Show icons for hard drives, servers, and removable media on the desktop
  defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
  defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
  defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
  #defaults write com.apple.finder AppleShowAllFiles -bool true # show hidden files by default
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true # show status bar
  defaults write com.apple.finder ShowStatusBar -bool true # show status bar
  defaults write com.apple.finder ShowPathbar -bool true # show path bar

  # Enable snap-to-grid for icons on the desktop and in other icon views
  /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
  /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

  # Enable AirDrop over Ethernet and on unsupported Macs running Lion
  defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

  # Hot corners
  # Possible values:
  #  0: no-op
  #  2: Mission Control
  #  3: Show application windows
  #  4: Desktop
  #  5: Start screen saver
  #  6: Disable screen saver
  #  7: Dashboard
  # 10: Put display to sleep
  # 11: Launchpad
  # 12: Notification Center
  # Top left screen corner
  defaults write com.apple.dock wvous-tl-corner -int 0
  defaults write com.apple.dock wvous-tl-modifier -int 0
  # Top right screen corner
  defaults write com.apple.dock wvous-tr-corner -int 0
  defaults write com.apple.dock wvous-tr-modifier -int 0
  # Bottom left screen corner
  defaults write com.apple.dock wvous-bl-corner -int 0
  defaults write com.apple.dock wvous-bl-modifier -int 0
  # Bottom right screen corner
  defaults write com.apple.dock wvous-br-corner -int 0
  defaults write com.apple.dock wvous-br-modifier -int 0

  # Disable smart quotes as it’s annoying for messages that contain code
  defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false

  # Mac App Store:
  defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true # Enable the automatic update check
  defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1 # Download newly available updates in background
  defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1 # Install System data files & security updates
  defaults write com.apple.commerce AutoUpdate -bool true # Turn on app auto-update

  # Safari & WebKit:
  defaults write com.apple.Safari UniversalSearchEnabled -bool false # FDA required - Privacy: don’t send search queries to Apple
  defaults write com.apple.Safari SuppressSearchSuggestions -bool true # FDA required - Privacy: don’t send search queries to Apple
  defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false # FDA required - Block pop-up windows
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false # FDA required
  defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true # Enable “Do Not Track”
  defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true # Update extensions automatically
  defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true # FDA required
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true # FDA required - Press Tab to highlight each item on a web page
  defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true # FDA required - Show the full URL in the address bar (note: this still hides the scheme)
  defaults write com.apple.Safari HomePage -string "about:blank" # FDA required - Set Safari’s home page to `about:blank` for faster loading
  defaults write com.apple.Safari AutoOpenSafeDownloads -bool false # FDA required - Prevent Safari from opening ‘safe’ files automatically after downloading
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled -bool true # FDA required - Allow hitting the Backspace key to go to the previous page in history
  defaults write com.apple.Safari ShowSidebarInTopSites -bool false # FDA required - Hide Safari’s sidebar in Top Sites
  defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2 # FDA required - Disable Safari’s thumbnail cache for History and Top Sites
  defaults write com.apple.Safari IncludeInternalDebugMenu -bool true # FDA required - Enable Safari’s debug menu
  defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false # FDA required - Make Safari’s search banners default to Contains instead of Starts With
  defaults write com.apple.Safari ProxiesInBookmarksBar "()" # FDA required - Remove useless icons from Safari’s bookmarks bar
  defaults write com.apple.Safari IncludeDevelopMenu -bool true  # FDA required - Enable the Develop menu and the Web Inspector in Safari
  defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true # FDA required
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true # FDA required
  defaults write NSGlobalDomain WebKitDeveloperExtras -bool true # FDA required - Add a context menu item for showing the Web Inspector in web views

  defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool true # FDA required - Enable continuous spellchecking
  defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false  # FDA required - Disable auto-correct

  defaults write com.apple.Safari AutoFillFromAddressBook -bool false  # FDA required - Disable AutoFill
  defaults write com.apple.Safari AutoFillPasswords -bool false  # FDA required - Disable AutoFill
  defaults write com.apple.Safari AutoFillCreditCardData -bool false  # FDA required - Disable AutoFill
  defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false  # FDA required - Disable AutoFill

  defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true  # FDA required - Warn about fraudulent websites

  # Preview.app
  # Show Thumbnails/Sidebar on launch
  defaults write com.apple.Preview PVPDFSuppressSidebarOnOpening -bool false

  # Set Terminal default theme
  # setMacTerminalDefaultTheme ## This is set in the init_posix instead

  #Photos.app
  # Note: Sandbox apps keep their prefs in their container ("~/Library/Containers/**AppID**/Data/Library/Preferences/**AppID**.plist")
  # Non‑sandboxed apps keep their prefs in ~/Library/Preferences
  defaults write "$HOME/Library/Containers/com.apple.Photos/Data/Library/Preferences/com.apple.Photos" NSUserKeyEquivalents -dict-add "Close Viewer" "@$\U0020" # Remap 'Close Viewer' to Cmd+Shift+Space
  defaults write "$HOME/Library/Containers/com.apple.Photos/Data/Library/Preferences/com.apple.Photos" NSUserKeyEquivalents -dict-add "Start Playback" "\U0020" # Remap 'Start Playback' to Spacebar
  defaults write "$HOME/Library/Containers/com.apple.Photos/Data/Library/Preferences/com.apple.Photos" NSUserKeyEquivalents -dict-add "Stop Playback" "\U0020" # Remap 'Stop Playback' to Spacebar
  defaults write com.apple.Photos NSUserKeyEquivalents -dict-add "Close Viewer" "@$\U0020" # Remap 'Close Viewer' to Cmd+Shift+Space
  defaults write com.apple.Photos NSUserKeyEquivalents -dict-add "Start Playback" "\U0020" # Remap 'Start Playback' to Spacebar
  defaults write com.apple.Photos NSUserKeyEquivalents -dict-add "Stop Playback"  "\U0020" # Remap 'Stop Playback' to Spacebar
  defaults read com.apple.universalaccess com.apple.custommenu.apps 2>/dev/null \
        | grep -q "com.apple.Photos" \
        || defaults write com.apple.universalaccess com.apple.custommenu.apps -array-add "com.apple.Photos" # Add app entry into System Settings › Keyboard › App Shortcuts

  #Windows App Beta / Remote Desktop App  -  osascript -e 'id of app "Windows App Beta"'
  defaults write "$HOME/Library/Preferences/com.microsoft.rdc.osx.beta.plist" NSUserKeyEquivalents -dict-add "Close" "@~w" # Remap 'Close' to Cmd-Option-W
  defaults write "$HOME/Library/Preferences/com.microsoft.rdc.osx.beta.plist" NSUserKeyEquivalents -dict-add "Search" "@~f" # Remap 'Search' to Cmd+Option+F
  defaults write "$HOME/Library/Preferences/com.microsoft.rdc.osx.beta.plist" NSUserKeyEquivalents -dict-add "Add PC" "@~n" # Remap 'Add PC' to Cmd-Option-N
  defaults write "$HOME/Library/Preferences/com.microsoft.rdc.osx.beta.plist" NSUserKeyEquivalents -dict-add "Add Workspace" "@~s" # Remap 'Add Workspace' to Cmd-Option-S
  defaults read com.apple.universalaccess com.apple.custommenu.apps 2>/dev/null \
        | grep -Fq "com.microsoft.rdc.osx.beta" \
        || defaults write com.apple.universalaccess com.apple.custommenu.apps -array-add "com.microsoft.rdc.osx.beta" # Add app entry into System Settings › Keyboard › App Shortcuts


  # mac-KbDisableDndButton - Add to login:
  command cat <<EOF > "$HOME/Library/LaunchAgents/com.dotfiles.mac-KbDisableDndButton.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.dotfiles.mac-KbDisableDndButton</string>
  <key>Program</key>
  <string>$HOME/.dotfiles/bin/mac-KbDisableDndButton</string>

  <!-- Troubleshooting:
  launchctl print gui/$(id -u)/com.dotfiles.mac-KbDisableDndButton
  launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.dotfiles.mac-KbDisableDndButton.plist
  launchctl print gui/$(id -u)/com.dotfiles.mac-KbDisableDndButton
  launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.dotfiles.mac-KbDisableDndButton.plist
  launchctl print gui/$(id -u)/com.dotfiles.mac-KbDisableDndButton -->

  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
  launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.dotfiles.mac-KbDisableDndButton.plist

  killall cfprefsd #flush the preferences daemon so the pane refreshes immediately
  echo "** Darwin Init Done ** Note that some of these changes require a logout/restart to take effect."
fi
