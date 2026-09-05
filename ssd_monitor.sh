#!/bin/bash
# ssd_monitor.sh
# Creates a macOS menu bar app for monitoring SSD storage

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              SSD STORAGE MONITOR - MENU BAR APP          ║"
echo "║              Real-time Storage Usage in Menu Bar         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

APP_NAME="SSDMonitor"
BUNDLE_ID="com.github.ssdmonitor"

rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/src"
cd "$APP_NAME" || exit

# ===============================================
# CREATE ICON (download from your URL)
# ===============================================
echo -e "${CYAN}🎨 Downloading SSD icon...${NC}"

ICON_URL="https://raw.githubusercontent.com/igiteam/winejs/refs/heads/main/images/ssd-icon.png"
ICON_FILE="ssd-icon.png"

echo "📥 Downloading icon from: $ICON_URL"
curl -s -L "$ICON_URL" -o "$ICON_FILE"

if [ -f "$ICON_FILE" ] && [ -s "$ICON_FILE" ]; then
    echo "✅ Icon downloaded successfully!"
    
    # Create iconset for the app bundle
    mkdir -p AppIcon.iconset
    
    # Generate various sizes for the app icon
    for SIZE in 16 32 64 128 256 512 1024; do
        sips -z $SIZE $SIZE "$ICON_FILE" --out "AppIcon.iconset/icon_${SIZE}x${SIZE}.png" 2>/dev/null || true
        RETINA=$((SIZE * 2))
        sips -z $RETINA $RETINA "$ICON_FILE" --out "AppIcon.iconset/icon_${SIZE}x${SIZE}@2x.png" 2>/dev/null || true
    done
    
    if command -v iconutil &> /dev/null; then
        iconutil -c icns "AppIcon.iconset" -o "app_icon.icns" 2>/dev/null
        echo "✅ Created .icns file"
    else
        cp "$ICON_FILE" "app_icon.icns"
    fi
    
    rm -rf "AppIcon.iconset"
else
    echo "⚠ Download failed, using fallback icon"
    echo "💾" > app_icon.txt
fi

# ===============================================
# CREATE OBJECTIVE-C SOURCE
# ===============================================

cat > "src/SSDMonitor.h" << 'EOF'
#import <Foundation/Foundation.h>

@interface SSDMonitor : NSObject
- (NSDictionary *)getStorageInfo;
- (NSString *)formatBytes:(unsigned long long)bytes;
- (NSString *)formatBytesShort:(unsigned long long)bytes;
@end
EOF

cat > "src/SSDMonitor.m" << 'EOF'
#import "SSDMonitor.h"
#import <AppKit/AppKit.h>

@implementation SSDMonitor

- (NSDictionary *)getStorageInfo {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSURL *rootURL = [NSURL fileURLWithPath:@"/"];
    NSDictionary *attributes = [fileManager attributesOfFileSystemForPath:@"/" error:&error];
    
    if (error) {
        return @{@"error": error.localizedDescription};
    }
    
    unsigned long long totalSpace = [[attributes objectForKey:NSFileSystemSize] unsignedLongLongValue];
    unsigned long long freeSpace = [[attributes objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
    unsigned long long usedSpace = totalSpace - freeSpace;
    
    // Check if it's an SSD
    BOOL isSSD = YES;
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/system_profiler";
    task.arguments = @[@"SPStorageDataType", @"-json"];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    [task launch];
    
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    
    if (data) {
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!jsonError) {
            NSArray *storage = json[@"SPStorageDataType"];
            for (NSDictionary *item in storage) {
                NSString *mountPoint = item[@"mount_point"];
                if ([mountPoint isEqualToString:@"/"]) {
                    NSString *mediaName = item[@"_name"] ?: @"";
                    NSString *protocol = item[@"protocol"] ?: @"";
                    NSString *mediumType = item[@"medium_type"] ?: @"";
                    
                    NSArray *ssdKeywords = @[@"SSD", @"NVMe", @"PCIe", @"Solid State", @"Flash"];
                    for (NSString *keyword in ssdKeywords) {
                        if ([mediaName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound ||
                            [protocol rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound ||
                            [mediumType rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                            isSSD = YES;
                            break;
                        }
                    }
                    break;
                }
            }
        }
    }
    
    return @{
        @"total": @(totalSpace),
        @"free": @(freeSpace),
        @"used": @(usedSpace),
        @"isSSD": @(isSSD)
    };
}

- (NSString *)formatBytes:(unsigned long long)bytes {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%llu B", bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024];
    } else if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024 * 1024)];
    } else if (bytes < 1024 * 1024 * 1024 * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f GB", (double)bytes / (1024 * 1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"%.1f TB", (double)bytes / (1024 * 1024 * 1024 * 1024ULL)];
    }
}

- (NSString *)formatBytesShort:(unsigned long long)bytes {
    if (bytes < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.0f MB", (double)bytes / (1024 * 1024)];
    } else if (bytes < 1024 * 1024 * 1024 * 1024ULL) {
        return [NSString stringWithFormat:@"%.0f GB", (double)bytes / (1024 * 1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"%.1f TB", (double)bytes / (1024 * 1024 * 1024 * 1024ULL)];
    }
}

@end
EOF

cat > "src/AppDelegate.h" << 'EOF'
#import <Cocoa/Cocoa.h>
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end
EOF

cat > "src/AppDelegate.m" << 'EOF'
#import "AppDelegate.h"
#import "SSDMonitor.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) SSDMonitor *monitor;
@property (nonatomic, strong) NSMenuItem *openStorageItem;
@property (nonatomic, strong) NSMenuItem *refreshMenuItem;
@property (nonatomic, strong) NSMenuItem *quitMenuItem;
@property (nonatomic, strong) NSMenuItem *detailsMenuItem;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.monitor = [[SSDMonitor alloc] init];
    
    // Create status bar item - text only, no icon
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightMedium];
    
    // Update initial status
    [self updateStatus];
    
    // Update every 10 seconds
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                        target:self
                                                      selector:@selector(updateStatus)
                                                      userInfo:nil
                                                       repeats:YES];
    
    // Create menu
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Storage info header (non-clickable)
    self.detailsMenuItem = [[NSMenuItem alloc] initWithTitle:@"SSD Storage" action:nil keyEquivalent:@""];
    self.detailsMenuItem.enabled = NO;
    [menu addItem:self.detailsMenuItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Open Storage Management
    self.openStorageItem = [[NSMenuItem alloc] initWithTitle:@"Open Storage Management..."
                                                      action:@selector(openStorageManagement:)
                                               keyEquivalent:@"o"];
    self.openStorageItem.target = self;
    [menu addItem:self.openStorageItem];
    
    // Open Disk Utility
    NSMenuItem *diskUtilityItem = [[NSMenuItem alloc] initWithTitle:@"Open Disk Utility"
                                                             action:@selector(openDiskUtility:)
                                                      keyEquivalent:@"d"];
    diskUtilityItem.target = self;
    [menu addItem:diskUtilityItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Refresh
    self.refreshMenuItem = [[NSMenuItem alloc] initWithTitle:@"Refresh"
                                                      action:@selector(updateStatus)
                                               keyEquivalent:@"r"];
    self.refreshMenuItem.target = self;
    [menu addItem:self.refreshMenuItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Quit
    self.quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                   action:@selector(quitApp:)
                                            keyEquivalent:@"q"];
    self.quitMenuItem.target = self;
    [menu addItem:self.quitMenuItem];
    
    self.statusItem.menu = menu;
}

- (void)updateStatus {
    NSDictionary *storageInfo = [self.monitor getStorageInfo];
    
    if (storageInfo[@"error"]) {
        self.statusItem.button.title = @"⚠️ SSD Error";
        return;
    }
    
    unsigned long long total = [storageInfo[@"total"] unsignedLongLongValue];
    unsigned long long used = [storageInfo[@"used"] unsignedLongLongValue];
    BOOL isSSD = [storageInfo[@"isSSD"] boolValue];
    
    // Format as "SSD: 93/956gb" - short format
    NSString *usedStr = [self.monitor formatBytesShort:used];
    NSString *totalStr = [self.monitor formatBytesShort:total];
    
    // Remove spaces between number and unit for compact display
    usedStr = [usedStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    totalStr = [totalStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    // Menu bar text: "SSD: 93/956gb"
    NSString *type = isSSD ? @"SSD" : @"HDD";
    self.statusItem.button.title = [NSString stringWithFormat:@"%@: %@/%@", type, usedStr, totalStr];
    
    // Update menu details
    if (self.detailsMenuItem) {
        NSString *usedFull = [self.monitor formatBytes:used];
        NSString *totalFull = [self.monitor formatBytes:total];
        double usedPercent = (double)used / total * 100;
        self.detailsMenuItem.title = [NSString stringWithFormat:@"💾 %@: %@ / %@ (%.1f%%)", 
                                      type, usedFull, totalFull, usedPercent];
    }
}

- (void)openStorageManagement:(id)sender {
    NSURL *url;
    if (@available(macOS 13.0, *)) {
        url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.settings.Storage"];
    } else {
        url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.storagemanagement"];
    }
    
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    } else {
        [self openDiskUtility:sender];
    }
}

- (void)openDiskUtility:(id)sender {
    [[NSWorkspace sharedWorkspace] launchApplication:@"Disk Utility"];
}

- (void)quitApp:(id)sender {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    [NSApp terminate:nil];
}

- (void)dealloc {
    [self.updateTimer invalidate];
}

@end
EOF

cat > "src/main.m" << 'EOF'
#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
EOF

# ===============================================
# BUILD APP BUNDLE
# ===============================================

echo -e "${CYAN}🔨 Compiling SSD Monitor...${NC}"

APP_BUNDLE="$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/"{MacOS,Resources}

# Create Info.plist
cat > "Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp "Info.plist" "$APP_BUNDLE/Contents/"

# Copy the app icon (for Finder/Dock)
if [ -f "app_icon.icns" ]; then
    cp "app_icon.icns" "$APP_BUNDLE/Contents/Resources/app_icon.icns"
    echo "✅ App icon added to bundle"
fi

# Compile
clang -framework Cocoa -framework Foundation -framework AppKit -framework CoreGraphics -fobjc-arc -Wno-deprecated-declarations -mmacosx-version-min=10.15 -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" src/*.m 2> build_errors.log

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Compilation successful!${NC}"
else
    echo -e "${RED}❌ Compilation failed:${NC}"
    cat build_errors.log
    exit 1
fi

# Sign and fix permissions
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
xattr -cr "$APP_BUNDLE"

# Copy to Applications and Desktop
cp -R "$APP_BUNDLE" "$HOME/Applications/" 2>/dev/null || true
cp -R "$APP_BUNDLE" "$HOME/Desktop/" 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ SSD Monitor built successfully!${NC}"
echo -e "${CYAN}📁 App installed to:${NC} $HOME/Applications/$APP_BUNDLE"
echo -e "${CYAN}📁 Desktop copy:${NC} $HOME/Desktop/$APP_BUNDLE"
echo ""
echo -e "${CYAN}🚀 Launch from Applications or Desktop${NC}"
echo ""
echo -e "${GREEN}✨ Features:${NC}"
echo "   • Clean menu bar display: SSD: 93/956gb"
echo "   • No icon in menu bar - just text"
echo "   • App icon used for Finder/Dock (downloaded from GitHub)"
echo "   • Click for Storage Management and Disk Utility"
echo "   • Auto-refreshes every 10 seconds"
echo ""

# Launch the app
echo -e "${CYAN}🚀 Launching SSD Monitor...${NC}"
open "$APP_BUNDLE"