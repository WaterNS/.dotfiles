#!/bin/bash

# ref: https://github.com/mathiasbynens/dotfiles/blob/main/.macos

function setMacTerminalDefaultTheme() {
  if contains "$TERM_PROGRAM" "Terminal"; then
    # Set Terminal theme
  osascript <<EOD
tell application "Terminal"
	local allOpenedWindows
	local initialOpenedWindows
	local windowID
	set themeName to "Pro"

	(* Store the IDs of all the open terminal windows. *)
	set initialOpenedWindows to id of every window

	(* Set the custom theme as the default terminal theme. *)
	set default settings to settings set themeName

	(* Get the IDs of all the currently opened terminal windows. *)
	set allOpenedWindows to id of every window
	repeat with windowID in allOpenedWindows
		(* Close the additional windows that were opened in order
		   to add the custom theme to the list of terminal themes. *)
		if initialOpenedWindows does not contain windowID then
			close (every window whose id is windowID)
		(* Change the theme for the initial opened terminal windows
		   to remove the need to close them in order for the custom
		   theme to be applied. *)
		else
			set current settings of tabs of (every window whose id is windowID) to settings set themeName
		end if
	end repeat
end tell
EOD
  fi
}

if [ "$OS_FAMILY" = "Darwin" ]; then
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
  defaults write com.apple.mail DisableInlineAttachmentViewing -bool true # Disable inline attachments (just show the icons)
  # Copy email addresses as `foo@example.com` instead of `Foo Bar <foo@example.com>` in Mail.app
  defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

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
  defaults write com.apple.Safari UniversalSearchEnabled -bool false # Privacy: don’t send search queries to Apple
  defaults write com.apple.Safari SuppressSearchSuggestions -bool true # Privacy: don’t send search queries to Apple
  # Block pop-up windows
  defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool false
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool false
  defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true # Enable “Do Not Track”
  defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true # Update extensions automatically
  # Press Tab to highlight each item on a web page
  defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true
  defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true # Show the full URL in the address bar (note: this still hides the scheme)
  defaults write com.apple.Safari HomePage -string "about:blank" # Set Safari’s home page to `about:blank` for faster loading
  defaults write com.apple.Safari AutoOpenSafeDownloads -bool false # Prevent Safari from opening ‘safe’ files automatically after downloading
  # Allow hitting the Backspace key to go to the previous page in history
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2BackspaceKeyNavigationEnabled -bool true
  defaults write com.apple.Safari ShowSidebarInTopSites -bool false # Hide Safari’s sidebar in Top Sites
  defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2 # Disable Safari’s thumbnail cache for History and Top Sites
  defaults write com.apple.Safari IncludeInternalDebugMenu -bool true # Enable Safari’s debug menu
  defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false # Make Safari’s search banners default to Contains instead of Starts With
  defaults write com.apple.Safari ProxiesInBookmarksBar "()" # Remove useless icons from Safari’s bookmarks bar
  # Enable the Develop menu and the Web Inspector in Safari
  defaults write com.apple.Safari IncludeDevelopMenu -bool true
  defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
  defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
  defaults write NSGlobalDomain WebKitDeveloperExtras -bool true # Add a context menu item for showing the Web Inspector in web views
  # Enable continuous spellchecking
  defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool true
  # Disable auto-correct
  defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false
  # Disable AutoFill
  defaults write com.apple.Safari AutoFillFromAddressBook -bool false
  defaults write com.apple.Safari AutoFillPasswords -bool false
  defaults write com.apple.Safari AutoFillCreditCardData -bool false
  defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false
  # Warn about fraudulent websites
  defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

  # Set Terminal default theme
  setMacTerminalDefaultTheme

  echo "** Darwin Init Done ** Note that some of these changes require a logout/restart to take effect."
fi
