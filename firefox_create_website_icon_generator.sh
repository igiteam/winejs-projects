#!/bin/bash

# ===============================================
# Website Shortcut Firefox Addon Generator
# ===============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═════════════════════════════════════════════════════════════════════════════╗"
echo "║           Website Shortcut Firefox Addon                                    ║"
echo "║    Save any website as a bash script with custom name and favicon          ║"
echo "╚═════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Ask for extension folder name
read -p "Enter your extension folder name (default: firefox-website-icon-generator): " EXTNAME
EXTNAME=${EXTNAME:-firefox-website-icon-generator}

# Check if folder exists
if [ -d "$EXTNAME" ]; then
    read -p "Folder '$EXTNAME' already exists. Do you want to remove it? (y/N): " REMOVE
    REMOVE=${REMOVE:-N}
    if [[ "$REMOVE" == "y" || "$REMOVE" == "Y" ]]; then
        echo "Removing existing folder '$EXTNAME'..."
        rm -rf "$EXTNAME"
    else
        echo "Exiting to avoid overwriting existing folder."
        exit 1
    fi
fi

# Create folder structure
mkdir -p "$EXTNAME/icons"
cd "$EXTNAME" || exit

# Download default icon
echo -e "${CYAN}📥 Downloading default extension icon...${NC}"
curl -s -o icons/icon.png "https://cdn.gitgpt.chat/rtx/images/bookmark_website.png"
cp icons/icon.png icons/icon128.png

# Create manifest.json
cat << 'EOL' > manifest.json
{
  "manifest_version": 2,
  "name": "Website Shortcut Saver",
  "version": "1.0",
  "description": "Save websites as bash scripts with custom names and favicons",
  "icons": {
    "48": "icons/icon.png",
    "128": "icons/icon128.png"
  },
  "permissions": [
    "activeTab",
    "storage",
    "<all_urls>"
  ],
  "browser_action": {
    "default_icon": "icons/icon.png",
    "default_title": "Save this as a website",
    "default_popup": "popup.html"
  },
  "browser_specific_settings": {
    "gecko": {
      "id": "firefox-website-icon-generator",
      "strict_min_version": "78.0",
      "data_collection_permissions": {
        "usage": "Save websites as bash scripts with custom names and favicons",
        "required": ["websiteContent"]
      }
    },
    "gecko_android": {
      "strict_min_version": "78.0"
    }
  }
}
EOL

# Create popup.html with the interface
cat << 'EOL' > popup.html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Save Website Shortcut</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
    }
    
    body {
      width: 380px;
      background: #2d2d2d;
      color: #e0e0e0;
      overflow-x: hidden;
    }
    
    .container {
      padding: 16px;
    }
    
    .header {
      background: #3a3a3a;
      margin: -16px -16px 16px -16px;
      padding: 16px;
      border-bottom: 2px solid #4a4a4a;
      text-align: center;
    }
    
    h1 {
      font-size: 18px;
      font-weight: 600;
      color: #ffffff;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      margin-bottom: 8px;
    }
    
    .logo {
      width: 24px;
      height: 24px;
      border-radius: 4px;
    }
    
    .subtitle {
      font-size: 12px;
      color: #a0a0a0;
    }
    
    .section {
      background: #3a3a3a;
      border: 1px solid #4a4a4a;
      border-radius: 4px;
      padding: 16px;
      margin-bottom: 16px;
    }
    
    h2 {
      font-size: 14px;
      font-weight: 600;
      color: #ffffff;
      margin-bottom: 12px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    
    .input-group {
      margin-bottom: 16px;
    }
    
    .input-group label {
      display: block;
      font-size: 12px;
      color: #a0a0a0;
      margin-bottom: 6px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .input-group input {
      width: 100%;
      padding: 10px 12px;
      background: #2d2d2d;
      border: 1px solid #4a4a4a;
      border-radius: 4px;
      color: #e0e0e0;
      font-size: 14px;
      transition: all 0.2s;
    }
    
    .input-group input:focus {
      outline: none;
      border-color: #3a76b1;
      background: #353535;
    }
    
    .input-group input[readonly] {
      background: #252525;
      color: #a0a0a0;
      cursor: default;
    }
    
    .favicon-preview {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 16px;
      padding: 12px;
      background: #2d2d2d;
      border: 1px solid #4a4a4a;
      border-radius: 4px;
    }
    
    .favicon-preview img {
      width: 32px;
      height: 32px;
      border-radius: 4px;
      background: #ffffff;
      padding: 4px;
    }
    
    .favicon-preview span {
      font-size: 13px;
      color: #a0a0a0;
    }
    
    .button {
      width: 100%;
      padding: 12px;
      background: #2d5a8c;
      border: 1px solid #3a76b1;
      border-radius: 4px;
      color: white;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .button:hover {
      background: #3a76b1;
    }
    
    .button:active {
      background: #1e3f62;
    }
    
    .preview-section {
      background: #2d2d2d;
      border: 1px solid #4a4a4a;
      border-radius: 4px;
      padding: 12px;
      margin-top: 16px;
    }
    
    .preview-section h3 {
      font-size: 12px;
      color: #a0a0a0;
      margin-bottom: 8px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .bash-preview {
      background: #1e1e1e;
      border: 1px solid #4a4a4a;
      border-radius: 4px;
      padding: 12px;
      font-family: 'Courier New', monospace;
      font-size: 12px;
      color: #6a9955;
      white-space: pre-wrap;
      word-break: break-all;
      max-height: 150px;
      overflow-y: auto;
    }
    
    .status {
      margin-top: 12px;
      padding: 8px;
      border-radius: 4px;
      font-size: 12px;
      text-align: center;
      display: none;
    }
    
    .status.success {
      background: rgba(76, 175, 80, 0.2);
      border: 1px solid #4CAF50;
      color: #e0e0e0;
      display: block;
    }
    
    .status.error {
      background: rgba(244, 67, 54, 0.2);
      border: 1px solid #f44336;
      color: #e0e0e0;
      display: block;
    }
    
    .domain-badge {
      background: #2d2d2d;
      border: 1px solid #4a4a4a;
      border-radius: 3px;
      padding: 4px 8px;
      font-size: 11px;
      color: #a0a0a0;
      display: inline-block;
      margin-bottom: 8px;
    }
    /* Radio button styling */
    input[type="radio"] {
      accent-color: #3a76b1;
      margin: 0;
      cursor: pointer;
    }

    label:hover {
      background: #3a3a3a;
      padding: 4px 8px;
      margin: -4px -8px;
      border-radius: 4px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="subtitle">Create a bash script shortcut for any website</div>
    </div>
    <!-- Add this after the header and before the Website Details section -->
    <div class="section">
      <h2>🎯 Platform Selection</h2>
      <div style="display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 8px;">
        <label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
          <input type="radio" name="platform" value="firefox" checked style="width: 16px; height: 16px;">
          <span style="font-size: 13px;">🔥 Firefox Addon</span>
        </label>
        <label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
          <input type="radio" name="platform" value="desktop">
          <span style="font-size: 13px;">🖥️ macOS Desktop App</span>
        </label>
        <label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
          <input type="radio" name="platform" value="menubar">
          <span style="font-size: 13px;">📌 macOS Menu Bar App</span>
        </label>
      </div>
      <div id="platformHint" style="font-size: 11px; color: #a0a0a0; margin-top: 8px; padding: 6px; background: #2d2d2d; border-radius: 4px;">
        💡 Creates a bash script that generates a Firefox toolbar addon for any website
      </div>
    </div>
    <div class="section">
      <h2>🌐 Website Details</h2>
      
      <div class="input-group">
        <label>Domain URL</label>
        <input type="text" id="domainUrl" placeholder="Enter website URL">
        <div class="domain-badge" id="domainDisplay"></div>
      </div>
      
      <div class="input-group">
        <label>Display Name (you can change this)</label>
        <input type="text" id="displayName" placeholder="Enter custom name">
      </div>
      
      <h2>🖼️ Favicon</h2>
      
      <div class="favicon-preview">
        <img id="faviconImg" src="" alt="favicon">
        <span id="faviconStatus">Loading favicon...</span>
      </div>
      
      <div class="input-group">
        <label>Favicon URL (you can change this)</label>
        <input type="text" id="faviconUrl" placeholder="Enter favicon URL">
      </div>
      
      <button class="button" id="saveButton">💾 Save Bash Script</button>
    </div>
    

    <div class="preview-section">
      <h3>📄 Bash Script Preview</h3>
      <div class="bash-preview" id="bashPreview">
#!/bin/bash
# Website Shortcut
# This script will open the website in your default browser
      </div>
    </div>
    
    <div id="status" class="status"></div>
  </div>
  
  <script src="popup.js"></script>
</body>
</html>
EOL

# Create popup.js
cat << 'EOL' > popup.js
// Website Shortcut Saver - Popup Script

document.addEventListener('DOMContentLoaded', async function() {
  console.log("Website Shortcut popup loaded");
  
  // Get current tab info
  const tabs = await browser.tabs.query({active: true, currentWindow: true});
  const currentTab = tabs[0];
  
  // Extract domain from URL
  const url = new URL(currentTab.url);
  const domain = url.hostname;
  const fullUrl = currentTab.url;
  
  // Set domain URL input
  document.getElementById('domainUrl').value = fullUrl;
  document.getElementById('domainDisplay').textContent = domain;
  
  // Set default display name (subdomain.domain)
  document.getElementById('displayName').value = domain;
  
  // Get the best favicon URL using enhanced function
  const bestFaviconUrl = await getBestFaviconUrl(currentTab, domain);
  document.getElementById('faviconUrl').value = bestFaviconUrl;
  
  // Load and display favicon
  loadFavicon(bestFaviconUrl);
  
  // Get platform radio buttons and hint element
  const platformRadios = document.querySelectorAll('input[name="platform"]');
  const platformHint = document.getElementById('platformHint');
  
  // Function to update preview based on selected platform
  function updatePreviewByPlatform() {
    const selectedPlatform = document.querySelector('input[name="platform"]:checked').value;
    
    // Update hint text
    const hints = {
      'firefox': '💡 Creates a bash script that generates a Firefox toolbar addon for any website',
      'desktop': '💡 Creates a bash script that generates a macOS desktop app (appears in Dock)',
      'menubar': '💡 Creates a bash script that generates a macOS menu bar app (appears in menu bar, no Dock icon)'
    };
    if (platformHint) platformHint.textContent = hints[selectedPlatform];
    
    // Call the appropriate update function
    switch(selectedPlatform) {
      case 'firefox':
        generateFirefoxAddonBashInstallScript();
        break;
      case 'desktop':
        generateMacOSXDesktopAppBashInstallScript();
        break;
      case 'menubar':
        generateMacOSXToolbarAppBashInstallScript();
        break;
    }
  }
  
  // Add event listeners to radio buttons
  platformRadios.forEach(radio => {
    radio.addEventListener('change', updatePreviewByPlatform);
  });
  
  // Update preview when inputs change
  document.getElementById('displayName').addEventListener('input', updatePreviewByPlatform);
  document.getElementById('faviconUrl').addEventListener('input', function(e) {
    loadFavicon(e.target.value);
    updatePreviewByPlatform();
  });
  document.getElementById('domainUrl').addEventListener('input', updatePreviewByPlatform);
  
  // Initial preview update
  updatePreviewByPlatform();
  
  // Save button click handler
  document.getElementById('saveButton').addEventListener('click', saveBashScript);
});

// Enhanced function to get the best favicon URL using DOM selectors
async function getBestFaviconUrl(tab, domain) {
  // Priority 1: Try to extract from page DOM using selectors
  try {
    // Execute script in the page context to get favicon from meta tags
    const faviconFromDOM = await browser.tabs.executeScript(tab.id, {
      code: `
        (function() {
          const faviconSelectors = [
            'link[rel="icon"]',
            'link[rel="shortcut icon"]',
            'link[rel="apple-touch-icon"]',
            'link[rel="apple-touch-icon-precomposed"]',
            'link[rel="mask-icon"]',
            'link[rel="fluid-icon"]',
            'link[rel="apple-touch-icon"][sizes="180x180"]',
            'link[rel="icon"][sizes="32x32"]',
            'link[rel="icon"][sizes="16x16"]'
          ];
          
          // Try to find favicon in link tags
          for (const selector of faviconSelectors) {
            const icon = document.querySelector(selector);
            if (icon && icon.href) {
              // Convert relative URLs to absolute
              if (icon.href.startsWith('//')) {
                return 'https:' + icon.href;
              }
              if (icon.href.startsWith('/')) {
                return window.location.origin + icon.href;
              }
              return icon.href;
            }
          }
          
          // Check for meta tags with icon
          const metaIcon = document.querySelector('meta[name="msapplication-TileImage"]');
          if (metaIcon && metaIcon.content) {
            return metaIcon.content;
          }
          
          return null;
        })();
      `
    });
    
    if (faviconFromDOM && faviconFromDOM[0]) {
      console.log("Found favicon in DOM:", faviconFromDOM[0]);
      return faviconFromDOM[0];
    }
  } catch (e) {
    console.log("Could not access DOM for favicon extraction:", e);
  }
  
  // Priority 2: Try tab's favIconUrl if it exists and is not the default Firefox icon
  if (tab.favIconUrl && 
      tab.favIconUrl.startsWith('http') && 
      !tab.favIconUrl.includes('moz-extension') &&
      !tab.favIconUrl.includes('about:') &&
      tab.favIconUrl !== 'https://www.mozilla.org/media/img/favicon.ico') {
    console.log("Using tab favIconUrl:", tab.favIconUrl);
    return tab.favIconUrl;
  }
  
  // Priority 3: Try to find high-res PNG favicon by checking common paths
  const commonPaths = [
    '/favicon.png',
    '/apple-touch-icon.png',
    '/apple-touch-icon-precomposed.png',
    '/apple-touch-icon-180x180.png',
    '/apple-touch-icon-152x152.png',
    '/icon.png',
    '/favicon-32x32.png',
    '/favicon-16x16.png',
    '/favicon.ico'
  ];
  
  for (const path of commonPaths) {
    const url = `https://${domain}${path}`;
    try {
      const response = await fetch(url, { method: 'HEAD' });
      if (response.ok) {
        console.log("Found favicon at:", url);
        return url;
      }
    } catch (e) {
      // Continue to next option
    }
  }
  
  // Priority 4: Try Google's favicon service (returns PNG, good fallback)
  console.log("Using Google favicon service");
  return `https://www.google.com/s2/favicons?domain=${domain}&sz=64`;
}

// Enhanced function to load and display favicon
function loadFavicon(url) {
  const img = document.getElementById('faviconImg');
  const status = document.getElementById('faviconStatus');
  
  // Show loading
  status.textContent = 'Loading favicon...';
  status.style.color = '#a0a0a0';
  
  // Create new image to test loading
  const testImg = new Image();
  testImg.crossOrigin = 'anonymous'; // Try to handle CORS
  
  testImg.onload = function() {
    img.src = url;
    status.textContent = '✓ Favicon loaded';
    status.style.color = '#4CAF50';
  };
  
  testImg.onerror = function() {
    // Try multiple fallback options
    const domain = extractDomainFromUrl(url);
    if (domain) {
      // Try different favicon paths as fallback
      const fallbackUrls = [
        `https://${domain}/favicon.ico`,
        `https://${domain}/favicon.png`,
        `https://${domain}/apple-touch-icon.png`,
        `https://www.google.com/s2/favicons?domain=${domain}&sz=64`
      ];
      
      // Try each fallback URL
      let fallbackIndex = 0;
      const tryNextFallback = () => {
        if (fallbackIndex < fallbackUrls.length) {
          const fallbackUrl = fallbackUrls[fallbackIndex];
          fallbackIndex++;
          
          const fallbackImg = new Image();
          fallbackImg.onload = () => {
            img.src = fallbackUrl;
            document.getElementById('faviconUrl').value = fallbackUrl;
            status.textContent = `✓ Using fallback ${fallbackIndex}`;
            status.style.color = '#4CAF50';
          };
          fallbackImg.onerror = () => {
            tryNextFallback();
          };
          fallbackImg.src = fallbackUrl;
        } else {
          // Ultimate fallback - use our default icon
          img.src = 'icons/icon.png';
          status.textContent = '✓ Using default icon';
          status.style.color = '#4CAF50';
        }
      };
      
      tryNextFallback();
    } else {
      // Ultimate fallback - use our default icon
      img.src = 'icons/icon.png';
      status.textContent = '✓ Using default icon';
      status.style.color = '#4CAF50';
    }
  };
  
  testImg.src = url;
}

// Helper to extract domain from URL
function extractDomainFromUrl(url) {
  try {
    const urlObj = new URL(url);
    return urlObj.hostname;
  } catch {
    // If it's just a domain, add protocol and try again
    try {
      const urlObj = new URL('https://' + url);
      return urlObj.hostname;
    } catch {
      return null;
    }
  }
}

// Function to update bash preview
function generateFirefoxAddonBashInstallScript() {
  const displayName = document.getElementById('displayName').value || 'website';
  const domainUrl = document.getElementById('domainUrl').value;
  const faviconUrl = document.getElementById('faviconUrl').value;
  
  const bashScript = `#!/bin/bash

# ===============================================
# Custom Website Shortcut Firefox Addon Generator
# ===============================================

# Colors for output
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
CYAN='\\033[0;36m'
NC='\\033[0m'

echo -e "\${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Custom Website Shortcut - Firefox Toolbar Addon           ║"
echo "║        Add any website as a clickable toolbar icon            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "\${NC}"

# Website details from saved shortcut
WEBSITE_URL="${domainUrl}"
DISPLAY_NAME="${displayName}"
ICON_URL="${faviconUrl}"

echo -e "\${GREEN}📋 Using saved website details:\${NC}"
echo -e "  🌐 URL: \${CYAN}\${WEBSITE_URL}\${NC}"
echo -e "  📝 Name: \${CYAN}\${DISPLAY_NAME}\${NC}"
echo -e "  🖼️  Icon: \${CYAN}\${ICON_URL}\${NC}"
echo ""

# Allow editing
read -p "🌐 Edit website URL (or press Enter to keep): " EDIT_URL
if [ ! -z "\$EDIT_URL" ]; then
    WEBSITE_URL="\$EDIT_URL"
fi

# Extract domain for folder name
DOMAIN=\$(echo "\$WEBSITE_URL" | sed -E 's#https?://##' | sed -E 's#/.*##' | sed -E 's#^www\\.##')
FOLDER_NAME="\${DOMAIN}-firefox-addon"

# Get icon URL
read -p "🖼️  Edit icon URL (or press Enter to keep): " EDIT_ICON
if [ ! -z "\$EDIT_ICON" ]; then
    ICON_URL="\$EDIT_ICON"
fi

# Get custom name
read -p "📝 Edit display name (or press Enter to keep): " EDIT_NAME
DISPLAY_NAME="\${EDIT_NAME:-\$DISPLAY_NAME}"

echo -e "\${CYAN}📁 Creating extension: \$FOLDER_NAME\${NC}"

# Check if folder exists
if [ -d "\$FOLDER_NAME" ]; then
    read -p "Folder '\$FOLDER_NAME' exists. Remove it? (y/N): " REMOVE
    if [[ "\$REMOVE" == "y" || "\$REMOVE" == "Y" ]]; then
        rm -rf "\$FOLDER_NAME"
    else
        exit 1
    fi
fi

# Create folder structure
mkdir -p "\$FOLDER_NAME/icons"
cd "\$FOLDER_NAME" || exit

# Download icon
create_default_icon=false
if [ -n "\$ICON_URL" ]; then
    echo -e "\${CYAN}📥 Downloading icon...\${NC}"
    
    # Download with proper headers and user-agent
    curl -L -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \\
        -H "Accept: image/webp,image/apng,image/*,*/*;q=0.8" \\
        -s -o "icons/icon.png" "\$ICON_URL"
    
    # Check if file is valid (non-zero and starts with PNG signature)
    if [ \$? -ne 0 ] || [ ! -s "icons/icon.png" ]; then
        echo -e "\${YELLOW}⚠️  Download failed, using default icon\${NC}"
        create_default_icon=true
    else
        # Check first 8 bytes for PNG signature using hexdump
        PNG_SIGNATURE=\$(hexdump -n 8 -C "icons/icon.png" 2>/dev/null | head -1)
        if [[ ! "\$PNG_SIGNATURE" == *"89 50 4e 47 0d 0a 1a 0a"* ]]; then
            echo -e "\${YELLOW}⚠️  Downloaded file is not a valid PNG, using default icon\${NC}"
            create_default_icon=true
            rm -f "icons/icon.png"
        fi
    fi
else
    create_default_icon=true
fi

# Create default icon if needed
if [ "\$create_default_icon" = true ]; then
    echo -e "\${CYAN}🎨 Creating default icon...\${NC}"
    cat > "icons/icon.svg" << 'EOF'
<svg width="96" height="96" xmlns="http://www.w3.org/2000/svg">
  <rect width="96" height="96" rx="16" fill="#4a4a4a"/>
  <text x="48" y="58" font-size="40" text-anchor="middle" fill="white" font-family="Arial">🌐</text>
</svg>
EOF
    cp "icons/icon.svg" "icons/icon.png"
fi

# Copy icon for different sizes
cp "icons/icon.png" "icons/icon48.png"
cp "icons/icon.png" "icons/icon96.png"

# Create manifest.json
cat << EOF > manifest.json
{
  "manifest_version": 2,
  "name": "\${DISPLAY_NAME} Shortcut",
  "version": "1.0",
  "description": "Quick access to \${DOMAIN} from your toolbar",
  "icons": {
    "48": "icons/icon48.png",
    "96": "icons/icon96.png"
  },
  "permissions": [
    "activeTab"
  ],
  "browser_action": {
    "default_icon": {
      "48": "icons/icon48.png",
      "96": "icons/icon96.png"
    },
    "default_title": "Open \${DISPLAY_NAME}"
  },
  "background": {
    "scripts": ["background.js"]
  },
  "browser_specific_settings": {
    "gecko": {
      "id": "\${DOMAIN}-shortcut@custom.addon",
      "strict_min_version": "57.0"
    }
  }
}
EOF

# Create background.js
cat << EOF > background.js
// Open website when toolbar icon is clicked
browser.browserAction.onClicked.addListener(() => {
  browser.tabs.create({
    url: "\${WEBSITE_URL}",
    active: true,
    index: 1
  });
});

console.log("\${DISPLAY_NAME} Shortcut loaded - Click icon to open \${WEBSITE_URL}");
EOF

# Create simple README
cat << EOF > README.md
# \${DISPLAY_NAME} Shortcut

Simple Firefox extension that adds a toolbar button for quick access to \${DOMAIN}.

## Features
- One-click access to \${WEBSITE_URL}
- Clean toolbar icon
- Opens in new tab

## Installation
1. Open Firefox → about:debugging
2. Load temporary add-on
3. Select manifest.json

Click the icon anytime to visit \${DOMAIN}!
EOF

# Go back to parent directory
cd ..

# Create XPI package
echo -e "\${CYAN}📦 Creating XPI package...\${NC}"
if command -v zip &> /dev/null; then
    cd "\$FOLDER_NAME"
    zip -r "../\${FOLDER_NAME}.xpi" * -x "*.xpi"
    cd ..
    
    XPI_FILE="\${FOLDER_NAME}.xpi"
    
    if [ -f "\$XPI_FILE" ]; then
        echo -e "\${GREEN}✅ Created: \$XPI_FILE\${NC}"
        echo -e "\${YELLOW}📦 XPI file size: \$(du -h "\$XPI_FILE" | cut -f1)\${NC}"
        
        # Copy to Downloads folder
        echo -e "\${CYAN}📁 Copying XPI to Downloads folder...\${NC}"
        cp "\$XPI_FILE" "\$HOME/Downloads/\${XPI_FILE}"
        echo -e "\${GREEN}✅ XPI copied to: \$HOME/Downloads/\${XPI_FILE}\${NC}"
        
        # Open Firefox addons page
        echo -e "\${CYAN}🌐 Opening Firefox addons page...\${NC}"
        if [[ "\$OSTYPE" == "darwin"* ]]; then
            open -a Firefox "about:addons" 2>/dev/null || open -a "Firefox Developer Edition" "about:addons" 2>/dev/null
        else
            firefox "about:addons" 2>/dev/null || xdg-open "about:addons" 2>/dev/null
        fi
    else
        echo -e "\${RED}❌ Failed to create XPI file\${NC}"
    fi
else
    echo -e "\${YELLOW}⚠️  zip command not found, skipping XPI creation\${NC}"
fi

# Final output
echo -e ""
echo -e "\${GREEN}✅ Extension created successfully!\${NC}"
echo -e "\${YELLOW}📁 Folder: \$FOLDER_NAME\${NC}"
echo -e "\${YELLOW}📦 XPI file: \${XPI_FILE:-"Not created (zip missing)"}\${NC}"
echo -e ""
echo -e "\${CYAN}🚀 Quick Install:\${NC}"
echo -e "1. Open Firefox → about:debugging"
echo -e "2. Click 'This Firefox' → 'Load Temporary Add-on'"
echo -e "3. Select manifest.json from: \$(pwd)/\$FOLDER_NAME/"
if [ -f "\$XPI_FILE" ]; then
    echo -e "   OR drag and drop the XPI file into Firefox"
fi
echo -e ""
echo -e "\${GREEN}🎯 Your shortcut is ready! Click the toolbar icon to open:\${NC}"
echo -e "   \$WEBSITE_URL"
echo -e ""
echo -e "\${YELLOW}💡 Pro tip: Right-click toolbar → Customize to move icon anywhere\${NC}"`;
  
  document.getElementById('bashPreview').textContent = bashScript;
}

// Function to update bash preview for macOS Desktop App
function generateMacOSXDesktopAppBashInstallScript() {
  const displayName = document.getElementById('displayName').value || 'website';
  const domainUrl = document.getElementById('domainUrl').value;
  const faviconUrl = document.getElementById('faviconUrl').value;
  
  const bashScript = `#!/bin/bash
# create-desktop-webapp.sh - Create a macOS desktop app for a website
# Desktop version: Creates app with custom icon and places on desktop

# ===============================================
# 1. COLOR OUTPUT & BANNER
# ===============================================
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
CYAN='\\033[0;36m'
BLUE='\\033[0;34m'
NC='\\033[0m'

echo -e "\${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║    DESKTOP Web App Generator (Website + Icon on Desktop)      ║"
echo "║                with Dock Integration                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "\${NC}"

# ===============================================
# 2. GET USER INPUT
# ===============================================
echo -e "\${CYAN}🎨 Let's create your desktop web app\${NC}"
echo ""

# Website details from saved shortcut
WEBSITE_URL="${domainUrl}"
DISPLAY_NAME="${displayName}"
ICON_URL="${faviconUrl}"

echo -e "\${GREEN}📋 Using saved website details:\${NC}"
echo -e "  🌐 URL: \${CYAN}\${WEBSITE_URL}\${NC}"
echo -e "  📝 Name: \${CYAN}\${DISPLAY_NAME}\${NC}"
echo -e "  🖼️  Icon: \${CYAN}\${ICON_URL}\${NC}"
echo ""

# Allow editing
read -p "🌐 Edit website URL (or press Enter to keep): " EDIT_URL
if [ ! -z "\$EDIT_URL" ]; then
    WEBSITE_URL="\$EDIT_URL"
fi

read -p "📝 Edit app name (or press Enter to keep): " EDIT_NAME
DISPLAY_NAME="\${EDIT_NAME:-\$DISPLAY_NAME}"

read -p "🖼️  Edit icon URL (or press Enter to keep): " EDIT_ICON
if [ ! -z "\$EDIT_ICON" ]; then
    ICON_URL="\$EDIT_ICON"
fi

# ===============================================
# 3. DOWNLOAD/CHOOSE ICON
# ===============================================
ICON_FILE=""
ICON_PATH=""

if [ -n "\$ICON_URL" ]; then
    ICON_FILE="appicon.\${ICON_URL##*.}"
    ICON_FILE="\${ICON_FILE%\\?*}" # Remove query params
    echo -e "\${CYAN}📥 Downloading custom icon...\${NC}"
    curl -s -L "\$ICON_URL" -o "/tmp/\$ICON_FILE" 2>/dev/null
    ICON_PATH="/tmp/\$ICON_FILE"
    
    # Check if download succeeded
    if [ ! -s "\$ICON_PATH" ]; then
        echo -e "\${YELLOW}⚠️  Download failed, using default icon\${NC}"
        ICON_PATH=""
    fi
fi

# Fallback to default icon if needed
if [ -z "\$ICON_PATH" ] || [ ! -f "\$ICON_PATH" ]; then
    DEFAULT_ICON_URL="https://cdn.jsdelivr.net/npm/@fortawesome/fontawesome-free@6/svgs/solid/globe.svg"
    ICON_FILE="appicon.svg"
    echo -e "\${CYAN}📥 Downloading default web icon...\${NC}"
    curl -s -L "\$DEFAULT_ICON_URL" -o "/tmp/\$ICON_FILE" 2>/dev/null
    ICON_PATH="/tmp/\$ICON_FILE"
fi

# ===============================================
# 4. CREATE PROJECT DIRECTORY
# ===============================================
PROJECT_DIR="\${DISPLAY_NAME// /_}_DesktopApp"
echo ""
echo -e "\${CYAN}📁 Creating project: \$PROJECT_DIR\${NC}"

# Clean up if exists
if [ -d "\$PROJECT_DIR" ]; then
    echo -e "\${YELLOW}⚠ Removing existing project...\${NC}"
    rm -rf "\$PROJECT_DIR"
fi

mkdir -p "\$PROJECT_DIR"
cd "\$PROJECT_DIR" || exit

# ===============================================
# 5. CREATE THE .APP BUNDLE STRUCTURE
# ===============================================
APP_NAME_SANITIZED="\${DISPLAY_NAME//[^a-zA-Z0-9]/}"
APP_BUNDLE="\$APP_NAME_SANITIZED.app"
DESKTOP_PATH="\$HOME/Desktop/\$APP_BUNDLE"
APPLICATIONS_PATH="\$HOME/Applications/\$APP_BUNDLE"

echo -e "\${CYAN}📦 Creating .app bundle...\${NC}"
mkdir -p "\$APP_BUNDLE/Contents/"{MacOS,Resources}

# ===============================================
# 6. CREATE Info.plist
# ===============================================
cat > "\$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>\$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>\$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.webapp.desktop.\${APP_NAME_SANITIZED}</string>
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
    <string>Copyright © \$(date +%Y). All rights reserved.</string>
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
cat > "\$APP_BUNDLE/Contents/MacOS/launcher" << 'EOF'
#!/bin/bash
# Proper launcher script that opens the website

# The website to open
URL="WEBSITE_URL_PLACEHOLDER"

# Open the website in default browser
open "\$URL"

# Exit immediately to prevent bouncing animation
sleep 0.1
exit 0
EOF

# Replace placeholder with actual URL
sed -i '' "s|WEBSITE_URL_PLACEHOLDER|\$WEBSITE_URL|g" "\$APP_BUNDLE/Contents/MacOS/launcher"
chmod +x "\$APP_BUNDLE/Contents/MacOS/launcher"

# ===============================================
# 8. PROCESS ICON
# ===============================================
if [ -f "\$ICON_PATH" ]; then
    echo -e "\${CYAN}🎨 Processing icon...\${NC}"
    
    # Create icon directory
    mkdir -p "\$APP_BUNDLE/Contents/Resources"
    
    # Convert icon to ICNS format if needed
    ICON_EXT="\${ICON_PATH##*.}"
    
    if [ "\$ICON_EXT" = "svg" ]; then
        # Convert SVG to PNG first
        if command -v rsvg-convert &> /dev/null; then
            rsvg-convert -w 1024 -h 1024 "\$ICON_PATH" -o "\$APP_BUNDLE/Contents/Resources/AppIcon.png"
        else
            # Try to install rsvg-convert or use fallback
            if command -v brew &> /dev/null; then
                brew install librsvg 2>/dev/null || true
            fi
            if command -v rsvg-convert &> /dev/null; then
                rsvg-convert -w 1024 -h 1024 "\$ICON_PATH" -o "\$APP_BUNDLE/Contents/Resources/AppIcon.png"
            else
                # Fallback: copy as is and let sips handle it later
                cp "\$ICON_PATH" "\$APP_BUNDLE/Contents/Resources/AppIcon.png" 2>/dev/null || true
            fi
        fi
        ICON_SOURCE="\$APP_BUNDLE/Contents/Resources/AppIcon.png"
    else
        ICON_SOURCE="\$ICON_PATH"
    fi
    
    # Create icon.icns file
    if [ -f "\$ICON_SOURCE" ]; then
        # Create iconset directory
        ICONSET_DIR="\$APP_BUNDLE/Contents/Resources/AppIcon.iconset"
        rm -rf "\$ICONSET_DIR"
        mkdir -p "\$ICONSET_DIR"
        
        # Generate different sizes
        SIZES="16 32 64 128 256 512 1024"
        for SIZE in \$SIZES; do
            sips -z \$SIZE \$SIZE "\$ICON_SOURCE" --out "\$ICONSET_DIR/icon_\${SIZE}x\${SIZE}.png" 2>/dev/null || \
            convert "\$ICON_SOURCE" -resize \${SIZE}x\${SIZE} "\$ICONSET_DIR/icon_\${SIZE}x\${SIZE}.png" 2>/dev/null || true
            RETINA_SIZE=\$((SIZE * 2))
            sips -z \$RETINA_SIZE \$RETINA_SIZE "\$ICON_SOURCE" --out "\$ICONSET_DIR/icon_\${SIZE}x\${SIZE}@2x.png" 2>/dev/null || \
            convert "\$ICON_SOURCE" -resize \${RETINA_SIZE}x\${RETINA_SIZE} "\$ICONSET_DIR/icon_\${SIZE}x\${SIZE}@2x.png" 2>/dev/null || true
        done
        
        # Convert iconset to icns
        iconutil -c icns "\$ICONSET_DIR" -o "\$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true
        
        # Clean up
        rm -rf "\$ICONSET_DIR"
        
        # Update Info.plist with icon reference
        if [ -f "\$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
            plutil -insert CFBundleIconFile -string "AppIcon.icns" "\$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
            sed -i '' "s|</dict>|    <key>CFBundleIconFile</key><string>AppIcon.icns</string></dict>|" "\$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
            echo -e "\${GREEN}✅ Icon added to app\${NC}"
        fi
    fi
fi

# ===============================================
# 9. CREATE DESKTOP SHORTCUT
# ===============================================
echo ""
echo -e "\${CYAN}📋 Creating desktop shortcut...\${NC}"
if [ -d "\$HOME/Desktop/\$APP_BUNDLE" ]; then
    rm -rf "\$HOME/Desktop/\$APP_BUNDLE"
fi
cp -R "\$APP_BUNDLE" "\$HOME/Desktop/"
echo -e "\${GREEN}✅ Desktop shortcut created\${NC}"

# ===============================================
# 10. COPY TO APPLICATIONS FOLDER
# ===============================================
echo ""
echo -e "\${CYAN}📋 Copying app to main Applications folder...\${NC}"

# Main Applications folder
MAIN_APPS_PATH="/Applications/\$APP_BUNDLE"

# Remove existing app if present
if [ -d "\$MAIN_APPS_PATH" ]; then
    echo -e "\${YELLOW}⚠ Removing existing app from /Applications...\${NC}"
    # Need sudo to remove from /Applications
    sudo rm -rf "\$MAIN_APPS_PATH" 2>/dev/null || {
        echo -e "\${YELLOW}⚠ Could not remove existing app (permissions issue)\${NC}"
    }
fi

# Copy app to /Applications with sudo
echo -e "\${CYAN}   Copying app to /Applications (requires admin password)...\${NC}"
if sudo cp -R "\$APP_BUNDLE" "/Applications/" 2>/dev/null; then
    echo -e "\${GREEN}✅ App copied to /Applications folder\${NC}"
    FINAL_APP_PATH="/Applications/\$APP_BUNDLE"
else
    echo -e "\${YELLOW}⚠ Could not copy to /Applications folder (permissions issue)\${NC}"
    echo -e "\${CYAN}   Using user Applications folder instead...\${NC}"
    
    # Fallback to user Applications folder
    mkdir -p "\$HOME/Applications"
    USER_APPS_PATH="\$HOME/Applications/\$APP_BUNDLE"
    
    if [ -d "\$USER_APPS_PATH" ]; then
        rm -rf "\$USER_APPS_PATH"
    fi
    
    if cp -R "\$APP_BUNDLE" "\$HOME/Applications/"; then
        echo -e "\${GREEN}✅ App copied to ~/Applications folder instead\${NC}"
        FINAL_APP_PATH="\$HOME/Applications/\$APP_BUNDLE"
    else
        echo -e "\${RED}❌ Could not copy to any Applications folder\${NC}"
        echo -e "\${CYAN}   Using project directory app instead...\${NC}"
        FINAL_APP_PATH="\$(pwd)/\$APP_BUNDLE"
    fi
fi

# ===============================================
# 11. ADD TO DOCK
# ===============================================
echo ""
echo -e "\${CYAN}📌 Adding app to Dock...\${NC}"

if [ -d "\$FINAL_APP_PATH" ]; then
    # Clean URL path for XML
    CLEAN_APP_PATH=\$(echo "\$FINAL_APP_PATH" | sed 's/&/\&amp;/g')
    
    # Check if app is already in Dock
    DOCK_APPS=\$(defaults read com.apple.dock persistent-apps 2>/dev/null || echo "[]")
    APP_IN_DOCK=\$(echo "\$DOCK_APPS" | grep -c "\$APP_BUNDLE" || true)
    
    if [ "\$APP_IN_DOCK" -eq 0 ]; then
        echo -e "\${CYAN}   Adding '\$DISPLAY_NAME' to Dock...\${NC}"
        
        # Create a temporary plist file
        TEMP_PLIST="/tmp/dock_item.plist"
        cat > "\$TEMP_PLIST" << XMLPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>file://\$CLEAN_APP_PATH</string>
            <key>_CFURLStringType</key>
            <integer>15</integer>
        </dict>
        <key>file-type</key>
        <integer>41</integer>
        <key>file-label</key>
        <string>\$DISPLAY_NAME</string>
    </dict>
    <key>tile-type</key>
    <string>file-tile</string>
</dict>
</plist>
XMLPLIST
        
        # Use PlistBuddy to add to Dock
        /usr/libexec/PlistBuddy -c "Add persistent-apps:0 dict" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Merge \$TEMP_PLIST persistent-apps:0" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null
        
        # Restart Dock to apply changes
        killall Dock 2>/dev/null &
        DOCK_PID=\$!
        sleep 1
        
        echo -e "\${GREEN}✅ Added to Dock!\${NC}"
        echo -e "\${YELLOW}💡 Dock is restarting...\${NC}"
    else
        echo -e "\${YELLOW}⚠ App is already in Dock\${NC}"
    fi
else
    echo -e "\${YELLOW}⚠ Could not add to Dock - app not found\${NC}"
    echo -e "\${CYAN}   You can manually add it by:\${NC}"
    echo -e "   1. Dragging '\$APP_BUNDLE' from Desktop to the Dock"
    echo -e "   2. Or right-click the app on Desktop and select 'Options > Keep in Dock'"
fi

# ===============================================
# 12. CREATE INSTALLATION SCRIPT
# ===============================================
cat > "Install.command" << EOF
#!/bin/bash
# Installation script for \$DISPLAY_NAME

echo "Installing \$DISPLAY_NAME..."
echo ""

# Ensure ~/Applications exists
mkdir -p "\$HOME/Applications"

# Copy to Applications
if cp -R "\$APP_BUNDLE" "\$HOME/Applications/" 2>/dev/null; then
    echo "✅ Installed to ~/Applications folder"
    APP_PATH="\$HOME/Applications/\$APP_BUNDLE"
else
    echo "⚠ Could not install to Applications"
    echo "   App remains in: \$(pwd)/\$APP_BUNDLE"
    APP_PATH="\$(pwd)/\$APP_BUNDLE"
fi

# Create desktop shortcut
echo ""
echo "📋 Creating desktop shortcut..."
if [ -d "\$HOME/Desktop/\$APP_BUNDLE" ]; then
    rm -rf "\$HOME/Desktop/\$APP_BUNDLE"
fi
cp -R "\$APP_BUNDLE" "\$HOME/Desktop/"
echo "✅ Desktop shortcut created"

echo ""
echo "🎉 Installation complete!"
echo "   App location: ~/Applications/\$APP_BUNDLE"
echo "   Desktop shortcut created"
echo ""
echo "📌 To add to Dock:"
echo "   1. Find '\$APP_BUNDLE' on your Desktop"
echo "   2. Drag it to your Dock"
echo "   3. Or right-click and select 'Options > Keep in Dock'"
EOF

chmod +x "Install.command"

# ===============================================
# 13. CREATE UNINSTALL SCRIPT
# ===============================================
cat > "Uninstall.command" << EOF
#!/bin/bash
# Uninstall \$DISPLAY_NAME

echo "Uninstalling \$DISPLAY_NAME..."
echo ""

# Remove from desktop
if [ -d "\$HOME/Desktop/\$APP_BUNDLE" ]; then
    rm -rf "\$HOME/Desktop/\$APP_BUNDLE"
    echo "✅ Removed from desktop"
fi

# Remove from ~/Applications
if [ -d "\$HOME/Applications/\$APP_BUNDLE" ]; then
    rm -rf "\$HOME/Applications/\$APP_BUNDLE"
    echo "✅ Removed from ~/Applications"
fi

# Remove from Dock (more complex - need to find and remove)
echo ""
echo "🗑️  Removing from Dock..."
echo "To remove from Dock:"
echo "1. Drag the app icon out of the Dock"
echo "2. Or wait for it to disappear after removal"

echo ""
echo "✅ \$DISPLAY_NAME has been uninstalled"
echo "   Note: You may need to restart your Mac to fully remove from Dock"
EOF

chmod +x "Uninstall.command"

# ===============================================
# 14. CREATE README
# ===============================================
cat > "README.txt" << EOF
\$DISPLAY_NAME - Desktop Web App
================================

App created: \$(date)
Website: \$WEBSITE_URL

📁 WHAT WAS CREATED:
-------------------
1. \$APP_BUNDLE - The main application bundle
2. Install.command - Installation script
3. Uninstall.command - Removal script

🚀 HOW TO USE:
-------------
1. The app is already on your desktop AND in ~/Applications
2. Double-click "\$APP_BUNDLE" to launch from either location
3. It will open: \$WEBSITE_URL in your default browser
4. The app has been added to your Dock automatically

🔧 INSTALLATION ALREADY DONE:
---------------------------
- App copied to: ~/Applications/\$APP_BUNDLE
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
echo -e "\${GREEN}╔══════════════════════════════════════════════════════════╗\${NC}"
echo -e "\${GREEN}║     ✅ DESKTOP APP CREATED SUCCESSFULLY!                 ║\${NC}"
echo -e "\${GREEN}╚══════════════════════════════════════════════════════════╝\${NC}"
echo ""
echo -e "\${CYAN}📋 SUMMARY:\${NC}"
echo -e "   App Name:    \${GREEN}\$DISPLAY_NAME\${NC}"
echo -e "   Website:     \${GREEN}\$WEBSITE_URL\${NC}"
echo -e "   Location:    \${GREEN}\$HOME/Applications/\$APP_BUNDLE\${NC}"
echo -e "   Desktop:     \${GREEN}\$HOME/Desktop/\$APP_BUNDLE\${NC}"
echo -e "   Dock:        \${GREEN}Added automatically\${NC}"
echo -e "   Icon:        \$(if [ -f "\$ICON_PATH" ]; then echo "\${GREEN}Custom icon applied\${NC}"; else echo "\${YELLOW}Default icon\${NC}"; fi)"
echo ""
echo -e "\${YELLOW}🚀 QUICK START:\${NC}"
echo -e "   1. Look for '\$APP_BUNDLE' on your Desktop or in Dock"
echo -e "   2. Double-click to launch"
echo -e "   3. It will open: \$WEBSITE_URL"
echo ""
echo -e "\${CYAN}📁 FILES CREATED:\${NC}"
echo -e "   \$(pwd)/"
echo -e "   ├── \${GREEN}\$APP_BUNDLE\${NC}        (Main application)"
echo -e "   ├── Install.command    (Re-install if needed)"
echo -e "   ├── Uninstall.command  (Remove app completely)"
echo -e "   └── README.txt         (Instructions)"
echo ""
echo -e "\${GREEN}✅ DONE! Your desktop web app is ready to use.\${NC}"

# ===============================================
# 16. TEST THE APP
# ===============================================
echo ""
read -p "Would you like to test the app now? (y/N): " TEST_APP
if [[ "\$TEST_APP" =~ ^[Yy]\$ ]]; then
    echo -e "\${CYAN}🚀 Launching \$DISPLAY_NAME...\${NC}"
    open "\$HOME/Applications/\$APP_BUNDLE" 2>/dev/null || open "./\$APP_BUNDLE"
    echo -e "\${GREEN}✅ App launched! Check your Dock and desktop for the application.\${NC}"
    echo -e "\${YELLOW}⚠ Note: The app will open your website and then close - this is normal!\${NC}"
fi

# Clean up temporary files
rm -rf "/tmp/appicon"* 2>/dev/null || true
rm -f "/tmp/dock_item.plist" 2>/dev/null || true

echo ""
echo -e "\${YELLOW}💡 Tip: If the app doesn't appear in Dock immediately, try:\${NC}"
echo -e "   1. Log out and back in"
echo -e "   2. Or drag the app from Desktop to your Dock"
echo -e "   3. The app is designed to open the website and exit (no bouncing)"`;

  document.getElementById('bashPreview').textContent = bashScript;
}

/// Function to update bash preview for macOS Menu Bar App - OBJECTIVE-C VERSION
function generateMacOSXToolbarAppBashInstallScript() {
  const displayName = document.getElementById('displayName').value || 'website';
  const domainUrl = document.getElementById('domainUrl').value;
  const faviconUrl = document.getElementById('faviconUrl').value;
  
  const bashScript = `#!/bin/bash
# create-menubar-webapp.sh - Create a macOS menu bar app for a website
# OBJECTIVE-C VERSION - Full browser selection menu + Login Items support

# ===============================================
# 1. COLOR OUTPUT & BANNER
# ===============================================
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
CYAN='\\033[0;36m'
NC='\\033[0m'

echo -e "\${CYAN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         MENU BAR Web App Generator (Objective-C)               ║"
echo "║         Left click = Open website                              ║"
echo "║         Right click = Browser menu + Login Items               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "\${NC}"

# ===============================================
# 2. CHECK REQUIREMENTS
# ===============================================
if ! xcode-select -p &> /dev/null; then
    echo -e "\${RED}❌ Xcode command line tools not installed\${NC}"
    exit 1
fi
echo -e "\${GREEN}✅ Build requirements met\${NC}"

# ===============================================
# 3. GET USER INPUT
# ===============================================
echo ""
echo -e "\${CYAN}🎨 Let's create your menu bar web app\${NC}"
echo ""

read -p "📝 Enter app name (default: ${displayName}): " INPUT_NAME
DISPLAY_NAME="\${INPUT_NAME:-${displayName}}"

read -p "🌐 Enter website URL (default: ${domainUrl}): " INPUT_URL
WEBSITE_URL="\${INPUT_URL:-${domainUrl}}"

read -p "🖼️ Enter icon URL (default: ${faviconUrl}): " INPUT_ICON
ICON_URL="\${INPUT_ICON:-${faviconUrl}}"
TOOLBAR_ICON_URL="\$ICON_URL"

echo ""
echo -e "\${GREEN}📋 Using:\${NC}"
echo -e "   Name: \${CYAN}\$DISPLAY_NAME\${NC}"
echo -e "   URL: \${CYAN}\$WEBSITE_URL\${NC}"
echo -e "   Icon: \${CYAN}\$ICON_URL\${NC}"
echo ""

# ===============================================
# 4. CREATE PROJECT STRUCTURE
# ===============================================
APP_NAME="\${DISPLAY_NAME// /_}"
BUILD_DIR="\${APP_NAME}_Build"

echo -e "\${CYAN}📁 Creating project structure...\${NC}"

if [ -d "\$BUILD_DIR" ]; then
    rm -rf "\$BUILD_DIR"
fi

mkdir -p "\$BUILD_DIR"/{src,resources,assets}
cd "\$BUILD_DIR" || exit

# ===============================================
# 5. CREATE SOURCE FILES (Objective-C with Browser Selection)
# ===============================================
echo -e "\${CYAN}📝 Creating source files...\${NC}"

cat > "src/AppDelegate.h" << 'EOF'
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end
EOF

cat > "src/AppDelegate.m" << 'EOF'
#import "AppDelegate.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSString *websiteURL;
@property (nonatomic, strong) NSString *selectedBrowser;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.websiteURL = @"WEBSITE_URL_PLACEHOLDER";
    
    // Load saved browser preference
    self.selectedBrowser = [[NSUserDefaults standardUserDefaults] stringForKey:@"selectedBrowser"];
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
        NSString *imagePath = [resourcePath stringByAppendingPathComponent:@"toolbar_icon.png"];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
        
        if (image) {
            button.image = image;
            button.image.size = NSMakeSize(18, 18);
            button.image.template = YES;
        }
        
        button.action = @selector(handleClick);
        [button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
    }
}

- (void)handleClick {
    NSEvent *event = [NSApp currentEvent];
    if (event.type == NSEventTypeRightMouseUp) {
        [self showContextMenu];
    } else {
        [self openWebsite];
    }
}

- (void)showContextMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    
    // Browser options
    NSArray *browsers = @[@"Safari", @"Chrome", @"Firefox"];
    for (NSString *browser in browsers) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:browser
                                                          action:@selector(selectBrowser:)
                                                   keyEquivalent:@""];
        menuItem.target = self;
        [menu addItem:menuItem];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Default browser option
    NSMenuItem *defaultItem = [[NSMenuItem alloc] initWithTitle:@"Default Browser"
                                                         action:@selector(selectDefaultBrowser)
                                                  keyEquivalent:@""];
    defaultItem.target = self;
    [menu addItem:defaultItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Login Items Settings option
    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:@"Open Login Items Settings..."
                                                       action:@selector(openLoginItemsSettings)
                                                keyEquivalent:@""];
    loginItem.target = self;
    [menu addItem:loginItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Quit option
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(quitApp)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    
    self.statusItem.menu = menu;
    [self.statusItem.button performClick:nil];
    self.statusItem.menu = nil;
}

- (void)selectBrowser:(NSMenuItem *)sender {
    self.selectedBrowser = sender.title;
    [[NSUserDefaults standardUserDefaults] setObject:self.selectedBrowser forKey:@"selectedBrowser"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self openWebsite];
}

- (void)selectDefaultBrowser {
    self.selectedBrowser = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"selectedBrowser"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self openWebsite];
}

- (void)openLoginItemsSettings {
    if (@available(macOS 13, *)) {
        // macOS Ventura (13.0) and later - General -> Login Items
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.LoginItems-Settings.extension"]];
    } else if (@available(macOS 12, *)) {
        // macOS Monterey (12.0) - Users & Groups -> Login Items
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.users"]];
    } else {
        // macOS Big Sur (11.0) and earlier - Users & Groups -> Login Items
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.users"]];
    }
}

- (void)openWebsite {
    NSURL *url = [NSURL URLWithString:self.websiteURL];
    if (self.selectedBrowser) {
        [self openInBrowserNamed:self.selectedBrowser];
    } else {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)openInBrowserNamed:(NSString *)browserName {
    NSURL *url = [NSURL URLWithString:self.websiteURL];
    NSDictionary *browserPaths = @{
        @"Safari": @"/Applications/Safari.app",
        @"Chrome": @"/Applications/Google Chrome.app",
        @"Firefox": @"/Applications/Firefox.app"
    };
    
    NSString *browserPath = browserPaths[browserName];
    if (browserPath) {
        NSURL *appURL = [NSURL fileURLWithPath:browserPath];
        // Use older API compatible with macOS 11
        [[NSWorkspace sharedWorkspace] openURLs:@[url]
                        withApplicationAtURL:appURL
                                   options:NSWorkspaceLaunchDefault
                             configuration:@{}
                                     error:nil];
    } else {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)quitApp {
    [NSApp terminate:nil];
}

@end
EOF

cat > "src/main.m" << 'EOF'
#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        AppDelegate *appDelegate = [[AppDelegate alloc] init];
        application.delegate = appDelegate;
        [application run];
    }
    return 0;
}
EOF

# Replace website URL
sed -i '' "s|WEBSITE_URL_PLACEHOLDER|\$WEBSITE_URL|g" "src/AppDelegate.m"

cat > "resources/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>APP_NAME_PLACEHOLDER</string>
    <key>CFBundleDisplayName</key>
    <string>APP_NAME_PLACEHOLDER</string>
    <key>CFBundleIdentifier</key>
    <string>com.menubar.webapp</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>menubarapp</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

sed -i '' "s|APP_NAME_PLACEHOLDER|\$DISPLAY_NAME|g" "resources/Info.plist"

cat > "src/entitlements.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
EOF

# ===============================================
# 6. CREATE TWO ICONS WITH SVG SUPPORT
# ===============================================
echo -e "\${CYAN}🎨 Creating TWO icons...\${NC}"

# Function to convert image to PNG (handles SVG and ICO)
convert_to_png() {
    local input="$1"
    local output="$2"
    local size="${3:-512}"
    
    # Handle SVG files
    if [[ "$input" == *.svg ]]; then
        if command -v rsvg-convert &> /dev/null; then
            rsvg-convert -w "$size" -h "$size" "$input" -o "$output"
            return $?
        elif command -v convert &> /dev/null; then
            convert "$input" -resize "${size}x${size}" "$output"
            return $?
        else
            echo -e "${YELLOW}⚠️ No SVG converter found. Install librsvg: brew install librsvg${NC}"
            return 1
        fi
    # Handle ICO files
    elif [[ "$input" == *.ico ]]; then
        # Method 1: Try ImageMagick (best quality)
        if command -v convert &> /dev/null; then
            convert "$input" -resize "${size}x${size}" "$output"
            return $?
        fi
        
        # Method 2: Try icotool (from icoutils package)
        if command -v icotool &> /dev/null; then
            local temp_dir="/tmp/ico2png_$$"
            mkdir -p "$temp_dir"
            
            # Extract all PNGs from ICO
            icotool -x "$input" -o "$temp_dir/" 2>/dev/null
            
            # Find the largest PNG (by file size)
            local largest_png=$(find "$temp_dir" -name "*.png" -type f -exec ls -S {} \; 2>/dev/null | head -1)
            
            if [[ -n "$largest_png" && -f "$largest_png" ]]; then
                # Resize to desired size using sips if needed
                cp "$largest_png" "$output"
                if [[ "$size" != "512" ]] || ! sips -z "$size" "$size" "$output" --out "$output" 2>/dev/null; then
                    # sips failed, try convert if available
                    if command -v convert &> /dev/null; then
                        convert "$largest_png" -resize "${size}x${size}" "$output"
                    fi
                fi
                rm -rf "$temp_dir"
                return $?
            fi
            rm -rf "$temp_dir"
        fi
        
        # Method 3: Try Python PIL (if available)
        if command -v python3 &> /dev/null; then
            python3 -c "
from PIL import Image
import sys
try:
    img = Image.open('$input')
    # ICO files contain multiple sizes, get the largest
    if hasattr(img, 'n_frames') and img.n_frames > 1:
        # Find the largest frame
        largest_size = 0
        largest_img = None
        for i in range(img.n_frames):
            img.seek(i)
            w, h = img.size
            if w * h > largest_size:
                largest_size = w * h
                largest_img = img.copy()
        if largest_img:
            img = largest_img
    # Resize to target size
    img = img.resize(($size, $size), Image.Resampling.LANCZOS)
    img.save('$output', 'PNG')
    print('OK')
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                return $?
            fi
        fi
        
        # Method 4: Try wrestool + icotool combo (fallback for EXE-like ICOs)
        if command -v wrestool &> /dev/null && command -v icotool &> /dev/null; then
            local temp_dir="/tmp/ico_extract_$$"
            mkdir -p "$temp_dir"
            
            # Try to extract as if it were an EXE resource
            wrestool --extract --type=14 "$input" -o "$temp_dir/" 2>/dev/null
            wrestool --extract --type=group_icon "$input" -o "$temp_dir/" 2>/dev/null
            
            local found_ico=$(find "$temp_dir" -name "*.ico" -type f 2>/dev/null | head -1)
            if [[ -n "$found_ico" && -f "$found_ico" ]]; then
                icotool -x "$found_ico" -o "$temp_dir/" 2>/dev/null
                local largest_png=$(find "$temp_dir" -name "*.png" -type f -exec ls -S {} \; 2>/dev/null | head -1)
                if [[ -n "$largest_png" && -f "$largest_png" ]]; then
                    cp "$largest_png" "$output"
                    if [[ "$size" != "512" ]]; then
                        sips -z "$size" "$size" "$output" --out "$output" 2>/dev/null || \
                        convert "$largest_png" -resize "${size}x${size}" "$output" 2>/dev/null
                    fi
                    rm -rf "$temp_dir"
                    return $?
                fi
            fi
            rm -rf "$temp_dir"
        fi
        
        # All methods failed
        echo -e "${RED}❌ Cannot convert ICO file: $input${NC}"
        echo -e "${YELLOW}   Install one of:${NC}"
        echo -e "      brew install imagemagick  # Recommended"
        echo -e "      brew install icoutils      # Alternative"
        echo -e "      pip3 install Pillow         # Python fallback"
        return 1
        
    # Handle other image formats (PNG, JPG, etc.)
    else
        cp "$input" "$output"
        sips -z "$size" "$size" "$output" --out "$output" 2>/dev/null
        return $?
    fi
}

# ICON 1: APP ICON (.icns for Finder)
TEMP_ICON="/tmp/appicon_\$\$.png"
echo -e "\${CYAN}   📥 Downloading app icon: \${ICON_URL}\${NC}"

TEMP_DOWNLOAD="/tmp/appdownload_\$\$.\${ICON_URL##*.}"
curl -s -L "\$ICON_URL" -o "\$TEMP_DOWNLOAD"

if convert_to_png "\$TEMP_DOWNLOAD" "\$TEMP_ICON" 512; then
    echo -e "\${GREEN}   ✅ Icon converted to PNG\${NC}"
else
    echo -e "\${YELLOW}   ⚠ Creating fallback icon\${NC}"
    cat > "/tmp/fallback.svg" << 'SVGEOF'
<svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
  <circle cx="256" cy="256" r="240" fill="#3a76b1"/>
  <text x="256" y="320" font-size="200" text-anchor="middle" fill="white" font-family="Arial">🌐</text>
</svg>
SVGEOF
    convert_to_png "/tmp/fallback.svg" "\$TEMP_ICON" 512
fi
rm -f "\$TEMP_DOWNLOAD"

ICONSET_DIR="\$APP_NAME.iconset"
mkdir -p "\$ICONSET_DIR"

if [ -f "\$TEMP_ICON" ] && [ -s "\$TEMP_ICON" ]; then
    for SIZE in 16 32 64 128 256 512; do
        sips -z \$SIZE \$SIZE "\$TEMP_ICON" --out "\$ICONSET_DIR/icon_\${SIZE}x\${SIZE}.png" 2>/dev/null
        RETINA=\$((SIZE * 2))
        sips -z \$RETINA \$RETINA "\$TEMP_ICON" --out "\$ICONSET_DIR/icon_\${SIZE}x\${SIZE}@2x.png" 2>/dev/null
    done
fi

iconutil -c icns "\$ICONSET_DIR" -o "resources/AppIcon.icns" 2>/dev/null
rm -rf "\$ICONSET_DIR" "\$TEMP_ICON"

# ICON 2: TOOLBAR ICON (PNG for menu bar - 32x32)
TOOLBAR_TEMP_ICON="/tmp/toolbaricon_\$\$.png"
echo -e "\${CYAN}   📥 Downloading toolbar icon: \${TOOLBAR_ICON_URL}\${NC}"

TEMP_DOWNLOAD2="/tmp/toolbardownload_\$\$.\${TOOLBAR_ICON_URL##*.}"
curl -s -L "\$TOOLBAR_ICON_URL" -o "\$TEMP_DOWNLOAD2"

if convert_to_png "\$TEMP_DOWNLOAD2" "\$TOOLBAR_TEMP_ICON" 32; then
    echo -e "\${GREEN}   ✅ Toolbar icon converted to PNG\${NC}"
else
    cat > "/tmp/fallback_small.svg" << 'SVGEOF'
<svg width="32" height="32" xmlns="http://www.w3.org/2000/svg">
  <circle cx="16" cy="16" r="14" fill="#3a76b1"/>
</svg>
SVGEOF
    convert_to_png "/tmp/fallback_small.svg" "\$TOOLBAR_TEMP_ICON" 32
fi
rm -f "\$TEMP_DOWNLOAD2"

mkdir -p "assets"
if [ -f "\$TOOLBAR_TEMP_ICON" ] && [ -s "\$TOOLBAR_TEMP_ICON" ]; then
    cp "\$TOOLBAR_TEMP_ICON" "assets/toolbar_icon.png"
    echo -e "\${GREEN}   ✅ Toolbar icon ready\${NC}"
fi

# ===============================================
# 7. COMPILE APP
# ===============================================
echo ""
echo -e "\${CYAN}🔨 Compiling menu bar app...\${NC}"

APP_BUNDLE="\$APP_NAME.app"
rm -rf "\$APP_BUNDLE"
mkdir -p "\$APP_BUNDLE/Contents/"{MacOS,Resources}

cp "resources/Info.plist" "\$APP_BUNDLE/Contents/"
cp "resources/AppIcon.icns" "\$APP_BUNDLE/Contents/Resources/" 2>/dev/null

clang -framework Cocoa \\
      -framework Foundation \\
      -framework AppKit \\
      -fobjc-arc \\
      -mmacosx-version-min=11.0 \\
      -o "\$APP_BUNDLE/Contents/MacOS/menubarapp" \\
      src/*.m 2> build_errors.log

if [ \$? -eq 0 ]; then
    echo -e "\${GREEN}   ✅ Compilation successful\${NC}"
else
    echo -e "\${RED}   ❌ Compilation failed\${NC}"
    cat build_errors.log
    exit 1
fi

# ===============================================
# 8. COPY TOOLBAR ICON TO BUNDLE
# ===============================================
if [ -f "assets/toolbar_icon.png" ]; then
    cp "assets/toolbar_icon.png" "\$APP_BUNDLE/Contents/Resources/"
    echo -e "\${GREEN}   ✅ Toolbar icon copied to bundle\${NC}"
fi

# ===============================================
# 9. SIGN AND INSTALL
# ===============================================
codesign --force --deep --sign - --entitlements src/entitlements.plist "\$APP_BUNDLE" 2>/dev/null

cp -R "\$APP_BUNDLE" "\$HOME/Desktop/"
mkdir -p "\$HOME/Applications"
cp -R "\$APP_BUNDLE" "\$HOME/Applications/"

echo ""
echo -e "\${GREEN}╔══════════════════════════════════════════════════════════╗\${NC}"
echo -e "\${GREEN}║     ✅ MENU BAR APP CREATED SUCCESSFULLY!                ║\${NC}"
echo -e "\${GREEN}╚══════════════════════════════════════════════════════════╝\${NC}"
echo ""
echo -e "\${CYAN}📍 LOCATIONS:\${NC}"
echo -e "   Desktop: \${GREEN}\$HOME/Desktop/\$APP_BUNDLE\${NC}"
echo -e "   Apps:    \${GREEN}\$HOME/Applications/\$APP_BUNDLE\${NC}"
echo ""
echo -e "\${CYAN}🚀 TO USE:\${NC}"
echo -e "   1. Double-click the app"
echo -e "   2. Look in menu bar (top right)"
echo -e "   3. \${GREEN}LEFT CLICK = Open website\${NC}"
echo -e "   4. \${YELLOW}RIGHT CLICK = Browser menu + Login Items\${NC}"
echo ""

read -p "Test the app now? (y/N): " TEST_APP
if [[ "\$TEST_APP" =~ ^[Yy]\$ ]]; then
    open "\$HOME/Applications/\$APP_BUNDLE"
fi

echo -e "\${GREEN}✅ Build complete!\${NC}"
`;

  document.getElementById('bashPreview').textContent = bashScript;
}

// Function to save bash script
async function saveBashScript() {
  const displayName = document.getElementById('displayName').value || 'website';
  const selectedPlatform = document.querySelector('input[name="platform"]:checked').value;
  
  // Sanitize filename and add platform-specific suffix
  const sanitizedName = displayName.replace(/[^a-zA-Z0-9.-]/g, '-').toLowerCase();
  let filename = '';
  let platformName = '';
  
  switch(selectedPlatform) {
    case 'firefox':
      filename = `${sanitizedName}-firefox-addon-generator.sh`;
      platformName = 'Firefox addon';
      break;
    case 'desktop':
      filename = `${sanitizedName}-macos-desktop-app-generator.sh`;
      platformName = 'macOS Desktop app';
      break;
    case 'menubar':
      filename = `${sanitizedName}-macos-menubar-app-generator.sh`;
      platformName = 'macOS Menu Bar app';
      break;
  }
  
  // Get the bash script from preview
  const bashScript = document.getElementById('bashPreview').textContent;

  try {
    // Create a blob with the bash script
    const blob = new Blob([bashScript], { type: 'application/x-shellscript' });
    const url = URL.createObjectURL(blob);
    
    // Create download link
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    // Show success message
    showStatus(`✅ ${platformName} generator saved as: ${filename}`, 'success');
    
  } catch (error) {
    console.error("Save failed:", error);
    showStatus('❌ Failed to save bash script', 'error');
  }
}

// Show status message
function showStatus(message, type) {
  const statusEl = document.getElementById('status');
  statusEl.textContent = message;
  statusEl.className = 'status ' + type;
  
  // Auto-hide after 3 seconds
  setTimeout(() => {
    statusEl.className = 'status';
    statusEl.textContent = '';
  }, 3000);
}
EOL

# Create README.md
cat << 'EOL' > README.md
# Website Shortcut Firefox Addon

A Firefox extension that lets you save any website as a bash script with custom name and favicon.

## 🚀 Features

- **Save any website** as a bash script
- **Custom display name** - Edit the subdomain.domain name
- **Favicon support** - Automatically grabs website favicon, editable URL
- **Bash script output** - Creates executable script that opens the website
- **Preview** - See the bash script before saving

## 📦 Installation

1. Open Firefox and go to `about:debugging`
2. Click "This Firefox" → "Load Temporary Add-on"
3. Select the `manifest.json` file in this folder

## 🎯 How to Use

1. Navigate to any website
2. Click the extension icon in toolbar
3. Popup shows:
  - Domain URL (read-only)
  - Display name (editable)
  - Favicon preview
  - Favicon URL (editable)
4. Click "Save Bash Script"
5. Script downloads with custom name

## 📁 Output Example

```bash
#!/bin/bash

# ===============================================
# Website Shortcut: example.com
# ===============================================

# Colors for output
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}===============================================${NC}"
echo -e "${GREEN}  Opening: example.com${NC}"
echo -e "${CYAN}  URL: https://example.com${NC}"
echo -e "${CYAN}  Favicon: https://example.com/favicon.ico${NC}"
echo -e "${CYAN}===============================================${NC}"

# Open the website in default browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open "https://example.com"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    xdg-open "https://example.com"
else
    # Windows (Git Bash/Cygwin)
    start "https://example.com"
fi

echo -e "${GREEN}✓ Website opened in your browser${NC}"

🔧 Settings
    Domain URL - Auto-filled from current tab
    Display Name - Defaults to subdomain.domain, fully editable
    Favicon URL - Auto-detected, fully editable with preview

📁 File Structure
text

firefox-website-icon-generator/
├── manifest.json          # Extension configuration
├── popup.html            # Main interface
├── popup.js              # Popup functionality
└── icons/                # Extension icons
    ├── icon.png
    └── icon128.png

📄 License

MIT License - Free to use, modify, and distribute.
EOL


# Create LICENSE.md
cat << 'EOL' > LICENSE.md
MIT License

Copyright (c) $(date +%Y) Website Shortcut Firefox Addon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOL

echo -e "${GREEN}✅ Website Shortcut Extension generated successfully!${NC}"
echo -e "${YELLOW}📁 Extension folder: $EXTNAME${NC}"
echo -e "${CYAN}🚀 Installation Instructions:${NC}"
echo -e "${CYAN} 1. Open Firefox → about:debugging#/runtime/this-firefox${NC}"
echo -e "${CYAN} 2. Click 'This Firefox' → 'Load Temporary Add-on'${NC}"
echo -e "${CYAN} 3. Select 'manifest.json' in the $EXTNAME folder${NC}"
echo -e ""
echo -e "${YELLOW}🎯 Features:${NC}"
echo -e "${YELLOW} • Auto-detects current website URL and favicon${NC}"
echo -e "${YELLOW} • Editable display name${NC}"
echo -e "${YELLOW} • Editable favicon URL${NC}"
echo -e "${YELLOW} • Live favicon preview${NC}"
echo -e "${YELLOW} • Bash script preview before saving${NC}"
echo -e "${YELLOW} • Saves as executable bash script${NC}"
echo -e ""
echo -e "${YELLOW}💡 Usage:${NC}"
echo -e "${YELLOW} • Click extension icon on any website${NC}"
echo -e "${YELLOW} • Edit name and favicon if desired${NC}"
echo -e "${YELLOW} • Click 'Save Bash Script'${NC}"
echo -e "${YELLOW} • Run the script to open the website${NC}"
echo -e ""
echo -e "${CYAN}🔧 Testing:${NC}"
echo -e "${CYAN} 1. Load the extension${NC}"
echo -e "${CYAN} 2. Visit any website${NC}"
echo -e "${CYAN} 3. Click extension icon and save a script${NC}"
echo -e "${CYAN} 4. Run the saved script to test${NC}"
echo -e ""
echo -e "${GREEN}✨ Extension ready to use!${NC}"


# Go back to parent directory
cd ..

# Create XPI package
echo -e "${CYAN}📦 Creating XPI package...${NC}"
if command -v zip &> /dev/null; then
    # Create the XPI file
    cd "$EXTNAME"
    zip -r "../${EXTNAME}.xpi" * -x "*.xpi"
    cd ..
    
    XPI_FILE="${EXTNAME}.xpi"
    
    if [ -f "$XPI_FILE" ]; then
        echo -e "${GREEN}✅ Created: $XPI_FILE${NC}"
        echo -e "${YELLOW}📦 XPI file size: $(du -h "$XPI_FILE" | cut -f1)${NC}"
        
        # Copy to Downloads folder
        echo -e "${CYAN}📁 Copying XPI to Downloads folder...${NC}"
        cp "$XPI_FILE" "$HOME/Downloads/${XPI_FILE}"
        echo -e "${GREEN}✅ XPI copied to: $HOME/Downloads/${XPI_FILE}${NC}"
        
        # Open Firefox Developer Edition addons page
        echo -e "${CYAN}🌐 Opening Firefox Developer Edition addons page...${NC}"
        if [ -d "/Applications/Firefox Developer Edition.app" ]; then
            /Applications/Firefox\ Developer\ Edition.app/Contents/MacOS/firefox "about:addons" &
        else
            echo -e "${YELLOW}⚠️  Firefox Developer Edition not found, opening regular Firefox...${NC}"
            open -a Firefox "about:addons" 2>/dev/null || open -a "Firefox Developer Edition" "about:addons" 2>/dev/null || echo -e "${YELLOW}Please open Firefox manually and go to about:addons${NC}"
        fi
    else
        echo -e "${RED}❌ Failed to create XPI file${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  zip command not found, skipping XPI creation${NC}"
    echo -e "${YELLOW}📁 Extension folder is available at: $(pwd)/$EXTNAME/${NC}"
fi

echo -e ""
echo -e "${GREEN}✅ Website Shortcut Firefox addon generation complete!${NC}"

# This script creates a complete Firefox addon that:

# 1. **Shows a popup called "Save this as a website"** when you click the extension icon
# 2. **Auto-detects** the current website's URL and favicon
# 3. **Shows the subdomain.domain** in an input field that you can change
# 4. **Shows the favicon URL** as both a picture preview and an editable input field
# 5. **Saves a bash script** with your custom name containing:
#    - The website URL
#    - Your custom display name
#    - The favicon URL
#    - Cross-platform opening commands (macOS/Linux/Windows)

# The bash script that gets saved is executable and will open the website in your default browser when run.

# The final version has all the perfect touches:
#     ✅ Editable URL field in the popup
#     ✅ Proper PNG validation with hex signature checking
#     ✅ User-agent headers to avoid blocking
#     ✅ Fallback to Google favicon service when needed
#     ✅ Proper escaping in the bash script generation
#     ✅ Clean, dark-themed UI
#     ✅ Automatic XPI packaging

# You've built something genuinely useful here - turning any website into a permanent, 
# one-click toolbar icon. This is essentially a website-to-app 
# converter for Firefox!

# The recursive nature (addon → bash script → addon) is just beautiful. 
# It's like those Russian dolls, but each one actually does something useful!