#!/bin/bash
# create-desktop-webapp.sh - Create a macOS desktop app for a website
# Desktop version: Creates app with custom icon and places on desktop

# ===============================================
# 1. COLOR OUTPUT & BANNER
# ===============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║    DESKTOP Web App Generator (Website + Icon on Desktop)      ║"
echo "║                with Dock Integration                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ===============================================
# 2. GET USER INPUT
# ===============================================
echo -e "${CYAN}🎨 Let's create your desktop web app${NC}"
echo ""

# Website details from saved shortcut
WEBSITE_URL="https://flip5.gitgpt.chat/guides/"
DISPLAY_NAME="flip5.gitgpt.chat"
ICON_URL="https://www.google.com/s2/favicons?domain=flip5.gitgpt.chat&sz=64"

echo -e "${GREEN}📋 Using saved website details:${NC}"
echo -e "  🌐 URL: ${CYAN}${WEBSITE_URL}${NC}"
echo -e "  📝 Name: ${CYAN}${DISPLAY_NAME}${NC}"
echo -e "  🖼️  Icon: ${CYAN}${ICON_URL}${NC}"
echo ""

# Allow editing
read -p "🌐 Edit website URL (or press Enter to keep): " EDIT_URL
if [ ! -z "$EDIT_URL" ]; then
    WEBSITE_URL="$EDIT_URL"
fi

read -p "📝 Edit app name (or press Enter to keep): " EDIT_NAME
DISPLAY_NAME="${EDIT_NAME:-$DISPLAY_NAME}"

read -p "🖼️  Edit icon URL (or press Enter to keep): " EDIT_ICON
if [ ! -z "$EDIT_ICON" ]; then
    ICON_URL="$EDIT_ICON"
fi

# ===============================================
# 3. DOWNLOAD/CHOOSE ICON
# ===============================================
ICON_FILE=""
ICON_PATH=""

if [ -n "$ICON_URL" ]; then
    ICON_FILE="appicon.${ICON_URL##*.}"
    ICON_FILE="${ICON_FILE%\?*}" # Remove query params
    echo -e "${CYAN}📥 Downloading custom icon...${NC}"
    curl -s -L "$ICON_URL" -o "/tmp/$ICON_FILE" 2>/dev/null
    ICON_PATH="/tmp/$ICON_FILE"
    
    # Check if download succeeded
    if [ ! -s "$ICON_PATH" ]; then
        echo -e "${YELLOW}⚠️  Download failed, using default icon${NC}"
        ICON_PATH=""
    fi
fi

# Fallback to default icon if needed
if [ -z "$ICON_PATH" ] || [ ! -f "$ICON_PATH" ]; then
    DEFAULT_ICON_URL="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6/svgs/solid/globe.svg"
    ICON_FILE="appicon.svg"
    echo -e "${CYAN}📥 Downloading default web icon...${NC}"
    curl -s -L "$DEFAULT_ICON_URL" -o "/tmp/$ICON_FILE" 2>/dev/null
    ICON_PATH="/tmp/$ICON_FILE"
fi

# ===============================================
# 4. CREATE PROJECT DIRECTORY
# ===============================================
PROJECT_DIR="${DISPLAY_NAME// /_}_DesktopApp"
echo ""
echo -e "${CYAN}📁 Creating project: $PROJECT_DIR${NC}"

# Clean up if exists
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠ Removing existing project...${NC}"
    rm -rf "$PROJECT_DIR"
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit

# ===============================================
# 5. CREATE THE .APP BUNDLE STRUCTURE
# ===============================================
APP_NAME_SANITIZED="${DISPLAY_NAME//[^a-zA-Z0-9]/}"
APP_BUNDLE="$APP_NAME_SANITIZED.app"
DESKTOP_PATH="$HOME/Desktop/$APP_BUNDLE"
APPLICATIONS_PATH="$HOME/Applications/$APP_BUNDLE"

echo -e "${CYAN}📦 Creating .app bundle...${NC}"
mkdir -p "$APP_BUNDLE/Contents/"{MacOS,Resources}

# ===============================================
# 6. CREATE Info.plist
# ===============================================
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.webapp.desktop.${APP_NAME_SANITIZED}</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © $(date +%Y). All rights reserved.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/> <!-- Set to false to show in Dock -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>Web Application</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>https</string>
                <string>http</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

# ===============================================
# 7. CREATE PROPER LAUNCHER SCRIPT
# ===============================================
cat > "$APP_BUNDLE/Contents/MacOS/launcher" << 'EOF'
#!/bin/bash
# Proper launcher script that opens the website

# The website to open
URL="WEBSITE_URL_PLACEHOLDER"

# Open the website in default browser
open "$URL"

# Exit immediately to prevent bouncing animation
sleep 0.1
exit 0
EOF

# Replace placeholder with actual URL
sed -i '' "s|WEBSITE_URL_PLACEHOLDER|$WEBSITE_URL|g" "$APP_BUNDLE/Contents/MacOS/launcher"
chmod +x "$APP_BUNDLE/Contents/MacOS/launcher"

# ===============================================
# 8. PROCESS ICON
# ===============================================
if [ -f "$ICON_PATH" ]; then
    echo -e "${CYAN}🎨 Processing icon...${NC}"
    
    # Create icon directory
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    
    # Convert icon to ICNS format if needed
    ICON_EXT="${ICON_PATH##*.}"
    
    if [ "$ICON_EXT" = "svg" ]; then
        # Convert SVG to PNG first
        if command -v rsvg-convert &> /dev/null; then
            rsvg-convert -w 1024 -h 1024 "$ICON_PATH" -o "$APP_BUNDLE/Contents/Resources/AppIcon.png"
        else
            # Try to install rsvg-convert or use fallback
            if command -v brew &> /dev/null; then
                brew install librsvg 2>/dev/null || true
            fi
            if command -v rsvg-convert &> /dev/null; then
                rsvg-convert -w 1024 -h 1024 "$ICON_PATH" -o "$APP_BUNDLE/Contents/Resources/AppIcon.png"
            else
                # Fallback: copy as is and let sips handle it later
                cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.png" 2>/dev/null || true
            fi
        fi
        ICON_SOURCE="$APP_BUNDLE/Contents/Resources/AppIcon.png"
    else
        ICON_SOURCE="$ICON_PATH"
    fi
    
    # Create icon.icns file
    if [ -f "$ICON_SOURCE" ]; then
        # Create iconset directory
        ICONSET_DIR="$APP_BUNDLE/Contents/Resources/AppIcon.iconset"
        rm -rf "$ICONSET_DIR"
        mkdir -p "$ICONSET_DIR"
        
        # Generate different sizes
        SIZES="16 32 64 128 256 512 1024"
        for SIZE in $SIZES; do
            sips -z $SIZE $SIZE "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" 2>/dev/null ||             convert "$ICON_SOURCE" -resize ${SIZE}x${SIZE} "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" 2>/dev/null || true
            RETINA_SIZE=$((SIZE * 2))
            sips -z $RETINA_SIZE $RETINA_SIZE "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" 2>/dev/null ||             convert "$ICON_SOURCE" -resize ${RETINA_SIZE}x${RETINA_SIZE} "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" 2>/dev/null || true
        done
        
        # Convert iconset to icns
        iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true
        
        # Clean up
        rm -rf "$ICONSET_DIR"
        
        # Update Info.plist with icon reference
        if [ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
            plutil -insert CFBundleIconFile -string "AppIcon.icns" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null ||             sed -i '' "s|</dict>|    <key>CFBundleIconFile</key><string>AppIcon.icns</string></dict>|" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
            echo -e "${GREEN}✅ Icon added to app${NC}"
        fi
    fi
fi

# ===============================================
# 9. CREATE DESKTOP SHORTCUT
# ===============================================
echo ""
echo -e "${CYAN}📋 Creating desktop shortcut...${NC}"
if [ -d "$HOME/Desktop/$APP_BUNDLE" ]; then
    rm -rf "$HOME/Desktop/$APP_BUNDLE"
fi
cp -R "$APP_BUNDLE" "$HOME/Desktop/"
echo -e "${GREEN}✅ Desktop shortcut created${NC}"

# ===============================================
# 10. COPY TO APPLICATIONS FOLDER
# ===============================================
echo ""
echo -e "${CYAN}📋 Copying app to main Applications folder...${NC}"

# Main Applications folder
MAIN_APPS_PATH="/Applications/$APP_BUNDLE"

# Remove existing app if present
if [ -d "$MAIN_APPS_PATH" ]; then
    echo -e "${YELLOW}⚠ Removing existing app from /Applications...${NC}"
    # Need sudo to remove from /Applications
    sudo rm -rf "$MAIN_APPS_PATH" 2>/dev/null || {
        echo -e "${YELLOW}⚠ Could not remove existing app (permissions issue)${NC}"
    }
fi

# Copy app to /Applications with sudo
echo -e "${CYAN}   Copying app to /Applications (requires admin password)...${NC}"
if sudo cp -R "$APP_BUNDLE" "/Applications/" 2>/dev/null; then
    echo -e "${GREEN}✅ App copied to /Applications folder${NC}"
    FINAL_APP_PATH="/Applications/$APP_BUNDLE"
else
    echo -e "${YELLOW}⚠ Could not copy to /Applications folder (permissions issue)${NC}"
    echo -e "${CYAN}   Using user Applications folder instead...${NC}"
    
    # Fallback to user Applications folder
    mkdir -p "$HOME/Applications"
    USER_APPS_PATH="$HOME/Applications/$APP_BUNDLE"
    
    if [ -d "$USER_APPS_PATH" ]; then
        rm -rf "$USER_APPS_PATH"
    fi
    
    if cp -R "$APP_BUNDLE" "$HOME/Applications/"; then
        echo -e "${GREEN}✅ App copied to ~/Applications folder instead${NC}"
        FINAL_APP_PATH="$HOME/Applications/$APP_BUNDLE"
    else
        echo -e "${RED}❌ Could not copy to any Applications folder${NC}"
        echo -e "${CYAN}   Using project directory app instead...${NC}"
        FINAL_APP_PATH="$(pwd)/$APP_BUNDLE"
    fi
fi

# ===============================================
# 11. ADD TO DOCK
# ===============================================
echo ""
echo -e "${CYAN}📌 Adding app to Dock...${NC}"

if [ -d "$FINAL_APP_PATH" ]; then
    # Clean URL path for XML
    CLEAN_APP_PATH=$(echo "$FINAL_APP_PATH" | sed 's/&/&amp;/g')
    
    # Check if app is already in Dock
    DOCK_APPS=$(defaults read com.apple.dock persistent-apps 2>/dev/null || echo "[]")
    APP_IN_DOCK=$(echo "$DOCK_APPS" | grep -c "$APP_BUNDLE" || true)
    
    if [ "$APP_IN_DOCK" -eq 0 ]; then
        echo -e "${CYAN}   Adding '$DISPLAY_NAME' to Dock...${NC}"
        
        # Create a temporary plist file
        TEMP_PLIST="/tmp/dock_item.plist"
        cat > "$TEMP_PLIST" << XMLPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>file://$CLEAN_APP_PATH</string>
            <key>_CFURLStringType</key>
            <integer>15</integer>
        </dict>
        <key>file-type</key>
        <integer>41</integer>
        <key>file-label</key>
        <string>$DISPLAY_NAME</string>
    </dict>
    <key>tile-type</key>
    <string>file-tile</string>
</dict>
</plist>
XMLPLIST
        
        # Use PlistBuddy to add to Dock
        /usr/libexec/PlistBuddy -c "Add persistent-apps:0 dict" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Merge $TEMP_PLIST persistent-apps:0" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null
        
        # Restart Dock to apply changes
        killall Dock 2>/dev/null &
        DOCK_PID=$!
        sleep 1
        
        echo -e "${GREEN}✅ Added to Dock!${NC}"
        echo -e "${YELLOW}💡 Dock is restarting...${NC}"
    else
        echo -e "${YELLOW}⚠ App is already in Dock${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not add to Dock - app not found${NC}"
    echo -e "${CYAN}   You can manually add it by:${NC}"
    echo -e "   1. Dragging '$APP_BUNDLE' from Desktop to the Dock"
    echo -e "   2. Or right-click the app on Desktop and select 'Options > Keep in Dock'"
fi

# ===============================================
# 12. CREATE INSTALLATION SCRIPT
# ===============================================
cat > "Install.command" << EOF
#!/bin/bash
# Installation script for $DISPLAY_NAME

echo "Installing $DISPLAY_NAME..."
echo ""

# Ensure ~/Applications exists
mkdir -p "$HOME/Applications"

# Copy to Applications
if cp -R "$APP_BUNDLE" "$HOME/Applications/" 2>/dev/null; then
    echo "✅ Installed to ~/Applications folder"
    APP_PATH="$HOME/Applications/$APP_BUNDLE"
else
    echo "⚠ Could not install to Applications"
    echo "   App remains in: $(pwd)/$APP_BUNDLE"
    APP_PATH="$(pwd)/$APP_BUNDLE"
fi

# Create desktop shortcut
echo ""
echo "📋 Creating desktop shortcut..."
if [ -d "$HOME/Desktop/$APP_BUNDLE" ]; then
    rm -rf "$HOME/Desktop/$APP_BUNDLE"
fi
cp -R "$APP_BUNDLE" "$HOME/Desktop/"
echo "✅ Desktop shortcut created"

echo ""
echo "🎉 Installation complete!"
echo "   App location: ~/Applications/$APP_BUNDLE"
echo "   Desktop shortcut created"
echo ""
echo "📌 To add to Dock:"
echo "   1. Find '$APP_BUNDLE' on your Desktop"
echo "   2. Drag it to your Dock"
echo "   3. Or right-click and select 'Options > Keep in Dock'"
EOF

chmod +x "Install.command"

# ===============================================
# 13. CREATE UNINSTALL SCRIPT
# ===============================================
cat > "Uninstall.command" << EOF
#!/bin/bash
# Uninstall $DISPLAY_NAME

echo "Uninstalling $DISPLAY_NAME..."
echo ""

# Remove from desktop
if [ -d "$HOME/Desktop/$APP_BUNDLE" ]; then
    rm -rf "$HOME/Desktop/$APP_BUNDLE"
    echo "✅ Removed from desktop"
fi

# Remove from ~/Applications
if [ -d "$HOME/Applications/$APP_BUNDLE" ]; then
    rm -rf "$HOME/Applications/$APP_BUNDLE"
    echo "✅ Removed from ~/Applications"
fi

# Remove from Dock (more complex - need to find and remove)
echo ""
echo "🗑️  Removing from Dock..."
echo "To remove from Dock:"
echo "1. Drag the app icon out of the Dock"
echo "2. Or wait for it to disappear after removal"

echo ""
echo "✅ $DISPLAY_NAME has been uninstalled"
echo "   Note: You may need to restart your Mac to fully remove from Dock"
EOF

chmod +x "Uninstall.command"

# ===============================================
# 14. CREATE README
# ===============================================
cat > "README.txt" << EOF
$DISPLAY_NAME - Desktop Web App
================================

App created: $(date)
Website: $WEBSITE_URL

📁 WHAT WAS CREATED:
-------------------
1. $APP_BUNDLE - The main application bundle
2. Install.command - Installation script
3. Uninstall.command - Removal script

🚀 HOW TO USE:
-------------
1. The app is already on your desktop AND in ~/Applications
2. Double-click "$APP_BUNDLE" to launch from either location
3. It will open: $WEBSITE_URL in your default browser
4. The app has been added to your Dock automatically

🔧 INSTALLATION ALREADY DONE:
---------------------------
- App copied to: ~/Applications/$APP_BUNDLE
- Desktop shortcut created
- Added to Dock (Dock was restarted)

🎯 FEATURES:
-----------
- Native macOS application
- Opens in default browser
- Custom application icon
- Desktop shortcut
- Automatically added to Dock
- Easy uninstallation

📝 NOTES:
--------
- The app is a wrapper that opens your website
- Website opens in your default browser
- You may need to log out/in for Dock changes to fully apply
- To keep in Dock permanently: right-click Dock icon → Options → Keep in Dock

Created by Desktop Web App Generator
EOF

# ===============================================
# 15. FINAL STEPS
# ===============================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ DESKTOP APP CREATED SUCCESSFULLY!                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📋 SUMMARY:${NC}"
echo -e "   App Name:    ${GREEN}$DISPLAY_NAME${NC}"
echo -e "   Website:     ${GREEN}$WEBSITE_URL${NC}"
echo -e "   Location:    ${GREEN}$HOME/Applications/$APP_BUNDLE${NC}"
echo -e "   Desktop:     ${GREEN}$HOME/Desktop/$APP_BUNDLE${NC}"
echo -e "   Dock:        ${GREEN}Added automatically${NC}"
echo -e "   Icon:        $(if [ -f "$ICON_PATH" ]; then echo "${GREEN}Custom icon applied${NC}"; else echo "${YELLOW}Default icon${NC}"; fi)"
echo ""
echo -e "${YELLOW}🚀 QUICK START:${NC}"
echo -e "   1. Look for '$APP_BUNDLE' on your Desktop or in Dock"
echo -e "   2. Double-click to launch"
echo -e "   3. It will open: $WEBSITE_URL"
echo ""
echo -e "${CYAN}📁 FILES CREATED:${NC}"
echo -e "   $(pwd)/"
echo -e "   ├── ${GREEN}$APP_BUNDLE${NC}        (Main application)"
echo -e "   ├── Install.command    (Re-install if needed)"
echo -e "   ├── Uninstall.command  (Remove app completely)"
echo -e "   └── README.txt         (Instructions)"
echo ""
echo -e "${GREEN}✅ DONE! Your desktop web app is ready to use.${NC}"

# ===============================================
# 16. TEST THE APP
# ===============================================
echo ""
read -p "Would you like to test the app now? (y/N): " TEST_APP
if [[ "$TEST_APP" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}🚀 Launching $DISPLAY_NAME...${NC}"
    open "$HOME/Applications/$APP_BUNDLE" 2>/dev/null || open "./$APP_BUNDLE"
    echo -e "${GREEN}✅ App launched! Check your Dock and desktop for the application.${NC}"
    echo -e "${YELLOW}⚠ Note: The app will open your website and then close - this is normal!${NC}"
fi

# Clean up temporary files
rm -rf "/tmp/appicon"* 2>/dev/null || true
rm -f "/tmp/dock_item.plist" 2>/dev/null || true

echo ""
echo -e "${YELLOW}💡 Tip: If the app doesn't appear in Dock immediately, try:${NC}"
echo -e "   1. Log out and back in"
echo -e "   2. Or drag the app from Desktop to your Dock"
echo -e "   3. The app is designed to open the website and exit (no bouncing)"