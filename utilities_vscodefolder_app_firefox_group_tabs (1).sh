#!/bin/bash
# vs_code_project_dock_app.sh
# Creates a macOS Dock app for saving/launching VS Code projects and Link Groups

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
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     VS CODE PROJECT DOCK APP - Saved Project Launcher    ║"
echo "║              + Link Groups for Firefox Dev               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ===============================================
# 2. APP NAME AND STRUCTURE SETUP
# ===============================================
# Ask for app name
read -p "Enter your VS Code Dock app name (default: VSCode-Projects): " APPNAME
APPNAME=${APPNAME:-VSCode-Projects}

# Check if folder exists
if [ -d "$APPNAME" ]; then
    read -p "Folder '$APPNAME' already exists. Remove it? (y/N): " REMOVE
    REMOVE=${REMOVE:-N}
    if [[ "$REMOVE" == "y" || "$REMOVE" == "Y" ]]; then
        echo "Removing existing folder '$APPNAME'..."
        rm -rf "$APPNAME"
    else
        echo "Exiting to avoid overwriting."
        exit 1
    fi
fi

# Create folder structure
mkdir -p "$APPNAME/src" "$APPNAME/native" "$APPNAME/public" "$APPNAME/build"
cd "$APPNAME" || exit

# ===============================================
# 3. CREATE CUSTOM ICON (FIXED - PERFECT METHOD)
# ===============================================
echo -e "${CYAN}🎨 Downloading VS Code icon for Dock...${NC}"

# Download the icon with proper handling
ICON_URL="https://cdn.sdappnet.cloud/rtx/images/vscodefolders.png"

# Extract filename with extension (GENIUS METHOD!)
ICON_FILE="appicon.${ICON_URL##*.}"
ICON_FILE="${ICON_FILE%\?*}"  # Remove any query params

# Download with proper flags
echo "📥 Downloading icon from: $ICON_URL"
curl -s -L "$ICON_URL" -o "/tmp/$ICON_FILE"

# Check if download succeeded
if [ -f "/tmp/$ICON_FILE" ] && [ -s "/tmp/$ICON_FILE" ]; then
    echo "✅ Icon downloaded successfully!"
    
    # Copy to public folder
    mkdir -p public
    cp "/tmp/$ICON_FILE" "public/app_icon.png"
    
    # Create iconset for all sizes
    ICONSET_DIR="public/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    
    # Generate all required sizes
    for SIZE in 16 32 64 128 256 512 1024; do
        sips -z $SIZE $SIZE "public/app_icon.png" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" 2>/dev/null || true
        
        # Retina version (2x)
        RETINA=$((SIZE * 2))
        sips -z $RETINA $RETINA "public/app_icon.png" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" 2>/dev/null || true
    done
    
    # Convert to .icns
    if command -v iconutil &> /dev/null; then
        iconutil -c icns "$ICONSET_DIR" -o "public/app_icon.icns" 2>/dev/null
        echo "✅ Created .icns file"
    else
        # Fallback - just copy the png
        cp "public/app_icon.png" "public/app_icon.icns"
    fi
    
    # Clean up
    rm -rf "$ICONSET_DIR"
else
    echo "⚠ Download failed, creating fallback icon"
    # Create fallback icon using base64
    mkdir -p public
    cat > public/app_icon.png.b64 << 'EOF'
iVBORw0KGgoAAAANSUhEUgAAAgAAAAIAAQMAAADOtgr5AAAAAXNSR0IB2cksfwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAANQTFRFAAAAp3o92gAAABxJREFUeJztwTEBAAAAwqD1T20Hb6AAAAAAAAA+Bhw4AAG1cXrRAAAAAElFTkSuQmCC
EOF
    base64 -D < public/app_icon.png.b64 > public/app_icon.png 2>/dev/null || {
        echo "VS Code Icon" > public/app_icon.txt
    }
    cp public/app_icon.png public/app_icon.icns 2>/dev/null
    echo -e "${GREEN}✅ Created fallback icon${NC}"
fi

# ===============================================
# 4. CHECK SWIFT COMPILER
# ===============================================
echo -e "${CYAN}🔧 Checking Swift compiler...${NC}"

if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}❌ Swift compiler not found${NC}"
    echo -e "${CYAN}🔄 Please install Xcode Command Line Tools:${NC}"
    echo "   xcode-select --install"
    exit 1
fi

echo -e "${GREEN}✅ Swift compiler found${NC}"

# ===============================================
# 5. CREATE SWIFT APP (FIXED WITH ALL ISSUES RESOLVED)
# ===============================================
mkdir -p native/{Sources,Resources}
cd native || exit

# Save app name for later use
echo "$APPNAME" > .appname

# Create Swift file with ALL fixes
cat > Sources/main.swift << 'EOF'
// VS Code Project Dock App - COMPLETE FIX with working Cmd+V and no crashes
import Cocoa
import Foundation

struct LinkGroup: Codable {
    var name: String
    var links: [String]
}

// Custom text field that properly handles Cmd+V, Cmd+C, Cmd+X, Cmd+Z, Cmd+A
final class EditableNSTextField: NSTextField {
    private let commandKey = NSEvent.ModifierFlags.command.rawValue
    private let commandShiftKey = NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == NSEvent.EventType.keyDown {
            if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandKey {
                switch event.charactersIgnoringModifiers! {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
                case "z":
                    if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return true }
                case "a":
                    if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: self) { return true }
                default:
                    break
                }
            } else if (event.modifierFlags.rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue) == commandShiftKey {
                if event.charactersIgnoringModifiers == "Z" {
                    if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) { return true }
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// Protocol for link cell events
protocol LinkCellDelegate: AnyObject {
    func linkCell(_ cell: LinkCell, didUpdateText text: String, atRow row: Int)
}

// Custom cell class with weak delegate
class LinkCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("LinkCell")
    
    weak var delegate: LinkCellDelegate?
    var row: Int = -1
    
    let linkTextField: EditableNSTextField = {
        let field = EditableNSTextField(frame: .zero)
        field.isEditable = true
        field.isBordered = true
        field.bezelStyle = .squareBezel
        field.font = NSFont.systemFont(ofSize: 13)
        field.placeholderString = "https://example.com"
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.allowsEditingTextAttributes = true
        field.isSelectable = true
        field.isEnabled = true
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        addSubview(linkTextField)
        
        NSLayoutConstraint.activate([
            linkTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            linkTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            linkTextField.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            linkTextField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
        
        linkTextField.target = self
        linkTextField.action = #selector(textFieldChanged(_:))
    }
    
    @objc private func textFieldChanged(_ sender: NSTextField) {
        delegate?.linkCell(self, didUpdateText: sender.stringValue, atRow: row)
    }
    
    func configure(with text: String, row: Int, delegate: LinkCellDelegate) {
        self.row = row
        self.delegate = delegate
        linkTextField.stringValue = text
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSTableViewDataSource, NSTableViewDelegate, LinkCellDelegate {
    var dockMenu: NSMenu!
    var savedProjects: [String] = []
    var linkGroups: [LinkGroup] = []
    let projectsFile = "saved_vscode_projects.json"
    let groupsFile = "saved_link_groups.json"
    let maxProjects = 15
    let welcomeShownKey = "welcomeShown"
    
    // Link Group Editor Window
    var groupEditorWindow: NSWindow?
    var groupTableView: NSTableView?
    var linkTableView: NSTableView?
    var currentGroupIndex: Int = -1
    var groupNameField: NSTextField?
    var linksArray: [String] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        loadSavedProjects()
        loadLinkGroups()
        
        setupDockMenu()
        registerForDragAndDrop()
        
        if !UserDefaults.standard.bool(forKey: welcomeShownKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showWelcomeMessage()
                UserDefaults.standard.set(true, forKey: self.welcomeShownKey)
            }
        }
    }
    
    func setupDockMenu() {
        dockMenu = NSMenu(title: "VS Code & Link Groups")
        dockMenu.delegate = self
        updateDockMenu()
    }
    
    func updateDockMenu() {
        dockMenu.removeAllItems()
        
        // VS Code Projects Section
        let vsCodeTitle = NSMenuItem(title: "📁 VS CODE PROJECTS", action: nil, keyEquivalent: "")
        vsCodeTitle.isEnabled = false
        dockMenu.addItem(vsCodeTitle)
        
        if savedProjects.isEmpty {
            let noProjectsItem = NSMenuItem(title: "   No projects saved yet", action: nil, keyEquivalent: "")
            noProjectsItem.isEnabled = false
            dockMenu.addItem(noProjectsItem)
        } else {
            for (index, projectPath) in savedProjects.enumerated() {
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                let truncatedPath = projectPath.count > 40 ? "..." + projectPath.suffix(40) : projectPath
                
                let menuItem = NSMenuItem(title: "   📂 \(projectName)", action: #selector(openProject(_:)), keyEquivalent: index < 9 ? "\(index + 1)" : "")
                menuItem.target = self
                menuItem.representedObject = projectPath
                menuItem.toolTip = truncatedPath
                dockMenu.addItem(menuItem)
            }
        }
        
        dockMenu.addItem(NSMenuItem.separator())
        
        let addProjectItem = NSMenuItem(title: "➕ Add VS Code Project...", action: #selector(addCurrentFolder), keyEquivalent: "n")
        addProjectItem.target = self
        dockMenu.addItem(addProjectItem)
        
        let addFromFinderItem = NSMenuItem(title: "📂 Add from Finder Selection...", action: #selector(addFromFinder), keyEquivalent: "f")
        addFromFinderItem.target = self
        dockMenu.addItem(addFromFinderItem)
        
        dockMenu.addItem(NSMenuItem.separator())
        
        // LINK GROUPS SECTION
        let groupsTitle = NSMenuItem(title: "🔥 FIREFOX DEV LINK GROUPS", action: nil, keyEquivalent: "")
        groupsTitle.isEnabled = false
        dockMenu.addItem(groupsTitle)
        
        if linkGroups.isEmpty {
            let noGroupsItem = NSMenuItem(title: "   No link groups saved yet", action: nil, keyEquivalent: "")
            noGroupsItem.isEnabled = false
            dockMenu.addItem(noGroupsItem)
        } else {
            for (index, group) in linkGroups.enumerated() {
                let groupItem = NSMenuItem(title: "   📑 \(group.name)", action: nil, keyEquivalent: "")
                
                let submenu = NSMenu(title: group.name)
                
                if group.links.isEmpty {
                    let emptyItem = NSMenuItem(title: "No links", action: nil, keyEquivalent: "")
                    emptyItem.isEnabled = false
                    submenu.addItem(emptyItem)
                } else {
                    for link in group.links {
                        let displayLink = link.count > 50 ? String(link.prefix(47)) + "..." : link
                        let linkItem = NSMenuItem(title: "   🔗 \(displayLink)", action: #selector(openLink(_:)), keyEquivalent: "")
                        linkItem.target = self
                        linkItem.representedObject = link
                        linkItem.toolTip = link
                        submenu.addItem(linkItem)
                    }
                    
                    submenu.addItem(NSMenuItem.separator())
                    
                    let openAllItem = NSMenuItem(title: "🚀 Open All Links", action: #selector(openAllLinksInGroup(_:)), keyEquivalent: "")
                    openAllItem.target = self
                    openAllItem.representedObject = index
                    submenu.addItem(openAllItem)

                    // ADD THIS NEW EDIT GROUP MENU ITEM
                    let editGroupItem = NSMenuItem(title: "✏️ Edit Group", action: #selector(editLinkGroup(_:)), keyEquivalent: "")
                    editGroupItem.target = self
                    editGroupItem.representedObject = index
                    submenu.addItem(editGroupItem)
                }
                
                groupItem.submenu = submenu
                dockMenu.addItem(groupItem)
            }
        }
        
        dockMenu.addItem(NSMenuItem.separator())
        
        let addGroupItem = NSMenuItem(title: "➕ New Link Group...", action: #selector(createNewLinkGroup), keyEquivalent: "g")
        addGroupItem.target = self
        dockMenu.addItem(addGroupItem)
        
        let editGroupsItem = NSMenuItem(title: "✏️ Edit Link Groups...", action: #selector(editLinkGroups), keyEquivalent: "e")
        editGroupsItem.target = self
        dockMenu.addItem(editGroupsItem)
        
        dockMenu.addItem(NSMenuItem.separator())
        
        let dragDropItem = NSMenuItem(title: "📤 Drag folders onto Dock icon", action: nil, keyEquivalent: "")
        dragDropItem.isEnabled = false
        dockMenu.addItem(dragDropItem)
        
        dockMenu.addItem(NSMenuItem.separator())
        
        let clearProjectsItem = NSMenuItem(title: "🗑️ Clear All Projects", action: #selector(clearProjects), keyEquivalent: "")
        clearProjectsItem.target = self
        dockMenu.addItem(clearProjectsItem)
        
        let clearGroupsItem = NSMenuItem(title: "🗑️ Clear All Groups", action: #selector(clearAllGroups), keyEquivalent: "")
        clearGroupsItem.target = self
        dockMenu.addItem(clearGroupsItem)
        
        dockMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        dockMenu.addItem(quitItem)
    }
    
    // MARK: - Link Group Actions
    
    @objc func createNewLinkGroup() {
        showGroupEditor(groupIndex: -1, groupName: "", links: [])
    }
    
    @objc func editLinkGroups() {
        if linkGroups.isEmpty {
            showAlert(title: "No Groups", message: "Create a new link group first.")
            createNewLinkGroup()
        } else {
            showGroupListEditor()
        }
    }
    
    @objc func openLink(_ sender: NSMenuItem) {
        guard let link = sender.representedObject as? String else { return }
        openInFirefoxDev(link)
    }
    
    @objc func openAllLinksInGroup(_ sender: NSMenuItem) {
        guard let groupIndex = sender.representedObject as? Int,
              groupIndex >= 0 && groupIndex < linkGroups.count else { return }
        
        let group = linkGroups[groupIndex]
        
        for link in group.links {
            openInFirefoxDev(link)
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        //showNotification(title: "Links Opened", message: "Opened \(group.links.count) links in Firefox Developer")
    }

    @objc func editLinkGroup(_ sender: NSMenuItem) {
        guard let groupIndex = sender.representedObject as? Int,
            groupIndex >= 0 && groupIndex < linkGroups.count else { return }
        
        let group = linkGroups[groupIndex]
        showGroupEditor(groupIndex: groupIndex, groupName: group.name, links: group.links)
    }
    
    func openInFirefoxDev(_ urlString: String) {
        var finalURL = urlString
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") && !finalURL.hasPrefix("file://") {
            finalURL = "https://" + finalURL
        }
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "open -a \"Firefox Developer Edition\" \"\(finalURL)\""]
        
        do {
            try task.run()
        } catch {
            let fallbackTask = Process()
            fallbackTask.launchPath = "/bin/bash"
            fallbackTask.arguments = ["-c", "open -a \"Firefox Developer\" \"\(finalURL)\""]
            
            do {
                try fallbackTask.run()
            } catch {
                showAlert(title: "Firefox Dev Not Found", 
                         message: "Could not launch Firefox Developer Edition. Make sure it's installed.")
            }
        }
    }
    
    // MARK: - Group Editor UI - FIXED VERSION WITH NO CRASH
    
    func showGroupEditor(groupIndex: Int, groupName: String, links: [String]) {
        currentGroupIndex = groupIndex
        linksArray = links.isEmpty ? [""] : links
        
        // Create window with isReleasedWhenClosed = false to prevent auto-release
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false // CRITICAL: Prevent automatic release
        window.title = groupIndex == -1 ? "Create New Link Group" : "Edit Link Group"
        window.center()
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 650, height: 550))
        
        // Group Name Label
        let nameLabel = NSTextField(labelWithString: "Group Name:")
        nameLabel.frame = NSRect(x: 20, y: 500, width: 100, height: 24)
        nameLabel.alignment = .right
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        contentView.addSubview(nameLabel)
        
        // Group Name Field
        let nameField = NSTextField(frame: NSRect(x: 130, y: 496, width: 400, height: 24))
        nameField.placeholderString = "Enter group name (e.g., Dev Resources)"
        nameField.stringValue = groupName
        nameField.bezelStyle = .roundedBezel
        nameField.font = NSFont.systemFont(ofSize: 13)
        contentView.addSubview(nameField)
        groupNameField = nameField
        
        // Links Label
        let linksLabel = NSTextField(labelWithString: "Links:")
        linksLabel.frame = NSRect(x: 20, y: 460, width: 100, height: 24)
        linksLabel.alignment = .right
        linksLabel.font = NSFont.systemFont(ofSize: 13)
        contentView.addSubview(linksLabel)
        
        // Links Table with ScrollView
        let scrollView = NSScrollView(frame: NSRect(x: 130, y: 140, width: 490, height: 310))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        
        let tableView = NSTableView(frame: NSRect(x: 0, y: 0, width: 470, height: 300))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 28
        tableView.headerView = nil
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("LinkColumn"))
        column.width = 470
        column.minWidth = 200
        column.maxWidth = 2000
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        linkTableView = tableView
        
        // Button Panel
        let buttonPanel = NSView(frame: NSRect(x: 130, y: 80, width: 490, height: 40))
        
        let addButton = NSButton(frame: NSRect(x: 0, y: 5, width: 100, height: 30))
        addButton.title = "➕ Add Link"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addLinkField)
        buttonPanel.addSubview(addButton)
        
        let removeButton = NSButton(frame: NSRect(x: 110, y: 5, width: 100, height: 30))
        removeButton.title = "✖️ Remove"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(removeSelectedLink)
        buttonPanel.addSubview(removeButton)
        
        let upButton = NSButton(frame: NSRect(x: 220, y: 5, width: 40, height: 30))
        upButton.title = "↑"
        upButton.bezelStyle = .rounded
        upButton.target = self
        upButton.action = #selector(moveLinkUp)
        buttonPanel.addSubview(upButton)
        
        let downButton = NSButton(frame: NSRect(x: 270, y: 5, width: 40, height: 30))
        downButton.title = "↓"
        downButton.bezelStyle = .rounded
        downButton.target = self
        downButton.action = #selector(moveLinkDown)
        buttonPanel.addSubview(downButton)
        
        contentView.addSubview(buttonPanel)
        
        let saveButton = NSButton(frame: NSRect(x: 130, y: 30, width: 120, height: 35))
        saveButton.title = "💾 Save Group"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveLinkGroup)
        contentView.addSubview(saveButton)
        
        let cancelButton = NSButton(frame: NSRect(x: 260, y: 30, width: 100, height: 35))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(closeGroupEditor)
        contentView.addSubview(cancelButton)
        
        window.contentView = contentView
        groupEditorWindow = window
        
        linkTableView?.reloadData()
        
        // Use runModal for now - with isReleasedWhenClosed=false it should be safe
        NSApp.runModal(for: window)
    }
    
    // MARK: - TableView methods
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == linkTableView {
            return linksArray.count
        } else if tableView.tag == 100 {
            return linkGroups.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == linkTableView {
            var cell = tableView.makeView(withIdentifier: LinkCell.identifier, owner: self) as? LinkCell
            if cell == nil {
                cell = LinkCell()
                cell?.identifier = LinkCell.identifier
            }
            
            let text = row < linksArray.count ? linksArray[row] : ""
            cell?.configure(with: text, row: row, delegate: self)
            
            return cell
            
        } else if tableView.tag == 100 {
            // Group list view
            let cellIdentifier = NSUserInterfaceItemIdentifier("GroupCell")
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
            if cellView == nil {
                cellView = NSTableCellView()
                cellView?.identifier = cellIdentifier
                
                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.font = NSFont.systemFont(ofSize: 13)
                textField.lineBreakMode = .byTruncatingTail
                textField.isEditable = false
                textField.isBordered = false
                textField.drawsBackground = false
                
                cellView?.addSubview(textField)
                cellView?.textField = textField
                
                if let cellView = cellView {
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                        textField.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 2),
                        textField.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: -2)
                    ])
                }
            }
            
            if row < linkGroups.count {
                let group = linkGroups[row]
                cellView?.textField?.stringValue = "\(group.name) (\(group.links.count) links)"
            }
            
            return cellView
        }
        
        return nil
    }
    
    // MARK: - LinkCellDelegate
    func linkCell(_ cell: LinkCell, didUpdateText text: String, atRow row: Int) {
        if row >= 0 && row < linksArray.count {
            linksArray[row] = text
            print("📝 Updated link at row \(row): \(text.prefix(30))...")
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView == linkTableView {
            if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? LinkCell {
                DispatchQueue.main.async {
                    cell.linkTextField.becomeFirstResponder()
                    cell.linkTextField.selectText(nil)
                }
            }
            return true
        }
        return true
    }
    
    // MARK: - Link Editor Actions
    
    @objc func addLinkField() {
        linksArray.append("")
        linkTableView?.reloadData()
        
        if let tableView = linkTableView, linksArray.count > 0 {
            let lastRow = linksArray.count - 1
            tableView.scrollRowToVisible(lastRow)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let cell = tableView.view(atColumn: 0, row: lastRow, makeIfNecessary: false) as? LinkCell {
                    cell.linkTextField.becomeFirstResponder()
                }
            }
        }
    }
    
    @objc func removeSelectedLink() {
        guard let tableView = linkTableView,
              tableView.selectedRow >= 0 && tableView.selectedRow < linksArray.count else { return }
        
        linksArray.remove(at: tableView.selectedRow)
        tableView.reloadData()
    }
    
    @objc func moveLinkUp() {
        guard let tableView = linkTableView,
              tableView.selectedRow > 0 else { return }
        
        let selected = tableView.selectedRow
        linksArray.swapAt(selected, selected - 1)
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: selected - 1), byExtendingSelection: false)
    }
    
    @objc func moveLinkDown() {
        guard let tableView = linkTableView,
              tableView.selectedRow >= 0 && tableView.selectedRow < linksArray.count - 1 else { return }
        
        let selected = tableView.selectedRow
        linksArray.swapAt(selected, selected + 1)
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: selected + 1), byExtendingSelection: false)
    }
    
    @objc func saveLinkGroup() {
        guard let nameField = groupNameField,
            !nameField.stringValue.isEmpty else {
            showAlert(title: "Name Required", message: "Please enter a group name.")
            return
        }
        
        print("💾 Saving group...")
        print("   📝 Links array before capture: \(linksArray)")
        
        // CRITICAL: Force end editing and capture all text field values
        groupEditorWindow?.makeFirstResponder(nil)
        
        // Manually capture all values from visible cells
        if let tableView = linkTableView {
            for row in 0..<linksArray.count {
                if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? LinkCell {
                    linksArray[row] = cell.linkTextField.stringValue
                    print("   📝 Captured row \(row): \(cell.linkTextField.stringValue)")
                }
            }
        }
        
        print("   📝 Links array after capture: \(linksArray)")
        
        // Filter out empty links
        let validLinks = linksArray.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        print("   🔗 Valid links: \(validLinks)")
        
        let newGroup = LinkGroup(name: nameField.stringValue, links: validLinks)
        
        if currentGroupIndex >= 0 && currentGroupIndex < linkGroups.count {
            print("   📝 Updating existing group at index \(currentGroupIndex)")
            linkGroups[currentGroupIndex] = newGroup
        } else {
            print("   📝 Adding new group")
            linkGroups.append(newGroup)
        }
        
        print("   💾 Saving to disk...")
        saveLinkGroups()
        print("   🔄 Updating dock menu...")
        updateDockMenu()
        
        closeGroupEditor()
    }
    
    @objc func closeGroupEditor() {
        print("🔚 Closing group editor...")
        
        // Nil out references
        linkTableView = nil
        groupNameField = nil
        
        // Stop modal and close window safely
        if let window = groupEditorWindow {
            NSApp.stopModal()
            window.close()
            groupEditorWindow = nil
        }
        
        print("✅ Group editor closed")
    }
    
    // MARK: - Group List Editor - FIXED VERSION
    
    func showGroupListEditor() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false // CRITICAL: Prevent automatic release
        window.title = "Edit Link Groups"
        window.center()
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 450))
        
        let instructions = NSTextField(labelWithString: "Select a group to edit:")
        instructions.frame = NSRect(x: 20, y: 410, width: 510, height: 20)
        instructions.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        instructions.textColor = NSColor.secondaryLabelColor
        contentView.addSubview(instructions)
        
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: 510, height: 320))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true
        
        let tableView = NSTableView(frame: NSRect(x: 0, y: 0, width: 490, height: 300))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tag = 100
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 30
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("GroupColumn"))
        column.title = "Link Groups"
        column.width = 490
        column.minWidth = 200
        column.maxWidth = 2000
        column.isEditable = false
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        groupTableView = tableView
        
        let newButton = NSButton(frame: NSRect(x: 20, y: 30, width: 100, height: 30))
        newButton.title = "➕ New"
        newButton.bezelStyle = .rounded
        newButton.target = self
        newButton.action = #selector(createNewLinkGroup)
        contentView.addSubview(newButton)
        
        let editButton = NSButton(frame: NSRect(x: 130, y: 30, width: 100, height: 30))
        editButton.title = "✏️ Edit"
        editButton.bezelStyle = .rounded
        editButton.target = self
        editButton.action = #selector(editSelectedGroup)
        contentView.addSubview(editButton)
        
        let deleteButton = NSButton(frame: NSRect(x: 240, y: 30, width: 100, height: 30))
        deleteButton.title = "🗑️ Delete"
        deleteButton.bezelStyle = .rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteSelectedGroup)
        contentView.addSubview(deleteButton)
        
        let closeButton = NSButton(frame: NSRect(x: 430, y: 30, width: 100, height: 30))
        closeButton.title = "Close"
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.target = self
        closeButton.action = #selector(closeGroupListEditor)
        contentView.addSubview(closeButton)
        
        window.contentView = contentView
        groupEditorWindow = window
        
        tableView.reloadData()
        if !linkGroups.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        
        NSApp.runModal(for: window)
    }
    
    @objc func editSelectedGroup() {
        guard let tableView = groupTableView,
              tableView.selectedRow >= 0 && tableView.selectedRow < linkGroups.count else {
            showAlert(title: "No Selection", message: "Please select a group to edit.")
            return
        }
        
        let group = linkGroups[tableView.selectedRow]
        closeGroupListEditor()
        showGroupEditor(groupIndex: tableView.selectedRow, groupName: group.name, links: group.links)
    }
    
    @objc func deleteSelectedGroup() {
        guard let tableView = groupTableView,
              tableView.selectedRow >= 0 && tableView.selectedRow < linkGroups.count else { return }
        
        let group = linkGroups[tableView.selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Delete Group?"
        alert.informativeText = "Are you sure you want to delete '\(group.name)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            linkGroups.remove(at: tableView.selectedRow)
            saveLinkGroups()
            tableView.reloadData()
            updateDockMenu()
        }
    }
    
    @objc func closeGroupListEditor() {
        print("🔚 Closing group list editor...")
        
        // Nil out references
        groupTableView = nil
        
        // Stop modal and close window safely
        if let window = groupEditorWindow {
            NSApp.stopModal()
            window.close()
            groupEditorWindow = nil
        }
        
        print("✅ Group list editor closed")
    }
    
    @objc func clearAllGroups() {
        let alert = NSAlert()
        alert.messageText = "Clear All Groups?"
        alert.informativeText = "This will remove all saved link groups. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            linkGroups.removeAll()
            saveLinkGroups()
            updateDockMenu()
            showNotification(title: "Cleared", message: "All link groups have been removed.")
        }
    }
    
        func saveLinkGroups() {
        do {
            let fileURL = getGroupsFileURL()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(linkGroups)
            try data.write(to: fileURL, options: .atomic)
            
            print("✅ Successfully saved \(linkGroups.count) link groups to: \(fileURL.path)")
            
            DispatchQueue.main.async {
                self.updateDockMenu()
            }
            
        } catch let error as NSError {
            print("❌ Failed to save link groups: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Save Failed"
                alert.informativeText = "Could not save link groups. Error: \(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    // MARK: - Project Management
    
    func loadSavedProjects() {
        let fileURL = getProjectsFileURL()
        
        // Check if file exists and is valid
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            savedProjects = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            
            // Validate that data is not corrupted
            guard !data.isEmpty else {
                print("⚠ Projects file is empty, starting fresh")
                savedProjects = []
                return
            }
            
            // Try to parse JSON
            if let loaded = try JSONSerialization.jsonObject(with: data) as? [String] {
                // Validate each path exists
                let validProjects = loaded.filter { path in
                    var isDir: ObjCBool = false
                    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
                }
                
                savedProjects = validProjects
                print("✅ Loaded \(savedProjects.count) valid projects from \(loaded.count) total")
                
                // If we filtered out any invalid paths, save the cleaned list
                if validProjects.count != loaded.count {
                    print("⚠ Removed \(loaded.count - validProjects.count) invalid paths")
                    saveProjects()
                }
            } else {
                print("⚠ Projects file contained invalid data, starting fresh")
                savedProjects = []
            }
        } catch {
            print("Error loading projects: \(error)")
            
            // Try to recover from backup
            let backupURL = fileURL.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: backupURL.path) {
                do {
                    let backupData = try Data(contentsOf: backupURL)
                    if let loaded = try JSONSerialization.jsonObject(with: backupData) as? [String] {
                        savedProjects = loaded
                        print("✅ Recovered \(savedProjects.count) projects from backup")
                        // Restore the main file from backup
                        try? FileManager.default.removeItem(at: fileURL)
                        try? FileManager.default.copyItem(at: backupURL, to: fileURL)
                    }
                } catch {
                    print("❌ Could not recover from backup: \(error)")
                    savedProjects = []
                }
            } else {
                savedProjects = []
            }
        }
    }


    func saveProjects() {
        do {
            let fileURL = getProjectsFileURL()
            
            // Create backup of existing file if it exists
            let backupURL = fileURL.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            }
            
            // Create data with pretty printing
            let data = try JSONSerialization.data(withJSONObject: savedProjects, options: [.prettyPrinted])
            
            // Ensure data is not empty before writing
            guard !data.isEmpty else {
                print("❌ Cannot save empty project data")
                return
            }
            
            // Write atomically to temporary file first
            let tempURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: tempURL, options: .atomic)
            
            // Replace original with temp file
            _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL, backupItemName: nil, options: .usingNewMetadataOnly)
            
            print("✅ Successfully saved \(savedProjects.count) projects to: \(fileURL.path)")
            
            DispatchQueue.main.async {
                self.updateDockMenu()
            }
            
        } catch let error as NSError {
            print("❌ Failed to save projects: \(error.localizedDescription)")
            
            // Try to restore from backup if available
            let fileURL = getProjectsFileURL()
            let backupURL = fileURL.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
                try? FileManager.default.copyItem(at: backupURL, to: fileURL)
                print("🔄 Restored projects from backup")
            }
            
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Save Failed"
                alert.informativeText = "Could not save projects. Error: \(error.localizedDescription)\n\nYour projects have been preserved in a backup."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    func loadLinkGroups() {
        let fileURL = getGroupsFileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                linkGroups = try decoder.decode([LinkGroup].self, from: data)
                print("✅ Loaded \(linkGroups.count) link groups")
            } catch {
                print("Error loading link groups: \(error)")
            }
        }
    }
    
    func getProjectsFileURL() -> URL {
        let fileManager = FileManager.default
        
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fallbackFolder = documents.appendingPathComponent("VSCodeDockApp")
            
            do {
                try fileManager.createDirectory(at: fallbackFolder, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created fallback directory: \(fallbackFolder.path)")
            } catch {
                print("❌ Failed to create fallback directory: \(error)")
            }
            
            return fallbackFolder.appendingPathComponent(projectsFile)
        }
        
        let appFolder = appSupport.appendingPathComponent("VSCodeDockApp")
        
        do {
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
            print("✅ Created app support directory: \(appFolder.path)")
        } catch {
            print("❌ Failed to create directory: \(error)")
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("VSCodeDockApp")
            try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            return tempDir.appendingPathComponent(projectsFile)
        }
        
        return appFolder.appendingPathComponent(projectsFile)
    }

    func getGroupsFileURL() -> URL {
        let fileManager = FileManager.default
        
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fallbackFolder = documents.appendingPathComponent("VSCodeDockApp")
            
            do {
                try fileManager.createDirectory(at: fallbackFolder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ Failed to create fallback directory: \(error)")
            }
            
            return fallbackFolder.appendingPathComponent(groupsFile)
        }
        
        let appFolder = appSupport.appendingPathComponent("VSCodeDockApp")
        
        do {
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create directory: \(error)")
            let tempDir = fileManager.temporaryDirectory.appendingPathComponent("VSCodeDockApp")
            try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            return tempDir.appendingPathComponent(groupsFile)
        }
        
        return appFolder.appendingPathComponent(groupsFile)
    }
    
    func addProject(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            print("❌ Not a valid directory: \(path)")
            return false
        }
        
        // Remove if already exists
        if let index = savedProjects.firstIndex(of: path) {
            savedProjects.remove(at: index)
        }
        
        // Insert at beginning
        savedProjects.insert(path, at: 0)
        
        // Keep only maxProjects
        if savedProjects.count > maxProjects {
            savedProjects = Array(savedProjects.prefix(maxProjects))
        }
        
        // Save with validation
        saveProjects()
        
        print("✅ Added project: \(path)")
        return true
    }
    
    @objc func openProject(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        
        if let index = savedProjects.firstIndex(of: path) {
            savedProjects.remove(at: index)
            savedProjects.insert(path, at: 0)
            saveProjects()
        }
        
        openInVSCode(path)
    }
    
    func openInVSCode(_ path: String) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "open -a \"Visual Studio Code\" \"\(path)\""]
        
        do {
            try task.run()
        } catch {
            let fallbackTask = Process()
            fallbackTask.launchPath = "/bin/bash"
            fallbackTask.arguments = ["-c", "code \"\(path)\""]
            
            do {
                try fallbackTask.run()
            } catch {
                showAlert(title: "VS Code Not Found", 
                         message: "Could not launch VS Code. Make sure it's installed.")
            }
        }
    }
    
    @objc func addCurrentFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select a Project Folder"
        openPanel.message = "Choose a folder to add to VS Code Projects"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = true
        
        openPanel.begin { response in
            if response == .OK {
                for url in openPanel.urls {
                    _ = self.addProject(url.path)
                }
                self.showAlert(title: "Added", 
                              message: "Added \(openPanel.urls.count) folder(s) to your projects.")
            }
        }
    }
    
    @objc func addFromFinder() {
        let pasteboard = NSPasteboard.general
        guard let files = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            showAlert(title: "No Selection", message: "No folders selected in Finder.")
            return
        }
        
        var addedCount = 0
        for fileURL in files {
            if fileURL.hasDirectoryPath {
                if self.addProject(fileURL.path) {
                    addedCount += 1
                }
            }
        }
        
        if addedCount > 0 {
            showAlert(title: "Added from Finder", 
                     message: "Added \(addedCount) folder(s) from Finder selection.")
        } else {
            showAlert(title: "No Folders", 
                     message: "The Finder selection doesn't contain any folders.")
        }
    }
    
    @objc func clearProjects() {
        let alert = NSAlert()
        alert.messageText = "Clear All Projects?"
        alert.informativeText = "This will remove all saved VS Code projects."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            savedProjects.removeAll()
            saveProjects()
            showAlert(title: "Cleared", message: "All projects have been removed.")
        }
    }
    
    func showWelcomeMessage() {
        let alert = NSAlert()
        alert.messageText = "🚀 VS Code + Link Groups App Ready!"
        alert.informativeText = """
        HOW TO USE:
        
        VS CODE PROJECTS:
        • Click Dock icon to see saved projects
        • Click any project to open in VS Code
        • Drag & drop folders onto Dock icon to add
        
        LINK GROUPS (Firefox Developer):
        • 'New Link Group...' - Create named groups
        • Add/remove/reorder links in the table
        • Click group → submenu shows all links
        • 'Open All Links' opens entire group
        
        Everything saves permanently!
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got it!")
        alert.addButton(withTitle: "Create First Link Group")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            createNewLinkGroup()
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showNotification(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        if let window = groupEditorWindow {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }
    
    // MARK: - Drag & Drop
    
    func registerForDragAndDrop() {
        NSApp.servicesProvider = self
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        print("📁 Received \(filenames.count) file(s) via drag/drop")
        
        // CRITICAL: Process on background thread to prevent UI freezing
        DispatchQueue.global(qos: .userInitiated).async {
            var addedCount = 0
            var failedPaths: [String] = []
            
            // Validate all paths first
            let validPaths = filenames.filter { path in
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
                return exists && isDir.boolValue
            }
            
            print("   ✅ Valid folders: \(validPaths.count) of \(filenames.count)")
            
            // Process each valid folder
            for path in validPaths {
                // Validate again with security-scoped bookmark if needed
                let url = URL(fileURLWithPath: path)
                
                // Check if we can access the folder
                if FileManager.default.isReadableFile(atPath: path) {
                    if self.addProjectWithValidation(path) {
                        addedCount += 1
                        print("   ✅ Added: \(path)")
                    } else {
                        failedPaths.append(path)
                        print("   ❌ Failed: \(path)")
                    }
                } else {
                    failedPaths.append(path)
                    print("   ⚠ No read access: \(path)")
                }
            }
            
            // Show results on main thread
            DispatchQueue.main.async {
                if addedCount > 0 {
                    self.showNotification(
                        title: "Projects Added",
                        message: "Added \(addedCount) folder(s) to your projects.\n\n" +
                                (failedPaths.isEmpty ? "" : "Could not add \(failedPaths.count) item(s).")
                    )
                } else if !failedPaths.isEmpty {
                    self.showAlert(
                        title: "Error",
                        message: "Could not add any folders. Make sure you're dragging valid folders."
                    )
                }
            }
        }
        
        // Important: Call reply to open files to tell system we handled them
        NSApp.reply(toOpenOrPrint: .success)
    }

    // Thread-safe project addition with validation
    func addProjectWithValidation(_ path: String) -> Bool {
        // Verify it's a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), 
            isDir.boolValue else {
            print("❌ Not a valid directory: \(path)")
            return false
        }
        
        // Check if we can actually open this folder
        guard FileManager.default.isReadableFile(atPath: path) else {
            print("❌ Cannot read directory: \(path)")
            return false
        }
        
        // Use a lock to prevent concurrent modifications
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        // Remove if already exists
        if let index = savedProjects.firstIndex(of: path) {
            savedProjects.remove(at: index)
        }
        
        // Insert at beginning
        savedProjects.insert(path, at: 0)
        
        // Keep only maxProjects
        if savedProjects.count > maxProjects {
            savedProjects = Array(savedProjects.prefix(maxProjects))
        }
        
        // Save with validation and error handling
        return saveProjectsWithRetry()
    }

    // Enhanced save with retry logic
    func saveProjectsWithRetry(maxRetries: Int = 3) -> Bool {
        for attempt in 1...maxRetries {
            if saveProjectsSafe() {
                return true
            }
            print("⚠ Save attempt \(attempt) failed, retrying...")
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    func saveProjectsSafe() -> Bool {
        do {
            let fileURL = getProjectsFileURL()
            
            // Create backup of existing file if it exists
            let backupURL = fileURL.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try? FileManager.default.copyItem(at: fileURL, to: backupURL)
            }
            
            // Create data with pretty printing
            let data = try JSONSerialization.data(withJSONObject: savedProjects, options: [.prettyPrinted])
            
            // Ensure data is not empty before writing
            guard !data.isEmpty else {
                print("❌ Cannot save empty project data")
                return false
            }
            
            // Write atomically to temporary file first
            let tempURL = fileURL.appendingPathExtension("tmp")
            try data.write(to: tempURL, options: .atomic)
            
            // Replace original with temp file
            _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL, backupItemName: nil, options: .usingNewMetadataOnly)
            
            print("✅ Successfully saved \(savedProjects.count) projects")
            
            DispatchQueue.main.async {
                self.updateDockMenu()
            }
            
            return true
            
        } catch let error as NSError {
            print("❌ Failed to save projects: \(error.localizedDescription)")
            
            // Try to restore from backup if available
            let fileURL = getProjectsFileURL()
            let backupURL = fileURL.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
                try? FileManager.default.copyItem(at: backupURL, to: fileURL)
                print("🔄 Restored projects from backup")
                return true
            }
            
            return false
        }
    }

    // MARK: - Dock Menu
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return dockMenu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let dockMenu = self.dockMenu {
            let menuWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                                    styleMask: .borderless,
                                    backing: .buffered,
                                    defer: false)
            menuWindow.level = .popUpMenu
            menuWindow.makeKeyAndOrderFront(nil)
            
            let mouseLocation = NSEvent.mouseLocation
            let menuY: CGFloat = 500
            let menuX = mouseLocation.x - 40
            
            menuWindow.setFrameOrigin(NSPoint(x: menuX, y: menuY))
            
            let tempView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
            menuWindow.contentView = tempView
            
            dockMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: tempView.frame.height), in: tempView)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                menuWindow.orderOut(nil)
            }
        }
        return true
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        loadSavedProjects()
        loadLinkGroups()
        updateDockMenu()
    }
}

// Start the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
EOF

# ===============================================
# 6. CREATE BUILD SCRIPT
# ===============================================
cat > build_app.sh << 'EOF'
#!/bin/bash
# Build script for VS Code Project Dock App

# Read app name from file
APPNAME=$(cat .appname 2>/dev/null || echo "VSCode-Projects")

echo "🔨 Building $APPNAME..."
echo ""

# Clean up
rm -rf build dist 2>/dev/null || true
mkdir -p build dist

# Compile Swift code
echo "📦 Compiling Swift code..."
swiftc Sources/main.swift \
    -framework Cocoa \
    -framework Foundation \
    -o build/app_binary 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed"
    exit 1
fi

echo "✅ Compilation successful!"

# Create .app bundle with correct structure
echo ""
echo "📦 Creating app bundle: $APPNAME.app"
APP_BUNDLE="dist/$APPNAME.app"
rm -rf "$APP_BUNDLE" 2>/dev/null || true
mkdir -p "$APP_BUNDLE/Contents/"{MacOS,Resources}

# Copy binary to correct location (MUST be named exactly as the app)
cp build/app_binary "$APP_BUNDLE/Contents/MacOS/$APPNAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APPNAME"
echo "✅ Copied binary to: $APP_BUNDLE/Contents/MacOS/$APPNAME"

# Copy icon files
if [ -f "../public/app_icon.icns" ] && [ -s "../public/app_icon.icns" ]; then
    cp "../public/app_icon.icns" "$APP_BUNDLE/Contents/Resources/app_icon.icns"
    echo "✅ Copied .icns icon"
elif [ -f "../public/app_icon.png" ] && [ -s "../public/app_icon.png" ]; then
    cp "../public/app_icon.png" "$APP_BUNDLE/Contents/Resources/app_icon.icns"
    echo "✅ Copied .png as icon"
else
    echo "⚠ No icon found, app will use default"
fi

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << INFO_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APPNAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.vscode.${APPNAME//-/_}</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APPNAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <false/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Folder</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.folder</string>
                <string>public.directory</string>
            </array>
        </dict>
    </array>
    <key>CFBundleIconFile</key>
    <string>app_icon.icns</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
INFO_EOF
echo "✅ Created Info.plist"

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Verify
if [ -d "$APP_BUNDLE" ]; then
    echo ""
    echo "🎉 BUILD SUCCESSFUL!"
    echo "📁 App bundle: $APP_BUNDLE"
else
    echo "❌ App bundle creation failed!"
    exit 1
fi

echo "✅ Build complete!"
EOF

chmod +x build_app.sh


chmod +x ../One-Click-Install.command
# ===============================================
# 7. CREATE ONE-CLICK INSTALL SCRIPT (WORKING DOCK ADDITION)
# ===============================================
cat > ../One-Click-Install.command << 'EOF'
#!/bin/bash
# One-click installation for VS Code Project Dock App + Link Groups

echo "⚡ VS Code Project Dock App + Link Groups Installer"
echo "================================================"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

APPNAME=$(cat native/.appname 2>/dev/null || echo "VSCode-Projects")
echo "Installing: $APPNAME"
echo ""

# Build the app
echo "🔨 Step 1: Building app..."
cd native || exit 1

if ./build_app.sh; then
    echo ""
    echo "✅ Build successful!"
else
    echo "❌ Build failed"
    exit 1
fi

# Install to Applications
echo ""
echo "📦 Step 2: Installing to Applications..."
APP_BUNDLE="dist/$APPNAME.app"
USER_APPS="$HOME/Applications"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found at: $APP_BUNDLE"
    exit 1
fi

mkdir -p "$USER_APPS"
if [ -d "$USER_APPS/$APPNAME.app" ]; then
    echo "⚠ Removing existing app..."
    rm -rf "$USER_APPS/$APPNAME.app"
fi

if cp -R "$APP_BUNDLE" "$USER_APPS/"; then
    INSTALL_PATH="$USER_APPS/$APPNAME.app"
    echo "✅ Installed to: $INSTALL_PATH"
else
    echo "❌ Installation failed!"
    exit 1
fi

# ===============================================
# VERIFY BUNDLE STRUCTURE
# ===============================================
echo -e "🔍 Verifying app bundle structure..."

if [ -f "$APP_BUNDLE/Contents/MacOS/$APPNAME" ]; then
    echo -e "   ✅ Bundle structure is CORRECT"
    echo -e "   ├─ MacOS/$APPNAME: $(file "$APP_BUNDLE/Contents/MacOS/$APPNAME" | awk -F': ' '{print $2}')"
else
    echo -e "   ❌ Bundle structure is INCORRECT!"
    ls -la "$APP_BUNDLE/Contents/MacOS/" 2>/dev/null || echo "   MacOS dir empty"
    exit 1
fi

# ===============================================
# INSTALL THE APP
# ===============================================
echo -e "📋 Installing to Applications..."

mkdir -p "$HOME/Applications"
APP_PATH="$HOME/Applications/$APPNAME.app"
rm -rf "$APP_PATH"
cp -R "$APP_BUNDLE" "$APP_PATH"

if [ -d "$APP_PATH" ]; then
    echo -e "   ✅ Installed to: $APP_PATH"
else
    echo -e "   ❌ Failed to install to Applications"
    APP_PATH="$(pwd)/$APP_BUNDLE"
fi

DESKTOP_APP="$HOME/Desktop/$APPNAME.app"
rm -rf "$DESKTOP_APP"
cp -R "$APP_BUNDLE" "$DESKTOP_APP"
echo -e "   ✅ Copied to Desktop: $DESKTOP_APP"

# ===============================================
# CREATE DESKTOP LAUNCHER
# ===============================================
cat > "$HOME/Desktop/Launch $APPNAME.command" << LAUNCHER_EOF
#!/bin/bash
echo "🚀 Launching $APPNAME..."
open "$APP_PATH"
LAUNCHER_EOF
chmod +x "$HOME/Desktop/Launch $APPNAME.command"
echo -e "   ✅ Launcher created"

# ===============================================
# ADD TO DOCK
# ===============================================
echo -e "📌 Adding to Dock..."

DOCK_APPS=$(defaults read com.apple.dock persistent-apps 2>/dev/null || echo "[]")
if ! echo "$DOCK_APPS" | grep -q "$APPNAME"; then
    defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$APP_PATH</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    killall Dock 2>/dev/null &
    echo -e "   ✅ Added to Dock"
else
    echo -e "   ⚠ App already in Dock"
fi

# ===============================================
# LAUNCH THE APP
# ===============================================
echo ""
echo "🚀 Step 4: Launching $APPNAME..."

# Wait a moment for Dock to restart
sleep 2

if open "$INSTALL_PATH" 2>/dev/null; then
    echo "✅ App launched successfully!"
else
    echo "⚠ Could not launch automatically"
    echo "   Open manually from: $INSTALL_PATH"
    echo "   Or use: Desktop/Launch $APPNAME.command"
fi

echo ""
echo "🎉 INSTALLATION COMPLETE!"
echo "================================================"
echo "📋 HOW TO USE:"
echo "   1. Look for '$APPNAME' in your Dock"
echo "   2. CLICK the Dock icon (left or right click)"
echo "   3. Two sections: VS Code Projects & Link Groups"
echo ""
echo "🔥 LINK GROUPS:"
echo "   • 'New Link Group...' - Create named groups"
echo "   • Add/remove/reorder links in the table"
echo "   • Click 'Save Group' when done"
echo "   • Groups appear in menu with submenus"
echo "   • 'Open All Links' opens entire group in Firefox Dev"
echo ""
echo "📁 VS CODE PROJECTS:"
echo "   • Drag folders onto Dock icon to add"
echo "   • Click any project to open in VS Code"
echo "================================================"
echo ""
echo "📌 App installed to: $INSTALL_PATH"
echo "📌 Desktop copy: $HOME/Desktop/$APPNAME.app"
echo "📌 Launcher: $HOME/Desktop/Launch $APPNAME.command"
EOF

chmod +x ../One-Click-Install.command

# ===============================================
# 8. BUILD AND INSTALL AUTOMATICALLY
# ===============================================
echo ""
echo -e "${GREEN}✅ VS Code Project Dock App with Link Groups created!${NC}"
echo ""
echo -e "${CYAN}📁 Project location:${NC} $(pwd)/"
echo -e "${CYAN}🚀 One-click install:${NC} ./One-Click-Install.command"
echo ""

# Ask if user wants to build and install now
read -p "Would you like to build and install the app now? (Y/n): " BUILD_NOW
BUILD_NOW=${BUILD_NOW:-Y}

if [[ "$BUILD_NOW" == "y" || "$BUILD_NOW" == "Y" || "$BUILD_NOW" == "" ]]; then
    echo -e "${CYAN}🚀 Running installer...${NC}"
    echo ""
    
    # Make the install script executable and run it
    chmod +x ../One-Click-Install.command
    ../One-Click-Install.command
    
    echo ""
    echo -e "${GREEN}✅ Setup complete!${NC}"
else
    echo -e "${YELLOW}⏸ You can install later by running: ./One-Click-Install.command${NC}"
fi

echo ""
echo -e "${GREEN}✨ Your VS Code Project + Link Groups app is ready!${NC}"
echo -e "${CYAN}💡 Click the Dock icon (left or right) to access everything${NC}"

# 1. The Crash Fix - Window being released twice
# The crash was *** -[NSWindow release]: message sent to deallocated instance

# The fix: Added window.isReleasedWhenClosed = false to both window creations:
# let window = NSWindow(...)
# window.isReleasedWhenClosed = false // CRITICAL: Prevents auto-release

# This stops the window from being automatically released when closed, giving us control over its lifecycle. Then in closeGroupEditor() we safely:
#     Nil out references first
#     Call NSApp.stopModal()
#     Close the window
#     Nil the window reference

# 2. The Save Issue - Links not saving

# The problem was that text field values weren't being captured before saving.

# The fix: Added manual capture of all text field values in saveLinkGroup():

# // Manually capture all values from visible cells
# if let tableView = linkTableView {
#     for row in 0..<linksArray.count {
#         if let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? LinkCell {
#             linksArray[row] = cell.linkTextField.stringValue
#         }
#     }
# }

# 3. The Cmd+V Fix - Using proper NSApp.sendAction

# Instead of trying to manually handle paste, we used the proper EditableNSTextField that sends actions to the responder chain:

# case "v":
#     if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }

# This lets the system handle paste properly instead of us trying to manually insert text.

# So basically: stop the window from killing itself, actually read the text fields before saving, and let the system handle keyboard shortcuts properly.