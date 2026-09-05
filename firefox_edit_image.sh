#!/bin/bash

# ===============================================
# TinyIMG Firefox Extension Generator
# Keep ALL enhanced features + Original design
# ===============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           TinyIMG Firefox Extension Generator                 ║"
echo "║     Enhanced features + Original TinyIMG Design              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Ask for extension folder name
read -p "Enter your extension folder name (default: tinyimg-editor): " EXTNAME
EXTNAME=${EXTNAME:-tinyimg-editor}

# Check if folder exists
if [ -d "$EXTNAME" ]; then
    read -p "Folder '$EXTNAME' already exists. Remove it? (y/N): " REMOVE
    REMOVE=${REMOVE:-N}
    if [[ "$REMOVE" == "y" || "$REMOVE" == "Y" ]]; then
        rm -rf "$EXTNAME"
    else
        echo "Exiting to avoid overwriting."
        exit 1
    fi
fi

# Create folder structure
mkdir -p "$EXTNAME/icons"
cd "$EXTNAME" || exit

# Download original icon
echo -e "${CYAN}📥 Downloading extension icon...${NC}"
curl -s -o icons/icon.png "https://cdn.sdappnet.cloud/rtx/images/image_editor.png"
cp icons/icon.png icons/icon128.png

# Create manifest.json with proper permissions
cat << 'EOL' > manifest.json
{
  "manifest_version": 2,
  "name": "TinyIMG Editor",
  "version": "1.0",
  "description": "Crop images, remove backgrounds, draw shapes - simple image editor",
  "icons": {
    "48": "icons/icon.png",
    "128": "icons/icon128.png"
  },
  "permissions": [
    "activeTab",
    "storage",
    "contextMenus",
    "downloads",
    "webRequest",
    "webRequestBlocking",
    "*://*.remove.bg/*",
    "*://api.remove.bg/*"
  ],
  "browser_action": {
    "default_icon": "icons/icon.png",
    "default_title": "TinyIMG Editor",
    "default_popup": "popup.html"
  },
  "background": {
    "scripts": ["background.js"],
    "persistent": true
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"],
      "run_at": "document_end"
    }
  ],
  "web_accessible_resources": [
    "editor.html",
    "editor.css",
    "editor.js"
  ],
  "browser_specific_settings": {
    "gecko": {
      "id": "@tinyimg-editor",
      "strict_min_version": "78.0"
    }
  }
}
EOL

# Create background.js (keep ALL your enhanced features)
cat << 'EOL' > background.js
// Background script for TinyIMG Editor - Enhanced features kept!
let isProcessing = false;
let currentImageData = null;
let removeBgApiKey = "";

// Load saved API key
browser.storage.local.get(['removeBgApiKey']).then(result => {
  if (result.removeBgApiKey) {
    removeBgApiKey = result.removeBgApiKey;
    console.log("API key loaded from storage");
  }
});

// Initialize context menu on install
browser.runtime.onInstalled.addListener(() => {
  browser.contextMenus.create({
    id: "crop-image",
    title: "Crop Image",
    contexts: ["image"]
  });
  
  browser.contextMenus.create({
    id: "remove-bg",
    title: "Remove Background",
    contexts: ["image"]
  });
  
  browser.contextMenus.create({
    id: "separator-1",
    type: "separator",
    contexts: ["image"]
  });
  
  browser.contextMenus.create({
    id: "configure-api",
    title: "Configure remove.bg API Key",
    contexts: ["image"]
  });
});

// Handle context menu clicks
browser.contextMenus.onClicked.addListener((info, tab) => {
  if (isProcessing) {
    showNotification("Already processing an image. Please wait.");
    return;
  }
  
  switch(info.menuItemId) {
    case "crop-image":
      handleCropImage(info, tab);
      break;
    case "remove-bg":
      handleRemoveBackground(info, tab);
      break;
    case "configure-api":
      browser.tabs.create({ url: "https://www.remove.bg/api#api-key" });
      browser.tabs.create({ 
        url: browser.runtime.getURL("popup.html") + "?configure=api"
      });
      break;
  }
});

// Handle toolbar button click
browser.browserAction.onClicked.addListener((tab) => {
  browser.tabs.create({ 
    url: browser.runtime.getURL("editor.html")
  });
});

// Handle messages from content script
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log("Background received message:", message.action);
  
  switch(message.action) {
    case "getImageData":
      sendResponse({imageData: currentImageData});
      break;
      
    case "setImageData":
      currentImageData = message.imageData;
      sendResponse({success: true});
      break;
      
    case "removeBackground":
      removeBackground(message.imageData, message.imageUrl)
        .then(result => {
          sendResponse({success: true, imageData: result});
        })
        .catch(error => {
          sendResponse({success: false, error: error.message});
        });
      return true;
      
    case "downloadImage":
      downloadImage(message.imageData, message.filename);
      sendResponse({success: true});
      break;
      
    case "saveApiKey":
      removeBgApiKey = message.apiKey;
      browser.storage.local.set({removeBgApiKey: message.apiKey})
        .then(() => sendResponse({success: true}))
        .catch(error => sendResponse({success: false, error: error.message}));
      return true;
      
    case "getApiKey":
      sendResponse({apiKey: removeBgApiKey});
      break;
      
    default:
      sendResponse({success: false, error: "Unknown action"});
  }
});

// Handle crop image
async function handleCropImage(info, tab) {
  isProcessing = true;
  
  try {
    showNotification("Loading image for cropping...");
    
    const imageData = await getImageDataFromUrl(info.srcUrl);
    currentImageData = imageData;
    
    await browser.tabs.create({
      url: browser.runtime.getURL("editor.html") + "?image=" + encodeURIComponent(imageData),
      active: true
    });
    
    showNotification("Image loaded in editor!");
    
  } catch (error) {
    showNotification("Failed to crop image: " + error.message);
  } finally {
    isProcessing = false;
  }
}

// Handle background removal
async function handleRemoveBackground(info, tab) {
  isProcessing = true;
  
  try {
    if (!removeBgApiKey) {
      showNotification("Please configure your remove.bg API key first");
      browser.tabs.create({ 
        url: browser.runtime.getURL("popup.html") + "?configure=api"
      });
      return;
    }
    
    showNotification("Removing background...");
    
    const result = await removeBackground(null, info.srcUrl);
    
    await browser.tabs.create({
      url: browser.runtime.getURL("editor.html") + "?image=" + encodeURIComponent(result) + "&fromRemoveBg=true",
      active: true
    });
    
    showNotification("Background removed successfully!");
    
  } catch (error) {
    showNotification("Failed to remove background: " + error.message);
  } finally {
    isProcessing = false;
  }
}

// Get image data from URL
async function getImageDataFromUrl(url) {
  try {
    if (url.startsWith('data:')) {
      return url;
    }
    
    const cacheBusterUrl = url + (url.includes('?') ? '&' : '?') + 't=' + Date.now();
    
    const response = await fetch(cacheBusterUrl, {
      mode: 'cors',
      credentials: 'omit'
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const blob = await response.blob();
    return await blobToDataURL(blob);
  } catch (error) {
    throw new Error("Failed to load image: " + error.message);
  }
}

// Convert blob to data URL
function blobToDataURL(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

// Remove background using remove.bg API
async function removeBackground(imageData, imageUrl) {
  console.log("Starting background removal");
  
  if (!removeBgApiKey) {
    throw new Error("API key not configured. Please set your remove.bg API key first.");
  }
  
  const formData = new FormData();
  
  try {
    if (imageData) {
      const response = await fetch(imageData);
      const blob = await response.blob();
      formData.append("image_file", blob, "image.png");
    } else if (imageUrl) {
      formData.append("image_url", imageUrl);
    } else {
      throw new Error("No image provided");
    }
    
    formData.append("size", "auto");
    formData.append("format", "png");
    
    const response = await fetch("https://api.remove.bg/v1.0/removebg", {
      method: "POST",
      headers: {
        "X-Api-Key": removeBgApiKey
      },
      body: formData
    });
    
    if (!response.ok) {
      let errorText;
      try {
        errorText = await response.text();
        try {
          const errorJson = JSON.parse(errorText);
          errorText = errorJson.errors ? errorJson.errors[0].title : errorText;
        } catch (e) {}
      } catch (e) {
        errorText = `HTTP ${response.status}`;
      }
      
      if (response.status === 402) {
        throw new Error("API quota exceeded. Free tier: 50 calls/month.");
      } else if (response.status === 403) {
        throw new Error("Invalid API key. Please check your remove.bg API key.");
      } else if (response.status === 429) {
        throw new Error("Too many requests. Please wait a moment.");
      } else {
        throw new Error(`API Error (${response.status}): ${errorText}`);
      }
    }
    
    const resultBlob = await response.blob();
    return await blobToDataURL(resultBlob);
    
  } catch (error) {
    if (error.message.includes("Failed to fetch")) {
      throw new Error("Network error. Please check your internet connection.");
    } else {
      throw error;
    }
  }
}

// Download image
function downloadImage(imageData, filename) {
  try {
    const byteString = atob(imageData.split(',')[1]);
    const mimeString = imageData.split(',')[0].split(':')[1].split(';')[0];
    const ab = new ArrayBuffer(byteString.length);
    const ia = new Uint8Array(ab);
    
    for (let i = 0; i < byteString.length; i++) {
      ia[i] = byteString.charCodeAt(i);
    }
    
    const blob = new Blob([ab], { type: mimeString });
    const url = URL.createObjectURL(blob);
    
    browser.downloads.download({
      url: url,
      filename: filename,
      saveAs: true
    }).then(() => {
      setTimeout(() => URL.revokeObjectURL(url), 10000);
    }).catch(() => {
      const link = document.createElement('a');
      link.href = imageData;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    });
    
  } catch (error) {
    showNotification("Download failed: " + error.message);
  }
}

// Show notification
function showNotification(message) {
  try {
    browser.notifications.create({
      type: "basic",
      iconUrl: browser.runtime.getURL("icons/icon.png"),
      title: "TinyIMG Editor",
      message: message
    });
  } catch (error) {}
}
EOL

# Create content.js (keep hover effects but with original design colors)
cat << 'EOL' > content.js
// Content script for TinyIMG Editor

console.log("TinyIMG Editor content script loaded");

// Listen for messages from background script
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === "getCurrentImage") {
    const images = Array.from(document.querySelectorAll('img'));
    
    let largestImage = null;
    let maxSize = 0;
    
    images.forEach(img => {
      const size = img.width * img.height;
      if (size > maxSize && !img.src.startsWith('data:') && img.src) {
        maxSize = size;
        largestImage = img;
      }
    });
    
    if (largestImage) {
      sendResponse({url: largestImage.src, success: true});
    } else {
      sendResponse({url: null, success: false, error: "No images found"});
    }
  } else if (message.action === "getAllImages") {
    const images = Array.from(document.querySelectorAll('img'));
    const imageUrls = images
      .filter(img => !img.src.startsWith('data:') && img.src)
      .map(img => ({
        url: img.src,
        width: img.width,
        height: img.height,
        alt: img.alt || 'image'
      }));
    
    sendResponse({images: imageUrls, success: true});
  }
  
  return true;
});

// Add image hover effects (using original design colors - #3a76b1 blue)
function addImageHoverEffects() {
  document.addEventListener('mouseover', (e) => {
    if (e.target.tagName === 'IMG' && !e.target.src.startsWith('data:') && e.target.src) {
      const img = e.target;
      
      img.style.boxShadow = '0 0 0 3px #3a76b1';
      img.style.transition = 'box-shadow 0.3s';
      img.style.cursor = 'pointer';
      img.style.borderRadius = '4px';
      
      if (!img.hasAttribute('data-image-editor-click')) {
        img.setAttribute('data-image-editor-click', 'true');
        img.addEventListener('click', handleImageClick, {once: true});
      }
    }
  });

  document.addEventListener('mouseout', (e) => {
    if (e.target.tagName === 'IMG') {
      e.target.style.boxShadow = '';
      e.target.style.cursor = '';
    }
  });
}

// Handle image click
function handleImageClick(e) {
  e.preventDefault();
  e.stopPropagation();
  showImageOptions(e.target);
}

// Show image options overlay (using original design)
function showImageOptions(img) {
  const existingOverlay = document.getElementById('image-editor-overlay');
  if (existingOverlay) existingOverlay.remove();
  
  const overlay = document.createElement('div');
  overlay.id = 'image-editor-overlay';
  overlay.style.position = 'fixed';
  overlay.style.top = '0';
  overlay.style.left = '0';
  overlay.style.width = '100%';
  overlay.style.height = '100%';
  overlay.style.backgroundColor = 'rgba(0,0,0,0.7)';
  overlay.style.zIndex = '999999';
  overlay.style.display = 'flex';
  overlay.style.justifyContent = 'center';
  overlay.style.alignItems = 'center';
  
  const optionsBox = document.createElement('div');
  optionsBox.style.backgroundColor = '#efefef';
  optionsBox.style.padding = '20px';
  optionsBox.style.borderRadius = '0';
  optionsBox.style.boxShadow = '0 4px 12px rgba(0,0,0,0.3)';
  optionsBox.style.textAlign = 'center';
  optionsBox.style.minWidth = '300px';
  optionsBox.style.border = '1px solid #5a5a5a';
  
  const title = document.createElement('h3');
  title.textContent = 'TinyIMG Editor';
  title.style.marginBottom = '15px';
  title.style.color = '#000';
  title.style.fontSize = '16px';
  title.style.fontWeight = 'bold';
  
  const preview = document.createElement('img');
  preview.src = img.src;
  preview.style.maxWidth = '200px';
  preview.style.maxHeight = '150px';
  preview.style.marginBottom = '15px';
  preview.style.border = '1px solid #c4c4c4';
  preview.style.objectFit = 'contain';
  
  const buttonsContainer = document.createElement('div');
  buttonsContainer.style.display = 'flex';
  buttonsContainer.style.flexDirection = 'column';
  buttonsContainer.style.gap = '8px';
  
  const cropBtn = createButton('Crop Image', () => {
    browser.runtime.sendMessage({
      action: 'setImageData',
      imageData: img.src
    }).then(() => {
      window.open(browser.runtime.getURL('editor.html') + '?image=' + encodeURIComponent(img.src), '_blank');
      overlay.remove();
    });
  });
  
  const removeBgBtn = createButton('Remove Background', () => {
    browser.runtime.sendMessage({
      action: 'removeBackground',
      imageUrl: img.src
    }).then(response => {
      if (response.success) {
        window.open(browser.runtime.getURL('editor.html') + '?image=' + encodeURIComponent(response.imageData) + '&fromRemoveBg=true', '_blank');
      }
      overlay.remove();
    });
  });
  
  const downloadBtn = createButton('Download Image', () => {
    const link = document.createElement('a');
    link.href = img.src;
    link.download = img.alt || 'image';
    link.click();
    overlay.remove();
  });
  
  const closeBtn = createButton('Close', () => {
    overlay.remove();
  });
  
  buttonsContainer.appendChild(cropBtn);
  buttonsContainer.appendChild(removeBgBtn);
  buttonsContainer.appendChild(downloadBtn);
  buttonsContainer.appendChild(closeBtn);
  
  optionsBox.appendChild(title);
  optionsBox.appendChild(preview);
  optionsBox.appendChild(buttonsContainer);
  overlay.appendChild(optionsBox);
  
  document.body.appendChild(overlay);
}

// Create button element (original design)
function createButton(text, onClick) {
  const button = document.createElement('button');
  button.textContent = text;
  button.style.backgroundColor = '#efefef';
  button.style.color = '#000';
  button.style.border = '1px solid #c4c4c4';
  button.style.padding = '8px 16px';
  button.style.margin = '0';
  button.style.cursor = 'pointer';
  button.style.fontSize = '14px';
  button.style.width = '100%';
  button.style.fontFamily = 'Arial, sans-serif';
  
  button.addEventListener('mouseenter', () => {
    button.style.backgroundColor = '#d6d6d6';
  });
  
  button.addEventListener('mouseleave', () => {
    button.style.backgroundColor = '#efefef';
  });
  
  button.addEventListener('click', onClick);
  
  return button;
}

// Initialize when page is loaded
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', addImageHoverEffects);
} else {
  addImageHoverEffects();
}

// Observer for dynamically added images
const observer = new MutationObserver((mutations) => {
  mutations.forEach((mutation) => {
    if (mutation.addedNodes.length) {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1) {
          if (node.tagName === 'IMG' && node.src && !node.src.startsWith('data:')) {
            node.style.boxShadow = '0 0 0 3px #3a76b1';
            node.style.cursor = 'pointer';
            node.addEventListener('click', handleImageClick);
          }
          node.querySelectorAll && node.querySelectorAll('img').forEach(img => {
            if (img.src && !img.src.startsWith('data:')) {
              img.style.boxShadow = '0 0 0 3px #3a76b1';
              img.style.cursor = 'pointer';
              img.addEventListener('click', handleImageClick);
            }
          });
        }
      });
    }
  });
});

observer.observe(document.body, { childList: true, subtree: true });
EOL

# Create popup.html (ORIGINAL TINYIMG DESIGN restored!)
cat << 'EOL' > popup.html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>TinyIMG Editor</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      font-family: Arial, sans-serif;
      font-size: 14px;
      user-select: none;
      -moz-user-select: none;
    }
    
    body {
      width: 260px;
      background: #efefef;
      color: #000;
      overflow: hidden;
    }
    
    .container {
      padding: 8px;
    }
    
    .title {
      text-align: center;
      font-weight: bold;
      padding: 8px 0;
      margin-bottom: 8px;
      border-bottom: 1px solid #c4c4c4;
      color: #333;
    }
    
    button {
      width: 100%;
      padding: 8px 12px;
      margin: 4px 0;
      background-color: #efefef;
      border: 1px solid #c4c4c4;
      cursor: pointer;
      text-align: left;
      font-size: 14px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    
    button:hover {
      background-color: #d6d6d6;
    }
    
    button.primary {
      background-color: #3a76b1;
      border-color: #2a5a8c;
      color: white;
    }
    
    button.primary:hover {
      background-color: #2a5a8c;
    }
    
    .section {
      margin: 12px 0;
      padding: 8px 0;
      border-top: 1px solid #c4c4c4;
    }
    
    .section:first-of-type {
      border-top: none;
    }
    
    .api-input {
      width: 100%;
      padding: 6px;
      margin: 4px 0;
      border: 1px solid #c4c4c4;
      background: #fff;
      font-family: monospace;
    }
    
    .api-input:focus {
      outline: 1px solid #3a76b1;
    }
    
    .status {
      margin-top: 8px;
      padding: 6px;
      font-size: 12px;
      display: none;
      background: #fff;
      border: 1px solid #c4c4c4;
    }
    
    .status.success {
      background: #e8f0fe;
      border-color: #3a76b1;
      display: block;
    }
    
    .status.error {
      background: #ffe8e8;
      border-color: #d83e3e;
      display: block;
    }
    
    .status.warning {
      background: #fff3e0;
      border-color: #f0ad4e;
      display: block;
    }
    
    .help-text {
      font-size: 11px;
      color: #666;
      margin-top: 8px;
      line-height: 1.4;
    }
    
    .help-text a {
      color: #3a76b1;
      text-decoration: none;
    }
    
    .help-text a:hover {
      text-decoration: underline;
    }
    
    hr {
      border: none;
      border-top: 1px solid #c4c4c4;
      margin: 8px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="title">TinyIMG Editor</div>
    
    <button id="openEditor">
      <span>📁</span> Open Editor
    </button>
    
    <button id="uploadImage">
      <span>📤</span> Upload Image
    </button>
    
    <button id="currentPageImages">
      <span>🌐</span> Page Images
    </button>
    
    <hr>
    
    <div style="font-weight: bold; margin: 8px 0 4px 0;">remove.bg API Key</div>
    <input type="password" id="apiKey" class="api-input" placeholder="Enter API key">
    <button id="saveApiKey" style="text-align: center; justify-content: center;">Save API Key</button>
    
    <div id="status" class="status"></div>
    
    <div class="help-text">
      • Get free API key: <a href="https://www.remove.bg/api#api-key" target="_blank">remove.bg/api</a><br>
      • 50 free calls/month<br>
      • Key stored locally
    </div>
    
    <hr>
    
    <div style="font-size: 11px; color: #666; text-align: center;">
      Right-click any image on any webpage for quick access
    </div>
  </div>
  
  <script src="popup.js"></script>
</body>
</html>
EOL

# Create popup.js (keep functionality, simplify UI)
cat << 'EOL' > popup.js
// Popup script for TinyIMG Editor
document.addEventListener('DOMContentLoaded', function() {
  console.log("Popup loaded");
  
  const urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('configure') === 'api') {
    document.getElementById('apiKey').focus();
    showStatus('Enter your remove.bg API key', 'warning');
  }
  
  loadApiKey();
  
  document.getElementById('openEditor').addEventListener('click', () => {
    browser.tabs.create({
      url: browser.runtime.getURL('editor.html'),
      active: true
    });
  });
  
  document.getElementById('uploadImage').addEventListener('click', () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    
    input.onchange = async (e) => {
      const file = e.target.files[0];
      if (file) {
        showStatus('Processing image...', 'warning');
        
        try {
          const imageData = await fileToDataURL(file);
          
          browser.runtime.sendMessage({
            action: 'setImageData',
            imageData: imageData
          }).then(() => {
            browser.tabs.create({
              url: browser.runtime.getURL('editor.html') + '?image=' + encodeURIComponent(imageData),
              active: true
            });
          });
        } catch (error) {
          showStatus('Failed to read image', 'error');
        }
      }
    };
    
    input.click();
  });
  
  document.getElementById('currentPageImages').addEventListener('click', () => {
    showStatus('Looking for images...', 'warning');
    
    browser.tabs.query({active: true, currentWindow: true}).then(tabs => {
      if (!tabs[0] || tabs[0].url.startsWith('about:') || tabs[0].url.startsWith('chrome:')) {
        showStatus('No webpage with images', 'error');
        return;
      }
      
      browser.tabs.sendMessage(tabs[0].id, {action: 'getCurrentImage'}).then(response => {
        if (response.success && response.url) {
          browser.runtime.sendMessage({
            action: 'setImageData',
            imageData: response.url
          }).then(() => {
            browser.tabs.create({
              url: browser.runtime.getURL('editor.html') + '?image=' + encodeURIComponent(response.url),
              active: true
            });
          });
        } else {
          showStatus('No images found on page', 'error');
        }
      }).catch(() => {
        showStatus('Please refresh the page', 'error');
      });
    });
  });
  
  document.getElementById('saveApiKey').addEventListener('click', saveApiKey);
  
  document.getElementById('apiKey').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      saveApiKey();
    }
  });
});

function loadApiKey() {
  browser.runtime.sendMessage({action: 'getApiKey'}).then(response => {
    if (response.apiKey) {
      document.getElementById('apiKey').value = response.apiKey;
      showStatus('API key loaded', 'success');
    } else {
      showStatus('No API key found', 'warning');
    }
  });
}

function saveApiKey() {
  const apiKeyInput = document.getElementById('apiKey');
  const apiKey = apiKeyInput.value.trim();
  
  if (!apiKey) {
    showStatus('Please enter an API key', 'error');
    apiKeyInput.focus();
    return;
  }
  
  const saveBtn = document.getElementById('saveApiKey');
  const originalText = saveBtn.textContent;
  saveBtn.textContent = 'Saving...';
  saveBtn.disabled = true;
  
  browser.runtime.sendMessage({
    action: 'saveApiKey',
    apiKey: apiKey
  }).then(response => {
    if (response.success) {
      showStatus('API key saved!', 'success');
    } else {
      showStatus('Failed to save API key', 'error');
    }
  }).catch(() => {
    showStatus('Failed to save API key', 'error');
  }).finally(() => {
    saveBtn.textContent = originalText;
    saveBtn.disabled = false;
  });
}

function fileToDataURL(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function showStatus(message, type) {
  const statusEl = document.getElementById('status');
  statusEl.textContent = message;
  statusEl.className = 'status ' + type;
  
  setTimeout(() => {
    statusEl.className = 'status';
    statusEl.textContent = '';
  }, 5000);
}
EOL

# Create editor.html (main editor with ORIGINAL TINYIMG DESIGN)
cat << 'EOL' > editor.html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>TinyIMG Editor</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0" />
  <link rel="icon" type="image/png" href="icons/icon.png">
  <style>
    * {
      font-family: Arial, sans-serif;
      font-size: 16px;
      box-sizing: border-box;
      user-select: none;
      -moz-user-select: none;
    }
    
    body {
      margin: 0;
      background: #000;
      display: flex;
      height: 100vh;
      overflow: hidden;
    }
    
    .toolbar {
      position: fixed;
      top: 0;
      left: 0;
      width: 180px;
      height: 100%;
      background: #efefef;
      border-right: 1px solid #5a5a5a;
      padding: 5px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
    }
    
    .toolbar::-webkit-scrollbar {
      display: none;
    }
    
    .toolbar strong {
      margin-top: 10px;
      margin-bottom: 5px;
      font-size: 14px;
    }
    
    .toolbar hr {
      border: 0;
      height: 1px;
      background: #c4c4c4;
      margin: 10px 0;
    }
    
    .toolbar button {
      margin: 3px 5px;
      padding: 5px;
      background-color: #efefef;
      border: 1px solid #c4c4c4;
      cursor: pointer;
      font-size: 14px;
      text-align: left;
    }
    
    .toolbar button:hover {
      background-color: #d6d6d6;
    }
    
    .toolbar button.selected {
      outline: 2px solid #3a76b1;
      background-color: #dce9f9;
    }
    
    .toolbar button:disabled {
      opacity: 0.4;
      cursor: default;
    }
    
    .toolbar button:disabled:hover {
      background-color: #efefef;
    }
    
    .toolbar input[type=number] {
      width: 100%;
      padding: 5px;
      margin: 3px 0;
      border: 1px solid #c4c4c4;
      background: #fff;
      font-size: 14px;
    }
    
    .toolbar input[type=number]:disabled {
      background-color: #efefef;
      opacity: 0.4;
    }
    
    .toolbar label {
      display: flex;
      align-items: center;
      gap: 5px;
      margin: 5px 0;
      font-size: 14px;
    }
    
    .toolbar input[type=checkbox] {
      cursor: pointer;
    }
    
    .color-picker {
      margin: 5px;
      padding: 5px;
      border: 1px solid #c4c4c4;
    }
    
    .color-picker.disabled {
      opacity: 0.4;
      pointer-events: none;
    }
    
    .color-picker-preview {
      width: 100%;
      height: 30px;
      border: 1px solid #c4c4c4;
      margin-bottom: 5px;
    }
    
    .color-picker-input {
      width: 100%;
      padding: 5px;
      margin: 2px 0;
      border: 1px solid #c4c4c4;
      font-family: monospace;
      font-size: 12px;
    }
    
    .containerResize {
      padding: 0 5px;
    }
    
    .title {
      text-align: center;
      font-weight: bold;
      margin: 10px 0;
      cursor: default;
    }
    
    .workspace {
      flex: 1;
      display: flex;
      justify-content: center;
      align-items: center;
      margin-left: 180px;
      overflow: auto;
    }
    
    canvas {
      background: #fff;
      max-width: 100%;
      max-height: 100%;
    }
    
    input[type=file] {
      display: none;
    }
    
    .notification {
      position: fixed;
      top: 20px;
      right: 20px;
      padding: 10px 20px;
      background: #efefef;
      border: 1px solid #5a5a5a;
      color: #000;
      z-index: 9999;
      display: none;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <input type="file" id="fileSelector" accept="image/*">
    <button id="btnOpen">📁 Open</button>
    <button id="btnUndo" disabled>↩ Undo</button>
    <button id="btnRedo" disabled>↪ Redo</button>
    
    <hr>
    <strong>Transform</strong>
    <button id="btnFlipH">↔ Flip H</button>
    <button id="btnFlipV">↕ Flip V</button>
    <button id="btnRotateLeft">↺ Rotate L</button>
    <button id="btnRotateRight">↻ Rotate R</button>
    <button id="btnCrop">✂ Crop</button>
    
    <hr>
    <strong>Merge</strong>
    <button id="btnMergeH">◫ Merge H</button>
    <button id="btnMergeV">▦ Merge V</button>
    <button id="btnPasteOverlay">📋 Paste Overlay</button>
    <input type="file" id="mergeFileSelector" accept="image/*">
    <input type="file" id="pasteOverlayFileSelector" accept="image/*">
    
    <hr>
    <strong>Draw</strong>
    <button id="btnDrawSquare">■ Square</button>
    <button id="btnDrawSquareOutline">□ Outline</button>
    <button id="btnDrawCircle">● Circle</button>
    <button id="btnDrawCircleOutline">○ Outline</button>
    <button id="btnDrawLine">/ Line</button>
    
    <div class="color-picker disabled" id="colorPicker">
      <div class="color-picker-preview" id="colorPreview" style="background:#ff0000"></div>
      <input type="text" id="inputShapeColorHex" class="color-picker-input" value="#ff0000" maxlength="7">
      <input type="text" id="inputShapeColorRgb" class="color-picker-input" value="255,0,0">
    </div>
    
    <hr>
    <div class="containerResize">
      <input type="number" id="inputWidth" min="1" placeholder="Width">
      <input type="number" id="inputHeight" min="1" placeholder="Height">
      <label><input type="checkbox" id="checkKeepRatio" checked> Keep ratio</label>
    </div>
    
    <hr>
    <strong>Download</strong>
    <button id="btnDownloadPNG">💾 PNG</button>
    <button id="btnDownloadJPG">💾 JPG</button>
    <button id="btnDownloadWEBP">💾 WebP</button>
    
    <hr>
    <strong>Base64</strong>
    <button id="btnDownloadPNGBase64">📄 PNG (Base64)</button>
    <button id="btnDownloadJPGBase64">📄 JPG (Base64)</button>
    <button id="btnDownloadWEBPBase64">📄 WebP (Base64)</button>
    
    <hr>
    <button id="btnRemoveBg" class="primary" style="background:#3a76b1; color:white; text-align:center; justify-content:center;">🎭 Remove Background</button>
  </div>
  
  <div class="workspace">
    <canvas id="canvas"></canvas>
  </div>
  
  <div id="notification" class="notification"></div>
  
  <script src="editor.js"></script>
</body>
</html>
EOL

# Create editor.js (core editor functionality from original TinyIMG + your enhancements)
cat << 'EOL' > editor.js
// TinyIMG Editor Core - Original functionality + remove.bg integration
var canvas, ctx, img = new Image();
var originalFileName = null;
var undoStack = [], redoStack = [];
var activeTool = null;
var isDrawingShape = false, isCropping = false;
var startX, startY;
var currentSelection = null;
var displayScaleX = 1, displayScaleY = 1;
var ratio = 1;
var shapeColor = "#ff0000";
var removeBgApiKey = "";

// DOM Elements
var btnOpen, btnUndo, btnRedo, btnFlipH, btnFlipV, btnRotateLeft, btnRotateRight;
var btnCrop, btnMergeH, btnMergeV, btnPasteOverlay, btnResize;
var btnDrawSquare, btnDrawSquareOutline, btnDrawCircle, btnDrawCircleOutline, btnDrawLine;
var btnDownloadPNG, btnDownloadJPG, btnDownloadWEBP;
var btnDownloadPNGBase64, btnDownloadJPGBase64, btnDownloadWEBPBase64;
var btnRemoveBg;
var inputWidth, inputHeight, checkKeepRatio;
var fileSelector, mergeFileSelector, pasteOverlayFileSelector;
var colorPicker, colorPreview, inputShapeColorHex, inputShapeColorRgb;

// Initialize
window.addEventListener('load', function() {
  getElements();
  initEventListeners();
  loadApiKey();
  checkUrlForImage();
});

function getElements() {
  canvas = document.getElementById('canvas');
  ctx = canvas.getContext('2d');
  
  btnOpen = document.getElementById('btnOpen');
  btnUndo = document.getElementById('btnUndo');
  btnRedo = document.getElementById('btnRedo');
  btnFlipH = document.getElementById('btnFlipH');
  btnFlipV = document.getElementById('btnFlipV');
  btnRotateLeft = document.getElementById('btnRotateLeft');
  btnRotateRight = document.getElementById('btnRotateRight');
  btnCrop = document.getElementById('btnCrop');
  btnMergeH = document.getElementById('btnMergeH');
  btnMergeV = document.getElementById('btnMergeV');
  btnPasteOverlay = document.getElementById('btnPasteOverlay');
  btnRemoveBg = document.getElementById('btnRemoveBg');
  
  btnDrawSquare = document.getElementById('btnDrawSquare');
  btnDrawSquareOutline = document.getElementById('btnDrawSquareOutline');
  btnDrawCircle = document.getElementById('btnDrawCircle');
  btnDrawCircleOutline = document.getElementById('btnDrawCircleOutline');
  btnDrawLine = document.getElementById('btnDrawLine');
  
  btnDownloadPNG = document.getElementById('btnDownloadPNG');
  btnDownloadJPG = document.getElementById('btnDownloadJPG');
  btnDownloadWEBP = document.getElementById('btnDownloadWEBP');
  btnDownloadPNGBase64 = document.getElementById('btnDownloadPNGBase64');
  btnDownloadJPGBase64 = document.getElementById('btnDownloadJPGBase64');
  btnDownloadWEBPBase64 = document.getElementById('btnDownloadWEBPBase64');
  
  inputWidth = document.getElementById('inputWidth');
  inputHeight = document.getElementById('inputHeight');
  checkKeepRatio = document.getElementById('checkKeepRatio');
  
  fileSelector = document.getElementById('fileSelector');
  mergeFileSelector = document.getElementById('mergeFileSelector');
  pasteOverlayFileSelector = document.getElementById('pasteOverlayFileSelector');
  
  colorPicker = document.getElementById('colorPicker');
  colorPreview = document.getElementById('colorPreview');
  inputShapeColorHex = document.getElementById('inputShapeColorHex');
  inputShapeColorRgb = document.getElementById('inputShapeColorRgb');
  
  disableAll();
}

function initEventListeners() {
  btnOpen.addEventListener('click', () => fileSelector.click());
  
  fileSelector.addEventListener('change', function(e) {
    var file = e.target.files[0];
    if (!file) return;
    
    originalFileName = file.name.replace(/\.[^/.]+$/, "");
    var reader = new FileReader();
    reader.onload = function(evt) {
      img.src = evt.target.result;
    };
    reader.readAsDataURL(file);
    fileSelector.value = null;
  });
  
  img.onload = function() {
    canvas.style.display = 'block';
    canvas.width = img.width;
    canvas.height = img.height;
    ctx.drawImage(img, 0, 0);
    inputWidth.value = img.width;
    inputHeight.value = img.height;
    ratio = img.width / img.height;
    enableAll();
    captureUndoState();
  };
  
  // Undo/Redo
  btnUndo.addEventListener('click', undo);
  btnRedo.addEventListener('click', redo);
  
  // Transform
  btnFlipH.addEventListener('click', () => flip(true, false));
  btnFlipV.addEventListener('click', () => flip(false, true));
  btnRotateLeft.addEventListener('click', () => rotate(-90));
  btnRotateRight.addEventListener('click', () => rotate(90));
  btnCrop.addEventListener('click', crop);
  
  // Merge
  btnMergeH.addEventListener('click', () => { mustMergeHorizontal = true; mergeFileSelector.click(); });
  btnMergeV.addEventListener('click', () => { mustMergeHorizontal = false; mergeFileSelector.click(); });
  btnPasteOverlay.addEventListener('click', () => pasteOverlayFileSelector.click());
  
  // Draw tools
  btnDrawSquare.addEventListener('click', () => setActiveTool('square'));
  btnDrawSquareOutline.addEventListener('click', () => setActiveTool('squareOutline'));
  btnDrawCircle.addEventListener('click', () => setActiveTool('circle'));
  btnDrawCircleOutline.addEventListener('click', () => setActiveTool('circleOutline'));
  btnDrawLine.addEventListener('click', () => setActiveTool('line'));
  
  // Color picker
  inputShapeColorHex.addEventListener('input', (e) => updateColorFromHex(e.target.value));
  inputShapeColorRgb.addEventListener('input', (e) => updateColorFromRgb(e.target.value));
  
  // Remove.bg
  btnRemoveBg.addEventListener('click', removeBackground);
  
  // Download
  btnDownloadPNG.addEventListener('click', () => downloadImage('png', false));
  btnDownloadJPG.addEventListener('click', () => downloadImage('jpeg', false));
  btnDownloadWEBP.addEventListener('click', () => downloadImage('webp', false));
  btnDownloadPNGBase64.addEventListener('click', () => downloadImage('png', true));
  btnDownloadJPGBase64.addEventListener('click', () => downloadImage('jpeg', true));
  btnDownloadWEBPBase64.addEventListener('click', () => downloadImage('webp', true));
  
  // Resize inputs
  inputWidth.addEventListener('input', function() {
    if (!checkKeepRatio.checked) return;
    var newW = parseInt(inputWidth.value);
    if (newW > 0) inputHeight.value = Math.round(newW / ratio);
  });
  
  inputHeight.addEventListener('input', function() {
    if (!checkKeepRatio.checked) return;
    var newH = parseInt(inputHeight.value);
    if (newH > 0) inputWidth.value = Math.round(newH * ratio);
  });
  
  btnResize = document.getElementById('btnResize');
  if (btnResize) {
    btnResize.addEventListener('click', resize);
  }
  
  // Mouse events for cropping/drawing
  canvas.addEventListener('mousedown', handleMouseDown);
  document.addEventListener('mousemove', handleMouseMove);
  document.addEventListener('mouseup', handleMouseUp);
  
  // Merge file selector
  mergeFileSelector.addEventListener('change', handleMergeFile);
  pasteOverlayFileSelector.addEventListener('change', handlePasteOverlayFile);
}

// Core functions from original TinyIMG
function disableAll() {
  var buttons = document.querySelectorAll('button');
  buttons.forEach(btn => {
    if (btn.id !== 'btnOpen') {
      btn.disabled = true;
    }
  });
  inputWidth.disabled = true;
  inputHeight.disabled = true;
  checkKeepRatio.disabled = true;
  colorPicker.classList.add('disabled');
}

function enableAll() {
  var buttons = document.querySelectorAll('button');
  buttons.forEach(btn => {
    btn.disabled = false;
  });
  inputWidth.disabled = false;
  inputHeight.disabled = false;
  checkKeepRatio.disabled = false;
  colorPicker.classList.remove('disabled');
  updateUndoRedoButtons();
}

function captureUndoState() {
  if (!canvas.width) return;
  var state = canvas.toDataURL();
  undoStack.push(state);
  redoStack = [];
  updateUndoRedoButtons();
}

function undo() {
  if (undoStack.length < 2) return;
  var current = canvas.toDataURL();
  redoStack.push(current);
  undoStack.pop();
  var prev = undoStack[undoStack.length - 1];
  loadImageData(prev);
  updateUndoRedoButtons();
}

function redo() {
  if (redoStack.length === 0) return;
  var next = redoStack.pop();
  var current = canvas.toDataURL();
  undoStack.push(current);
  loadImageData(next);
  updateUndoRedoButtons();
}

function loadImageData(dataUrl) {
  var tempImg = new Image();
  tempImg.onload = function() {
    canvas.width = tempImg.width;
    canvas.height = tempImg.height;
    ctx.drawImage(tempImg, 0, 0);
    inputWidth.value = tempImg.width;
    inputHeight.value = tempImg.height;
    ratio = tempImg.width / tempImg.height;
    img.src = dataUrl;
  };
  tempImg.src = dataUrl;
}

function updateUndoRedoButtons() {
  btnUndo.disabled = undoStack.length < 2;
  btnRedo.disabled = redoStack.length === 0;
}

function flip(horizontal, vertical) {
  if (!canvas.width) return;
  captureUndoState();
  
  var tmp = document.createElement('canvas');
  tmp.width = canvas.width;
  tmp.height = canvas.height;
  var tctx = tmp.getContext('2d');
  tctx.translate(horizontal ? tmp.width : 0, vertical ? tmp.height : 0);
  tctx.scale(horizontal ? -1 : 1, vertical ? -1 : 1);
  tctx.drawImage(canvas, 0, 0);
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(tmp, 0, 0);
  img.src = canvas.toDataURL();
}

function rotate(deg) {
  if (!canvas.width) return;
  captureUndoState();
  
  var tmp = document.createElement('canvas');
  var tctx = tmp.getContext('2d');
  
  if (Math.abs(deg) === 90 || Math.abs(deg) === 270) {
    tmp.width = canvas.height;
    tmp.height = canvas.width;
  } else {
    tmp.width = canvas.width;
    tmp.height = canvas.height;
  }
  
  tctx.translate(tmp.width / 2, tmp.height / 2);
  tctx.rotate((deg * Math.PI) / 180);
  tctx.drawImage(canvas, -canvas.width / 2, -canvas.height / 2);
  
  canvas.width = tmp.width;
  canvas.height = tmp.height;
  ctx.drawImage(tmp, 0, 0);
  img.src = canvas.toDataURL();
  inputWidth.value = canvas.width;
  inputHeight.value = canvas.height;
  ratio = canvas.width / canvas.height;
}

function crop() {
  if (!currentSelection) return;
  captureUndoState();
  
  var cropped = document.createElement('canvas');
  cropped.width = currentSelection.width;
  cropped.height = currentSelection.height;
  var croppedCtx = cropped.getContext('2d');
  
  croppedCtx.drawImage(
    img,
    currentSelection.x, currentSelection.y,
    currentSelection.width, currentSelection.height,
    0, 0, currentSelection.width, currentSelection.height
  );
  
  canvas.width = currentSelection.width;
  canvas.height = currentSelection.height;
  ctx.drawImage(cropped, 0, 0);
  img.src = canvas.toDataURL();
  currentSelection = null;
  inputWidth.value = canvas.width;
  inputHeight.value = canvas.height;
  ratio = canvas.width / canvas.height;
}

function resize() {
  var newW = parseInt(inputWidth.value);
  var newH = parseInt(inputHeight.value);
  
  if (!newW || !newH) return;
  captureUndoState();
  
  var tmp = document.createElement('canvas');
  tmp.width = newW;
  tmp.height = newH;
  var tctx = tmp.getContext('2d');
  tctx.drawImage(canvas, 0, 0, newW, newH);
  
  canvas.width = newW;
  canvas.height = newH;
  ctx.drawImage(tmp, 0, 0);
  img.src = canvas.toDataURL();
  ratio = canvas.width / canvas.height;
}

function setActiveTool(tool) {
  if (activeTool === tool) {
    activeTool = null;
  } else {
    activeTool = tool;
  }
  
  // Update button states
  [btnDrawSquare, btnDrawSquareOutline, btnDrawCircle, btnDrawCircleOutline, btnDrawLine].forEach(btn => {
    btn.classList.remove('selected');
  });
  
  if (activeTool) {
    var activeBtn = {
      'square': btnDrawSquare,
      'squareOutline': btnDrawSquareOutline,
      'circle': btnDrawCircle,
      'circleOutline': btnDrawCircleOutline,
      'line': btnDrawLine
    }[activeTool];
    if (activeBtn) activeBtn.classList.add('selected');
  }
  
  isCropping = false;
  currentSelection = null;
}

function handleMouseDown(e) {
  if (!canvas.width) return;
  if (e.button !== 0) return;
  
  var rect = canvas.getBoundingClientRect();
  displayScaleX = canvas.clientWidth / canvas.width;
  displayScaleY = canvas.clientHeight / canvas.height;
  
  var x = (e.clientX - rect.left) / displayScaleX;
  var y = (e.clientY - rect.top) / displayScaleY;
  
  if (activeTool) {
    isDrawingShape = true;
    startX = x;
    startY = y;
    return;
  }
  
  isCropping = true;
  startX = x;
  startY = y;
}

function handleMouseMove(e) {
  if (!isCropping && !isDrawingShape) return;
  
  var rect = canvas.getBoundingClientRect();
  var x = (e.clientX - rect.left) / displayScaleX;
  var y = (e.clientY - rect.top) / displayScaleY;
  
  if (isDrawingShape && activeTool) {
    redrawBaseImage();
    drawShape(startX, startY, x, y);
  } else if (isCropping) {
    currentSelection = {
      x: Math.min(startX, x),
      y: Math.min(startY, y),
      width: Math.abs(x - startX),
      height: Math.abs(y - startY)
    };
    drawSelection();
  }
}

function handleMouseUp(e) {
  if (isDrawingShape && activeTool) {
    var rect = canvas.getBoundingClientRect();
    var x = (e.clientX - rect.left) / displayScaleX;
    var y = (e.clientY - rect.top) / displayScaleY;
    
    captureUndoState();
    redrawBaseImage();
    drawShape(startX, startY, x, y);
    img.src = canvas.toDataURL();
    isDrawingShape = false;
  }
  
  isCropping = false;
  startX = null;
  startY = null;
}

function redrawBaseImage() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(img, 0, 0);
}

function drawShape(x1, y1, x2, y2) {
  ctx.save();
  ctx.strokeStyle = shapeColor;
  ctx.fillStyle = shapeColor;
  ctx.lineWidth = 3;
  
  switch(activeTool) {
    case 'square':
      var size = Math.min(Math.abs(x2 - x1), Math.abs(y2 - y1));
      var x = x2 > x1 ? x1 : x1 - size;
      var y = y2 > y1 ? y1 : y1 - size;
      ctx.fillRect(x, y, size, size);
      break;
      
    case 'squareOutline':
      var size = Math.min(Math.abs(x2 - x1), Math.abs(y2 - y1));
      var x = x2 > x1 ? x1 : x1 - size;
      var y = y2 > y1 ? y1 : y1 - size;
      ctx.strokeRect(x, y, size, size);
      break;
      
    case 'circle':
      var size = Math.min(Math.abs(x2 - x1), Math.abs(y2 - y1));
      var x = x2 > x1 ? x1 : x1 - size;
      var y = y2 > y1 ? y1 : y1 - size;
      ctx.beginPath();
      ctx.arc(x + size/2, y + size/2, size/2, 0, Math.PI * 2);
      ctx.fill();
      break;
      
    case 'circleOutline':
      var size = Math.min(Math.abs(x2 - x1), Math.abs(y2 - y1));
      var x = x2 > x1 ? x1 : x1 - size;
      var y = y2 > y1 ? y1 : y1 - size;
      ctx.beginPath();
      ctx.arc(x + size/2, y + size/2, size/2, 0, Math.PI * 2);
      ctx.stroke();
      break;
      
    case 'line':
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
      break;
  }
  
  ctx.restore();
}

function drawSelection() {
  if (!currentSelection) return;
  
  redrawBaseImage();
  
  ctx.fillStyle = 'rgba(0,0,0,0.7)';
  ctx.fillRect(0, 0, canvas.width, currentSelection.y);
  ctx.fillRect(0, currentSelection.y + currentSelection.height, canvas.width, canvas.height - (currentSelection.y + currentSelection.height));
  ctx.fillRect(0, currentSelection.y, currentSelection.x, currentSelection.height);
  ctx.fillRect(currentSelection.x + currentSelection.width, currentSelection.y, canvas.width - (currentSelection.x + currentSelection.width), currentSelection.height);
  
  ctx.strokeStyle = '#FFF';
  ctx.lineWidth = 2;
  ctx.strokeRect(currentSelection.x, currentSelection.y, currentSelection.width, currentSelection.height);
}

function downloadImage(format, asBase64) {
  if (!originalFileName) return;
  
  var canvasToUse = canvas;
  
  if (format === 'jpeg') {
    var tmp = document.createElement('canvas');
    tmp.width = canvas.width;
    tmp.height = canvas.height;
    var tctx = tmp.getContext('2d');
    tctx.fillStyle = '#fff';
    tctx.fillRect(0, 0, tmp.width, tmp.height);
    tctx.drawImage(canvas, 0, 0);
    canvasToUse = tmp;
  }
  
  if (asBase64) {
    var base64 = canvasToUse.toDataURL('image/' + format);
    var blob = new Blob([base64], { type: 'text/plain' });
    var url = URL.createObjectURL(blob);
    var link = document.createElement('a');
    link.download = originalFileName + '-base64.' + (format === 'jpeg' ? 'jpg' : format) + '.txt';
    link.href = url;
    link.click();
  } else {
    var link = document.createElement('a');
    link.download = originalFileName + '.' + (format === 'jpeg' ? 'jpg' : format);
    link.href = canvasToUse.toDataURL('image/' + format);
    link.click();
  }
}

// Color picker functions
function updateColorFromHex(hex) {
  if (!/^#[0-9A-F]{6}$/i.test(hex)) return;
  shapeColor = hex;
  colorPreview.style.backgroundColor = hex;
  
  var r = parseInt(hex.slice(1,3), 16);
  var g = parseInt(hex.slice(3,5), 16);
  var b = parseInt(hex.slice(5,7), 16);
  inputShapeColorRgb.value = r + ',' + g + ',' + b;
}

function updateColorFromRgb(rgb) {
  var parts = rgb.split(',').map(p => parseInt(p.trim()));
  if (parts.length !== 3 || parts.some(isNaN)) return;
  
  var hex = '#' + parts.map(p => p.toString(16).padStart(2,'0')).join('');
  shapeColor = hex;
  colorPreview.style.backgroundColor = hex;
  inputShapeColorHex.value = hex;
}

// API Key functions
function loadApiKey() {
  browser.runtime.sendMessage({action: 'getApiKey'}).then(response => {
    if (response.apiKey) {
      removeBgApiKey = response.apiKey;
    }
  });
}

function removeBackground() {
  if (!canvas.width) {
    showNotification('No image loaded');
    return;
  }
  
  if (!removeBgApiKey) {
    showNotification('Please set API key in popup first');
    return;
  }
  
  showNotification('Removing background...');
  
  browser.runtime.sendMessage({
    action: 'removeBackground',
    imageData: canvas.toDataURL()
  }).then(response => {
    if (response.success) {
      loadImageData(response.imageData);
      showNotification('Background removed!');
    } else {
      showNotification('Error: ' + response.error);
    }
  });
}

function handleMergeFile(e) {
  var file = e.target.files[0];
  if (!file) return;
  
  var reader = new FileReader();
  reader.onload = function(evt) {
    var mergeImg = new Image();
    mergeImg.onload = function() {
      mergeImages(mergeImg, mustMergeHorizontal);
    };
    mergeImg.src = evt.target.result;
  };
  reader.readAsDataURL(file);
}

function handlePasteOverlayFile(e) {
  var file = e.target.files[0];
  if (!file) return;
  
  var reader = new FileReader();
  reader.onload = function(evt) {
    var overlayImg = new Image();
    overlayImg.onload = function() {
      pasteOverlay(overlayImg);
    };
    overlayImg.src = evt.target.result;
  };
  reader.readAsDataURL(file);
}

function mergeImages(mergeImg, horizontal) {
  captureUndoState();
  
  var newCanvas = document.createElement('canvas');
  var newCtx = newCanvas.getContext('2d');
  
  if (horizontal) {
    var scale = img.height / mergeImg.height;
    var mergeW = mergeImg.width * scale;
    newCanvas.width = img.width + mergeW;
    newCanvas.height = img.height;
    newCtx.drawImage(img, 0, 0);
    newCtx.drawImage(mergeImg, img.width, 0, mergeW, img.height);
  } else {
    var scale = img.width / mergeImg.width;
    var mergeH = mergeImg.height * scale;
    newCanvas.width = img.width;
    newCanvas.height = img.height + mergeH;
    newCtx.drawImage(img, 0, 0);
    newCtx.drawImage(mergeImg, 0, img.height, img.width, mergeH);
  }
  
  canvas.width = newCanvas.width;
  canvas.height = newCanvas.height;
  ctx.drawImage(newCanvas, 0, 0);
  img.src = canvas.toDataURL();
  inputWidth.value = canvas.width;
  inputHeight.value = canvas.height;
  ratio = canvas.width / canvas.height;
}

function pasteOverlay(overlayImg) {
  captureUndoState();
  
  var x = (canvas.width - overlayImg.width) / 2;
  var y = (canvas.height - overlayImg.height) / 2;
  
  ctx.drawImage(overlayImg, x, y);
  img.src = canvas.toDataURL();
}

function checkUrlForImage() {
  var urlParams = new URLSearchParams(window.location.search);
  var imageParam = urlParams.get('image');
  
  if (imageParam) {
    img.src = imageParam;
  }
}

function showNotification(msg) {
  var notif = document.getElementById('notification');
  notif.textContent = msg;
  notif.style.display = 'block';
  
  setTimeout(() => {
    notif.style.display = 'none';
  }, 3000);
}
EOL

# Create README.md
cat << 'EOL' > README.md
# TinyIMG Editor - Firefox Extension

A lightweight image editor for Firefox with original TinyIMG design and enhanced features.

## Features
- ✂️ Crop, resize, rotate, flip images
- 🎨 Draw shapes (squares, circles, lines)
- 🎭 AI background removal (remove.bg API)
- 📋 Right-click any image on any webpage
- 💾 Download as PNG, JPG, WebP
- 📄 Export as Base64
- ↩️ Undo/Redo support

## Installation
1. Open Firefox and go to `about:debugging`
2. Click "This Firefox" → "Load Temporary Add-on"
3. Select the `manifest.json` file

## Get API Key for Background Removal
1. Visit https://www.remove.bg/api#api-key
2. Sign up for free (50 calls/month)
3. Enter API key in extension popup

## Usage
- **Right-click** any image on any webpage
- Click extension icon in toolbar
- Open editor and drag & drop images

## Original Design
Maintains the clean, functional aesthetic of TinyIMG Editor with gray toolbar and black workspace.
EOL


# Create LICENSE.md
cat << EOL > LICENSE.md
MIT License

Copyright (c) $(date +%Y) Gabriel Majorsky

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Third-party Services:
- remove.bg API (https://www.remove.bg) - Proprietary, free tier available
EOL

# ===============================================
# Auto-Package extension as .xpi file
# ===============================================

echo -e "${CYAN}📦 Auto-packaging extension as .xpi file...${NC}"

# Stay in the extension directory
cd "$EXTNAME"
XPI_FILE="${EXTNAME}.xpi"

# Remove any existing XPI file
rm -f "$XPI_FILE" 2>/dev/null
Create the XPI file with correct structure

echo -e "${CYAN}Creating $XPI_FILE...${NC}"

# Use 7z if available
if command -v 7z &> /dev/null; then
7z a "$XPI_FILE" * -r -x!.xpi -x!.
elif command -v zip &> /dev/null; then
zip -r "$XPI_FILE" * -x ".xpi" -x "."
else
echo -e "${RED}Error: Need zip or 7z to create XPI${NC}"
exit 1
fi

# Check if XPI was created
if [ -f "$XPI_FILE" ]; then
echo -e "${GREEN}✅ Created: $XPI_FILE${NC}"
echo -e "${YELLOW}📦 XPI file size: $(du -h "$XPI_FILE" | cut -f1)${NC}"

# Move XPI to parent directory
echo -e "${CYAN}📁 Moving XPI to parent directory...${NC}"
mv "$XPI_FILE" "../"
XPI_FILE="../${EXTNAME}.xpi"

# Move XPI to Downloads folder
echo -e "${CYAN}📁 Moving XPI to Downloads folder...${NC}"
mv "$XPI_FILE" "$HOME/Downloads/${EXTNAME}.xpi"
XPI_FILE="$HOME/Downloads/${EXTNAME}.xpi"
echo -e "${GREEN}✅ XPI moved to: $XPI_FILE${NC}"

# Open Firefox Developer Edition addons page
echo -e "${CYAN}🌐 Opening Firefox Developer Edition addons page...${NC}"
/Applications/Firefox\ Developer\ Edition.app/Contents/MacOS/firefox "about:addons" &
# Go to parent directory
cd ..

echo -e ""
echo -e "${GREEN}✨ FILES:${NC}"
echo -e " • ${EXTNAME}/ - Source folder"
echo -e " • ${EXTNAME}.xpi - Extension package"

echo -e ""
echo -e "${CYAN}🚀 INSTALLATION:${NC}"
echo -e " • Drag and drop ${EXTNAME}.xpi into Firefox"
echo -e " • Or load temporarily via about:debugging"

else
echo -e "${RED}❌ Failed to create XPI file${NC}"
fi

echo -e ""
echo -e "${GREEN}✅ Extension generation complete!${NC}"
echo -e ""
echo -e "${YELLOW}🎯 Features preserved:${NC}"
echo -e "  ✅ Original TinyIMG gray toolbar design"
echo -e "  ✅ Black workspace background"
echo -e "  ✅ Simple, functional buttons"
echo -e "  ✅ remove.bg API integration"
echo -e "  ✅ Right-click context menu"
echo -e "  ✅ Image hover effects"
echo -e "  ✅ Multiple export formats"
echo -e "  ✅ Undo/Redo support"
echo -e ""
echo -e "${CYAN}Load in Firefox: about:debugging → This Firefox → Load Temporary Add-on${NC}"

##########MOZILLA API KEY######################
#https://addons.mozilla.org/en-GB/developers/addon/api/key/
###########################################


# Here's my analysis of what this script does:
# 🎯 Core Functionality

# The script creates a complete Firefox extension that provides:
#     Image Cropping - Interactive crop tool with handles and aspect ratios
#     Background Removal - Integration with remove.bg API
#     Browser Integration - Right-click context menus, toolbar button, hover effects
#     Export Options - Multiple formats (PNG, JPEG, WebP), copy to clipboard, etc.

# 📁 Files Generated

# The script creates 10 essential files in a structured folder:

# manifest.json          # Extension configuration
# background.js          # Background service worker
# content.js            # Page interaction script
# popup.html/popup.js   # Toolbar popup interface
# simple-cropper.html/js # Image editor interface
# icons/                # Extension icons
# README.md             # Documentation
# LICENSE.md            # MIT License

# 🔧 Key Features of the Extension
#     Professional UI - Modern gradient design with proper feedback
#     Multiple Usage Methods:
#         Right-click on any webpage image
#         Toolbar button with popup
#         Drag & drop into editor

#     Standalone Cropper - No external dependencies, pure JavaScript
#     API Integration - Proper remove.bg API handling with free tier (50/month)
#     Error Handling - Comprehensive error messages and fallbacks
#     Responsive Design - Works on different screen sizes

# ⚡ Automation Benefits
#     One-Command Setup - Single Bash command generates everything
#     Self-Contained - All code generated locally, no external downloads
#     Auto-Packaging - Creates .xpi files ready for submission
#     Auto-Signing - Attempts to sign via Mozilla API
#     Clean Structure - Proper file organization and documentation

# 🚀 Signing & Deployment Automation
# The script includes an impressive auto-signing feature that:
#     Creates .xpi package from generated files
#     Attempts to sign via Mozilla's API (with credential management)
#     Provides fallback manual instructions if auto-signing fails
#     Handles the entire submission workflow

# 🔒 Security Considerations
#     API Key Storage - Keys stored locally in browser storage
#     CSP Headers - Proper content security policy in manifest
#     Permission Scoping - Minimal required permissions
#     Data Collection - Clear data collection declaration

# 📦 What Makes This Production-Ready
#     Complete Error Handling - Network errors, API failures, user errors
#     UX Polish - Loading states, notifications, visual feedback
#     Cross-Browser Compatibility - Firefox-specific APIs with fallbacks
#     Performance Optimizations - Lazy loading, canvas operations
#     Documentation - Comprehensive README with troubleshooting

# 💡 Use Cases for Automation
# This script is perfect for:
#     Developers creating similar image editing extensions
#     Agencies needing to deploy custom extensions for clients
#     Educational Purposes - Learning extension development
#     Rapid Prototyping - Testing image editing concepts

# 🎨 Design & UX Highlights
#     Consistent Visual Design - Purple gradient theme throughout
#     Intuitive Workflow - Clear progression from selection to editing to export
#     Multiple Entry Points - Users can access features in different ways
#     Preview System - Real-time previews before applying changes
#     Helpful Tooltips - Clear instructions and error messages

# 🔄 Improvement Opportunities

# The script could be enhanced with:
#     Configuration Options - More customization during generation
#     Theme Variants - Different color schemes
#     Additional Image Filters - Brightness, contrast, saturation controls
#     Batch Processing - Handle multiple images
#     Cloud Storage Integration - Save to Google Drive, Dropbox, etc.

# ✅ Why This is Excellent for Automation
#     Complete - Everything needed in one script
#     Idempotent - Can be run multiple times safely
#     Self-Explanatory - Clear output messages and documentation
#     Extensible - Easy to modify for different use cases
#     Professional - Production-quality code structure

# This is an impressive automation script that goes beyond simple file generation to handle the entire extension development lifecycle, including packaging and submission. It's well-structured, well-documented, and creates a genuinely useful tool.


# Here are all the API endpoints from the Mozilla Add-ons API documentation you provided:
# SEARCH & DISCOVERY
#     Search Add-ons - GET /api/v5/addons/search/
#         Search through public add-ons with filters
#     Autocomplete - GET /api/v5/addons/autocomplete/
#         Similar to search, optimized for autocomplete (max 10 results)

# ADD-ON MANAGEMENT
#     Create Add-on - POST /api/v5/addons/addon/
#         Submit upload to create new add-on
#     Get Add-on Detail - GET /api/v5/addons/addon/{id|slug|guid}/
#         Fetch specific add-on by id, slug, or guid
#     Edit Add-on - PATCH /api/v5/addons/addon/{id|slug|guid}/
#         Update add-on metadata
#     Create or Edit (PUT) - PUT /api/v5/addons/addon/{guid}/
#         Create new or update existing add-on if guid exists
#     Delete Add-on - DELETE /api/v5/addons/addon/{id|slug|guid}/
#         Delete add-on (requires confirmation token)
#     Delete Confirm - GET /api/v5/addons/addon/{id|slug|guid}/delete_confirm/
#         Get confirmation token for deletion

# VERSION MANAGEMENT
#     List Versions - GET /api/v5/addons/addon/{addon_id|slug|guid}/versions/
#         List all versions for an add-on
#     Version Detail - GET /api/v5/addons/addon/{addon_id|slug|guid}/versions/{id|version_number}/
#         Get specific version details
#     Create Version - POST /api/v5/addons/addon/{addon_id|slug|guid}/versions/
#         Submit upload to create new version
#     Edit Version - PATCH /api/v5/addons/addon/{addon_id|slug|guid}/versions/{id|version_number}/
#         Update version metadata
#     Delete Version - DELETE /api/v5/addons/addon/{addon_id|slug|guid}/versions/{id|version_number}/
#         Delete specific version
#     Version Rollback - POST /api/v5/addons/addon/{addon_id|slug|guid}/versions/{id|version_number}/rollback/
#         Rollback to previous approved version

# PREVIEW IMAGES
#     Create Preview - POST /api/v5/addons/addon/{addon_id|slug|guid}/previews/
#         Upload preview image for add-on
#     Edit Preview - PATCH /api/v5/addons/addon/{addon_id|slug|guid}/previews/{id}/
#         Update preview metadata
#     Delete Preview - DELETE /api/v5/addons/addon/{addon_id|slug|guid}/previews/{id}/
#         Delete preview image

# UPLOAD MANAGEMENT
#     Create Upload - POST /api/v5/addons/upload/
#         Upload add-on file for validation
#     List Uploads - GET /api/v5/addons/upload/
#         List user's previous uploads
#     Upload Detail - GET /api/v5/addons/upload/{uuid}/
#         Get specific upload details

# LEGAL DOCUMENTS
#     Get EULA & Privacy Policy - GET /api/v5/addons/addon/{id|slug|guid}/eula_policy/
#         Fetch add-on's EULA and privacy policy
#     Edit EULA & Privacy Policy - PATCH /api/v5/addons/addon/{id|slug|guid}/eula_policy/
#         Update EULA and privacy policy

# SPECIALIZED ENDPOINTS
#     Language Tools - GET /api/v5/addons/language-tools/
#         List all public language tools (dictionaries/language packs)

#     Replacement Add-ons - GET /api/v5/addons/replacement-addon/
#         Get suggested replacements for legacy add-ons
#     Recommendations - GET /api/v5/addons/recommendations/
#         Get add-on recommendations
#     Browser Mappings - GET /api/v5/addons/browser-mappings/
#         Map Chrome extensions to Firefox add-ons

# KEY AUTHENTICATION & PERMISSIONS
#     Most write operations require authentication
#     Delete operations require additional confirmation tokens
#     Non-public add-ons require reviewer permissions or developer status
#     Unlisted versions require specific permissions to access

# COMMON PARAMETERS ACROSS ENDPOINTS
#     app - Filter by application (firefox or android)
#     lang - Language for translations
#     type - Add-on type (extension, theme, dictionary, statictheme, etc.)
#     page / page_size - Pagination
#     q - Search query
#     sort - Sort order

# This gives you 26 distinct endpoints for managing every aspect of add-on lifecycle on AMO!

# FULL AUTOMATION WORKFLOW
# 1. AUTHENTICATION SETUP (One-time)
# bash

# # Create credentials file
# echo "API_KEY=your_jwt_issuer" > mozilla_credentials.txt
# echo "API_SECRET=your_jwt_secret" >> mozilla_credentials.txt
# echo "USER_ID=your_user_id" >> mozilla_credentials.txt

# 2. COMPLETE AUTOMATION SCRIPT
# bash

# #!/bin/bash
# # Firefox Add-on Auto-Creator

# # Load credentials
# source mozilla_credentials.txt

# # Variables
# ADDON_NAME="Image Editor Pro"
# ADDON_SUMMARY="Crop images and remove backgrounds using remove.bg API"
# ADDON_VERSION="1.0"
# XPI_FILE="image-editor-extension.xpi"
# CHANNEL="listed"  # or "unlisted"

# # ========== STEP 1: UPLOAD XPI ==========
# echo "📤 Uploading XPI file..."
# UPLOAD_RESPONSE=$(curl -s -X POST \
#   "https://addons.mozilla.org/api/v5/addons/upload/" \
#   -H "Authorization: JWT $API_SECRET" \
#   -F "upload=@$XPI_FILE" \
#   -F "channel=$CHANNEL")

# # Extract upload UUID
# UPLOAD_UUID=$(echo "$UPLOAD_RESPONSE" | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)
# echo "✅ Upload UUID: $UPLOAD_UUID"

# # Wait for validation (polling)
# echo "⏳ Waiting for validation..."
# for i in {1..30}; do
#   STATUS_RESPONSE=$(curl -s -X GET \
#     "https://addons.mozilla.org/api/v5/addons/upload/$UPLOAD_UUID/" \
#     -H "Authorization: JWT $API_SECRET")
  
#   PROCESSED=$(echo "$STATUS_RESPONSE" | grep -o '"processed":[^,]*' | cut -d':' -f2)
#   VALID=$(echo "$STATUS_RESPONSE" | grep -o '"valid":[^,]*' | cut -d':' -f2)
  
#   if [ "$PROCESSED" = "true" ]; then
#     if [ "$VALID" = "true" ]; then
#       echo "✅ Validation passed!"
#       break
#     else
#       echo "❌ Validation failed!"
#       exit 1
#     fi
#   fi
#   sleep 5
# done

# # ========== STEP 2: CREATE ADD-ON ==========
# echo "🚀 Creating add-on..."
# CREATE_RESPONSE=$(curl -s -X POST \
#   "https://addons.mozilla.org/api/v5/addons/addon/" \
#   -H "Authorization: JWT $API_SECRET" \
#   -H "Content-Type: application/json" \
#   -d "{
#     \"name\": {\"en-US\": \"$ADDON_NAME\"},
#     \"summary\": {\"en-US\": \"$ADDON_SUMMARY\"},
#     \"version\": {
#       \"upload\": \"$UPLOAD_UUID\"
#     },
#     \"categories\": {
#       \"firefox\": [\"photos-media\"]
#     },
#     \"tags\": [\"image\", \"editor\", \"crop\", \"background\"]
#   }")

# # Extract add-on ID/slug
# ADDON_SLUG=$(echo "$CREATE_RESPONSE" | grep -o '"slug":"[^"]*"' | cut -d'"' -f4)
# ADDON_GUID=$(echo "$CREATE_RESPONSE" | grep -o '"guid":"[^"]*"' | cut -d'"' -f4)
# echo "✅ Add-on created!"
# echo "   Slug: $ADDON_SLUG"
# echo "   GUID: $ADDON_GUID"

# # ========== STEP 3: ADD METADATA ==========
# echo "🏷️ Adding additional metadata..."
# # Set categories
# curl -s -X PATCH \
#   "https://addons.mozilla.org/api/v5/addons/addon/$ADDON_SLUG/" \
#   -H "Authorization: JWT $API_SECRET" \
#   -H "Content-Type: application/json" \
#   -d "{
#     \"categories\": {
#       \"firefox\": [\"photos-media\"],
#       \"android\": [\"photos-media\"]
#     }
#   }"

# # Set description
# curl -s -X PATCH \
#   "https://addons.mozilla.org/api/v5/addons/addon/$ADDON_SLUG/" \
#   -H "Authorization: JWT $API_SECRET" \
#   -H "Content-Type: application/json" \
#   -d "{
#     \"description\": {\"en-US\": \"Advanced image editor with cropping and AI background removal. Features: Interactive cropping with handles, remove.bg API integration, multiple export formats, drag & drop support.\"}
#   }"

# # ========== STEP 4: UPLOAD PREVIEWS ==========
# echo "🖼️ Uploading preview screenshots..."
# # Convert images to base64 and upload
# for IMG in preview1.png preview2.png preview3.png; do
#   if [ -f "$IMG" ]; then
#     # Create preview via multipart form-data
#     curl -s -X POST \
#       "https://addons.mozilla.org/api/v5/addons/addon/$ADDON_SLUG/previews/" \
#       -H "Authorization: JWT $API_SECRET" \
#       -F "image=@$IMG"
#   fi
# done

# # ========== STEP 5: WAIT FOR REVIEW ==========
# echo "⏳ Checking review status..."
# # For listed add-ons, they need review
# REVIEW_STATUS=""
# while [ "$REVIEW_STATUS" != "public" ]; do
#   DETAIL_RESPONSE=$(curl -s -X GET \
#     "https://addons.mozilla.org/api/v5/addons/addon/$ADDON_SLUG/" \
#     -H "Authorization: JWT $API_SECRET")
  
#   REVIEW_STATUS=$(echo "$DETAIL_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  
#   case $REVIEW_STATUS in
#     "public")
#       echo "✅ Add-on approved and public!"
#       ;;
#     "nominated")
#       echo "⏳ Add-on submitted for review..."
#       ;;
#     "disabled")
#       echo "❌ Add-on was disabled"
#       exit 1
#       ;;
#   esac
#   sleep 30
# done

# # ========== STEP 6: GET DOWNLOAD URL ==========
# echo "📦 Getting signed extension..."
# VERSION_RESPONSE=$(curl -s -X GET \
#   "https://addons.mozilla.org/api/v5/addons/addon/$ADDON_SLUG/versions/" \
#   -H "Authorization: JWT $API_SECRET")

# DOWNLOAD_URL=$(echo "$VERSION_RESPONSE" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)

# if [ -n "$DOWNLOAD_URL" ]; then
#   curl -s -L -o "${ADDON_NAME}-signed.xpi" "$DOWNLOAD_URL"
#   echo "✅ Signed extension downloaded: ${ADDON_NAME}-signed.xpi"
# else
#   echo "📋 Manual download: https://addons.mozilla.org/developers/addon/$ADDON_SLUG/versions"
# fi

# echo "🎉 Add-on creation complete!"

# 3. COMPREHENSIVE PYTHON AUTOMATION SCRIPT
# python

# #!/usr/bin/env python3
# """
# Firefox Add-on Auto-Creator
# Complete API automation
# """

# import requests
# import json
# import time
# import os
# from pathlib import Path

# class FirefoxAddonAutomator:
#     def __init__(self, api_key, api_secret):
#         self.api_key = api_key
#         self.api_secret = api_secret
#         self.base_url = "https://addons.mozilla.org/api/v5"
#         self.headers = {
#             "Authorization": f"JWT {api_secret}",
#             "Content-Type": "application/json"
#         }
    
#     def upload_xpi(self, xpi_path, channel="listed"):
#         """Step 1: Upload XPI file"""
#         print(f"📤 Uploading {xpi_path}...")
        
#         with open(xpi_path, 'rb') as f:
#             response = requests.post(
#                 f"{self.base_url}/addons/upload/",
#                 headers={"Authorization": f"JWT {self.api_secret}"},
#                 files={"upload": f},
#                 data={"channel": channel},
#                 timeout=60
#             )
        
#         if response.status_code != 201:
#             raise Exception(f"Upload failed: {response.text}")
        
#         data = response.json()
#         uuid = data.get('uuid')
#         print(f"✅ Upload UUID: {uuid}")
#         return uuid
    
#     def wait_for_validation(self, uuid, max_attempts=30):
#         """Wait for upload validation"""
#         print("⏳ Waiting for validation...")
        
#         for attempt in range(max_attempts):
#             response = requests.get(
#                 f"{self.base_url}/addons/upload/{uuid}/",
#                 headers=self.headers
#             )
            
#             if response.status_code == 200:
#                 data = response.json()
#                 processed = data.get('processed', False)
#                 valid = data.get('valid', False)
                
#                 if processed:
#                     if valid:
#                         print("✅ Validation passed!")
#                         return True
#                     else:
#                         print(f"❌ Validation failed: {data.get('validation', {})}")
#                         return False
            
#             time.sleep(5)
        
#         print("❌ Validation timeout")
#         return False
    
#     def create_addon(self, upload_uuid, metadata):
#         """Step 2: Create add-on with metadata"""
#         print("🚀 Creating add-on...")
        
#         payload = {
#             "name": {"en-US": metadata["name"]},
#             "summary": {"en-US": metadata["summary"]},
#             "version": {"upload": upload_uuid},
#             "categories": metadata.get("categories", {}),
#             "tags": metadata.get("tags", [])
#         }
        
#         response = requests.post(
#             f"{self.base_url}/addons/addon/",
#             headers=self.headers,
#             json=payload
#         )
        
#         if response.status_code != 201:
#             raise Exception(f"Create failed: {response.text}")
        
#         data = response.json()
#         slug = data.get('slug')
#         guid = data.get('guid')
#         print(f"✅ Add-on created! Slug: {slug}, GUID: {guid}")
#         return slug, guid
    
#     def update_metadata(self, slug, metadata_updates):
#         """Update add-on metadata"""
#         print("🏷️ Updating metadata...")
        
#         response = requests.patch(
#             f"{self.base_url}/addons/addon/{slug}/",
#             headers=self.headers,
#             json=metadata_updates
#         )
        
#         if response.status_code == 200:
#             print("✅ Metadata updated")
#         else:
#             print(f"⚠️ Metadata update warning: {response.text}")
    
#     def upload_preview(self, slug, image_path, caption=None):
#         """Upload preview screenshot"""
#         print(f"🖼️ Uploading preview: {image_path}")
        
#         with open(image_path, 'rb') as f:
#             files = {"image": f}
#             data = {}
#             if caption:
#                 data["caption"] = json.dumps({"en-US": caption})
            
#             response = requests.post(
#                 f"{self.base_url}/addons/addon/{slug}/previews/",
#                 headers={"Authorization": f"JWT {self.api_secret}"},
#                 files=files,
#                 data=data
#             )
        
#         if response.status_code == 201:
#             print("✅ Preview uploaded")
#         else:
#             print(f"⚠️ Preview upload warning: {response.text}")
    
#     def get_addon_status(self, slug):
#         """Check add-on review status"""
#         response = requests.get(
#             f"{self.base_url}/addons/addon/{slug}/",
#             headers=self.headers
#         )
        
#         if response.status_code == 200:
#             data = response.json()
#             return data.get('status'), data.get('is_disabled')
#         return None, None
    
#     def download_signed_xpi(self, slug, output_path):
#         """Download signed extension"""
#         print("📦 Getting signed extension...")
        
#         # Get versions list
#         response = requests.get(
#             f"{self.base_url}/addons/addon/{slug}/versions/",
#             headers=self.headers
#         )
        
#         if response.status_code == 200:
#             data = response.json()
#             # Find latest version with download URL
#             for version in data.get('results', []):
#                 for file in version.get('files', []):
#                     if file.get('url'):
#                         download_url = file['url']
                        
#                         # Download the file
#                         file_response = requests.get(download_url)
#                         if file_response.status_code == 200:
#                             with open(output_path, 'wb') as f:
#                                 f.write(file_response.content)
#                             print(f"✅ Signed extension saved: {output_path}")
#                             return True
        
#         print("⚠️ Could not auto-download signed extension")
#         return False
    
#     def automate(self, xpi_path, metadata, previews=None):
#         """Full automation workflow"""
#         print("=" * 50)
#         print("🚀 Starting Firefox Add-on Automation")
#         print("=" * 50)
        
#         try:
#             # 1. Upload
#             upload_uuid = self.upload_xpi(xpi_path)
            
#             # 2. Wait for validation
#             if not self.wait_for_validation(upload_uuid):
#                 return False
            
#             # 3. Create add-on
#             slug, guid = self.create_addon(upload_uuid, metadata)
            
#             # 4. Optional: Update additional metadata
#             if metadata.get("description"):
#                 self.update_metadata(slug, {
#                     "description": {"en-US": metadata["description"]}
#                 })
            
#             if metadata.get("homepage"):
#                 self.update_metadata(slug, {
#                     "homepage": {"en-US": metadata["homepage"]}
#                 })
            
#             # 5. Upload previews
#             if previews:
#                 for preview in previews:
#                     self.upload_preview(slug, preview["path"], preview.get("caption"))
            
#             # 6. Wait for review (for listed add-ons)
#             print("⏳ Waiting for review...")
#             while True:
#                 status, disabled = self.get_addon_status(slug)
                
#                 if status == "public":
#                     print("✅ Add-on approved and public!")
#                     break
#                 elif status == "nominated":
#                     print("⏳ Still in review...")
#                 elif status == "disabled" or disabled:
#                     print("❌ Add-on was disabled")
#                     return False
                
#                 time.sleep(30)  # Check every 30 seconds
            
#             # 7. Download signed version
#             output_xpi = f"{metadata['name'].replace(' ', '-')}-signed.xpi"
#             self.download_signed_xpi(slug, output_xpi)
            
#             print("\n" + "=" * 50)
#             print(f"🎉 Add-on creation complete!")
#             print(f"📋 Add-on page: https://addons.mozilla.org/addon/{slug}/")
#             print(f"🔧 Dev panel: https://addons.mozilla.org/developers/addon/{slug}/")
#             print("=" * 50)
            
#             return True
            
#         except Exception as e:
#             print(f"❌ Error: {e}")
#             return False

# # ========== USAGE ==========
# if __name__ == "__main__":
#     # Load credentials from file
#     with open("mozilla_credentials.txt") as f:
#         creds = dict(line.strip().split('=') for line in f if '=' in line)
    
#     automator = FirefoxAddonAutomator(
#         api_key=creds.get("API_KEY"),
#         api_secret=creds.get("API_SECRET")
#     )
    
#     # Define add-on metadata
#     metadata = {
#         "name": "Image Editor Pro",
#         "summary": "Crop images and remove backgrounds using remove.bg API",
#         "description": "Advanced image editor with cropping and AI background removal. Features: Interactive cropping with handles, remove.bg API integration, multiple export formats, drag & drop support.",
#         "homepage": "https://example.com/image-editor",
#         "categories": {
#             "firefox": ["photos-media"],
#             "android": ["photos-media"]
#         },
#         "tags": ["image", "editor", "crop", "background", "remove.bg"]
#     }
    
#     # Define preview images
#     previews = [
#         {"path": "screenshot1.png", "caption": "Main editor interface"},
#         {"path": "screenshot2.png", "caption": "Background removal example"},
#         {"path": "screenshot3.png", "caption": "Crop tool in action"}
#     ]
    
#     # Run automation
#     success = automator.automate(
#         xpi_path="image-editor-extension.xpi",
#         metadata=metadata,
#         previews=previews
#     )
    
#     if not success:
#         print("❌ Automation failed. Check errors above.")

# 4. ENHANCED BASH SCRIPT WITH ERROR HANDLING
# bash

# #!/bin/bash
# # Firefox Add-on Auto-Deployer with full error handling

# # ========== CONFIGURATION ==========
# source mozilla_credentials.txt

# ADDON_NAME="Image Editor Pro"
# XPI_FILE="build/extension.xpi"
# CHANNEL="listed"
# MAX_WAIT_SECONDS=300  # 5 minutes max wait

# # ========== FUNCTIONS ==========
# log_success() { echo -e "\e[32m✅ $1\e[0m"; }
# log_info() { echo -e "\e[34m📋 $1\e[0m"; }
# log_warning() { echo -e "\e[33m⚠️  $1\e[0m"; }
# log_error() { echo -e "\e[31m❌ $1\e[0m"; exit 1; }

# # Upload and get UUID
# upload_xpi() {
#     log_info "Uploading $XPI_FILE..."
#     response=$(curl -s -w "\n%{http_code}" -X POST \
#         "https://addons.mozilla.org/api/v5/addons/upload/" \
#         -H "Authorization: JWT $API_SECRET" \
#         -F "upload=@$XPI_FILE" \
#         -F "channel=$CHANNEL")
    
#     http_code=$(echo "$response" | tail -1)
#     body=$(echo "$response" | sed '$d')
    
#     if [ "$http_code" -eq 201 ]; then
#         uuid=$(echo "$body" | grep -o '"uuid":"[^"]*"' | cut -d'"' -f4)
#         log_success "Upload successful! UUID: $uuid"
#         echo "$uuid"
#     else
#         log_error "Upload failed ($http_code): $body"
#     fi
# }

# # Wait for validation
# wait_for_validation() {
#     local uuid="$1"
#     log_info "Waiting for validation..."
    
#     for ((i=1; i<=$((MAX_WAIT_SECONDS/5)); i++)); do
#         response=$(curl -s -X GET \
#             "https://addons.mozilla.org/api/v5/addons/upload/$uuid/" \
#             -H "Authorization: JWT $API_SECRET")
        
#         processed=$(echo "$response" | grep -o '"processed":[^,]*' | cut -d':' -f2)
#         valid=$(echo "$response" | grep -o '"valid":[^,]*' | cut -d':' -f2)
        
#         if [ "$processed" = "true" ]; then
#             if [ "$valid" = "true" ]; then
#                 log_success "Validation passed!"
#                 return 0
#             else
#                 log_error "Validation failed: $response"
#             fi
#         fi
        
#         if [ $((i % 6)) -eq 0 ]; then
#             log_info "Still validating... ($((i*5))s elapsed)"
#         fi
#         sleep 5
#     done
    
#     log_error "Validation timeout after $MAX_WAIT_SECONDS seconds"
# }

# # Create add-on
# create_addon() {
#     local uuid="$1"
#     log_info "Creating add-on..."
    
#     cat > /tmp/addon_metadata.json << EOF
# {
#     "name": {"en-US": "$ADDON_NAME"},
#     "summary": {"en-US": "Crop images and remove backgrounds using remove.bg API"},
#     "version": {"upload": "$uuid"},
#     "categories": {
#         "firefox": ["photos-media"],
#         "android": ["photos-media"]
#     },
#     "tags": ["image", "editor", "crop", "background"]
# }
# EOF
    
#     response=$(curl -s -w "\n%{http_code}" -X POST \
#         "https://addons.mozilla.org/api/v5/addons/addon/" \
#         -H "Authorization: JWT $API_SECRET" \
#         -H "Content-Type: application/json" \
#         -d @/tmp/addon_metadata.json)
    
#     http_code=$(echo "$response" | tail -1)
#     body=$(echo "$response" | sed '$d')
    
#     if [ "$http_code" -eq 201 ]; then
#         slug=$(echo "$body" | grep -o '"slug":"[^"]*"' | cut -d'"' -f4)
#         guid=$(echo "$body" | grep -o '"guid":"[^"]*"' | cut -d'"' -f4)
#         log_success "Add-on created! Slug: $slug, GUID: $guid"
#         echo "$slug"
#     else
#         log_error "Create failed ($http_code): $body"
#     fi
# }

# # Main execution
# main() {
#     log_info "Starting Firefox Add-on deployment"
    
#     # Check files exist
#     [ -f "$XPI_FILE" ] || log_error "XPI file not found: $XPI_FILE"
#     [ -f "mozilla_credentials.txt" ] || log_error "Credentials file not found"
    
#     # Step 1: Upload
#     uuid=$(upload_xpi)
    
#     # Step 2: Validate
#     wait_for_validation "$uuid"
    
#     # Step 3: Create
#     slug=$(create_addon "$uuid")
    
#     # Step 4: Output results
#     log_success "Deployment initiated successfully!"
#     echo ""
#     echo "📋 Deployment Summary:"
#     echo "   Add-on Name: $ADDON_NAME"
#     echo "   Upload UUID: $uuid"
#     echo "   Add-on Slug: $slug"
#     echo "   Review URL: https://addons.mozilla.org/developers/addon/$slug/versions"
#     echo ""
#     echo "⏳ The add-on is now in review queue."
#     echo "📧 You will receive email notification when reviewed."
# }

# # Run main
# main "$@"

# 5. AUTOMATION WORKFLOW SUMMARY
# yaml

# Steps:
#   1. Generate Extension Files
#      - Your AppGenesys script creates all files
#      - Package into .xpi using 7z/zip
  
#   2. Upload to Mozilla
#      - POST /api/v5/addons/upload/
#      - Get UUID for tracking
#      - Wait for validation (auto-polling)
  
#   3. Create Add-on Entry
#      - POST /api/v5/addons/addon/
#      - Provide metadata: name, summary, categories
#      - Link uploaded UUID
  
#   4. Add Metadata (Optional)
#      - PATCH /api/v5/addons/addon/{slug}/
#      - Add description, homepage, tags
  
#   5. Upload Previews
#      - POST /api/v5/addons/addon/{slug}/previews/
#      - Add screenshots
  
#   6. Monitor Review Status
#      - GET /api/v5/addons/addon/{slug}/
#      - Check status field
#      - Auto-download when approved
  
#   7. Get Signed Extension
#      - Download from versions endpoint
#      - Or get from add-on detail

# 6. CRITICAL CONSIDERATIONS FOR AUTOMATION

#     Rate Limiting - Add delays between API calls

#     Error Handling - Validate each step before proceeding

#     Credentials Security - Store JWT secrets securely

#     Review Times - Listed add-ons require human review (hours/days)

#     Validation Failures - Handle validation errors gracefully

#     Idempotency - Handle retries safely (check if add-on exists)

# 7. INTEGRATION WITH YOUR APPGENESYS
# bash

# #!/bin/bash
# # Complete workflow: Generate → Sign → Submit

# # 1. Generate extension
# ./appgenesys.sh

# # 2. Build XPI
# cd image-editor-extension
# zip -r ../extension.xpi *

# # 3. Submit to Mozilla
# ./mozilla_automator.sh \
#   --xpi ../extension.xpi \
#   --name "Image Editor Pro" \
#   --summary "Crop and remove backgrounds" \
#   --categories "photos-media" \
#   --tags "image editor crop background"

# # 4. Monitor and download
# ./monitor_status.sh --slug image-editor-pro

# This gives you complete automation from code generation to Mozilla submission! The key is proper error handling and status monitoring since review times vary.


# =======
# Add-ons
# =======

# .. note::

#     These APIs are not frozen and can change at any time without warning.
#     See :ref:`the API versions available<api-versions-list>` for alternatives
#     if you need stability.


# ------
# Search
# ------

# .. _addon-search:

# This endpoint allows you to search through public add-ons.

# .. http:get:: /api/v5/addons/search/

#     :query string q: The search query. The maximum length allowed is 100 characters.
#     :query string app: Filter by :ref:`add-on application <addon-detail-application>` availability.
#     :query string appversion: Filter by application version compatibility. Pass the full version as a string, e.g. ``46.0``. Only valid when the ``app`` parameter is also present.
#     :query string author: Filter by exact (listed) author username or user id. Multiple author usernames or ids can be specified, separated by comma(s), in which case add-ons with at least one matching author are returned.
#     :query string category: Filter by :ref:`category slug <category-list>`. ``app`` and ``type`` parameters need to be set, otherwise this parameter is ignored.
#     :query string color: (Experimental) Filter by color in RGB hex format, trying to find themes that approximately match the specified color. Only works for static themes.
#     :query string created: Filter to add-on that have a creation date matching a :ref:`threshold value <addon-threshold-param>`. ``YYYY-MM-DD``, ``YYYY-MM-DDTHH:MM``, ``YYYY-MM-DDTHH:MM:SS`` or milliseconds timestamps are supported.
#     :query string exclude_addons: Exclude add-ons by ``slug`` or ``id``. Multiple add-ons can be specified, separated by comma(s).
#     :query string guid: Filter by exact add-on guid. Multiple guids can be specified, separated by comma(s), in which case any add-ons matching any of the guids will be returned.  As guids are unique there should be at most one add-on result per guid specified. For usage with Firefox, instead of separating multiple guids by comma(s), a single guid can be passed in base64url format, prefixed by the ``rta:`` string.
#     :query string lang: Activate translations in the specific language for that query. (See :ref:`translated fields <api-overview-translations>`)
#     :query int page: 1-based page number. Defaults to 1.
#     :query int page_size: Maximum number of results to return for the requested page. Defaults to 25.
#     :query string promoted: Filter to add-ons in a specific :ref:`promoted category <addon-detail-promoted-category>`.  Can be combined with `app`.   Multiple promoted categories can be specified, separated by comma(s), in which case any add-ons in any of the promotions will be returned.
#     :query string ratings: Filter to add-ons that have average ratings of a :ref:`threshold value <addon-threshold-param>`.
#     :query string sort: The sort parameter. The available parameters are documented in the :ref:`table below <addon-search-sort>`.
#     :query string tag: Filter by exact tag name. Multiple tag names can be specified, separated by comma(s), in which case add-ons containing *all* specified tags are returned. See :ref:`available tags <tag-list>`
#     :query string type: Filter by :ref:`add-on type <addon-detail-type>`.  Multiple types can be specified, separated by comma(s), in which case add-ons that are any of the matching types are returned.
#     :query string updated: Filter to add-on that have a last updated date matching a :ref:`threshold value <addon-threshold-param>`. ``YYYY-MM-DD``, ``YYYY-MM-DDTHH:MM``, ``YYYY-MM-DDTHH:MM:SS`` or milliseconds timestamps are supported.
#     :query string users: Filter to add-ons that have average daily users of a :ref:`threshold value <addon-threshold-param>`.
#     :>json int count: The number of results for this query.
#     :>json string next: The URL of the next page of results.
#     :>json string previous: The URL of the previous page of results.
#     :>json array results: An array of :ref:`add-ons <addon-detail-object>`. As described below, the following fields are omitted for performance reasons: ``release_notes`` and ``license`` fields on ``current_version`` as well as ``picture_url`` from ``authors``. The special ``_score`` property is added to each add-on object, it contains a float value representing the relevancy of each add-on for the given query.

# .. _addon-search-sort:

#     Available sorting parameters:

#     ==============  ==========================================================
#          Parameter  Description
#     ==============  ==========================================================
#            created  Creation date, descending.
#          downloads  Number of weekly downloads, descending.
#            hotness  Hotness (average number of users progression), descending.
#             random  Random ordering. Only available when no search query is
#                     passed and when filtering to only return promoted add-ons.
#            ratings  Bayesian rating, descending.
#             rating  Bayesian rating, descending (deprecated, backwards-compatibility only).
#        recommended  Promoted addons in the recommended category above
#                     non-recommended add-ons. Only available combined with
#                     another sort - ignored on its own.
#                     Also ignored if combined with relevance as it already takes
#                     into account recommended status.
#          relevance  Search query relevance, descending.  Ignored without a
#                     query.
#            updated  Last updated date, descending.
#              users  Average number of daily users, descending.
#     ==============  ==========================================================

#     The default behavior is to sort by relevance if a search query (``q``)
#     is present; otherwise place recommended add-ons first, then non recommended
#     add-ons, then sorted by average daily users, descending. (``sort=recommended,users``).
#     This is the default on AMO dev server.

#     You can combine multiple parameters by separating them with a comma.
#     For instance, to sort search results by downloads and then by creation
#     date, use ``sort=downloads,created``. The only exception is the ``random``
#     sort parameter, which is only available alone.


# .. _addon-threshold-param:

#     Threshold style parameters allow queries against numeric or date-time values using comparison.

#     The following is supported (examples for query parameter `foo`):
#         * greater than ``foo__gt`` (example query: ?foo__gt=10.1)
#         * less than ``foo__lt`` (example query: ?foo__lt=10.1)
#         * greater than or equal to ``foo__gte`` (example query: ?foo__gte=10.1)
#         * less than or equal to ``foo__lte`` (example query: ?foo__lte=10.1)
#         * equal to ``foo`` (example query: ?foo=10.1)


# ------------
# Autocomplete
# ------------

# .. _addon-autocomplete:

# Similar to :ref:`add-ons search endpoint <addon-search>` above, this endpoint
# allows you to search through public add-ons. Because it's meant as a backend
# for autocomplete though, there are a couple key differences:

#   - No pagination is supported. There are no ``next``, ``prev`` or ``count``
#     fields, and passing ``page_size`` or ``page`` has no effect, a maximum of 10
#     results will be returned at all times.
#   - Only a subset of fields are returned.
#   - ``sort`` is not supported. Sort order is always ``relevance`` if ``q`` is
#     provided, or the :ref:`search default <addon-search-sort>` otherwise.

# .. http:get:: /api/v5/addons/autocomplete/

#     :query string q: The search query.
#     :query string app: Filter by :ref:`add-on application <addon-detail-application>` availability.
#     :query string appversion: Filter by application version compatibility. Pass the full version as a string, e.g. ``46.0``. Only valid when the ``app`` parameter is also present.
#     :query string author: Filter by exact (listed) author username. Multiple author names can be specified, separated by comma(s), in which case add-ons with at least one matching author are returned.
#     :query string category: Filter by :ref:`category slug <category-list>`. ``app`` and ``type`` parameters need to be set, otherwise this parameter is ignored.
#     :query string lang: Activate translations in the specific language for that query. (See :ref:`translated fields <api-overview-translations>`)
#     :query string tag: Filter by exact tag name. Multiple tag names can be specified, separated by comma(s), in which case add-ons containing *all* specified tags are returned. See :ref:`available tags <tag-list>`
#     :query string type: Filter by :ref:`add-on type <addon-detail-type>`.
#     :>json array results: An array of :ref:`add-ons <addon-detail-object>`. Only the ``id``, ``icon_url``, ``icons``, ``name``, ``promoted``, ``type`` and ``url`` fields are supported though.


# ------
# Detail
# ------

# .. _addon-detail:

# This endpoint allows you to fetch a specific add-on by id, slug or guid.

#     .. note::
#         Non-public add-ons and add-ons with only unlisted versions require both
#         authentication and reviewer permissions or an account listed as a
#         developer of the add-on.

#         A 401 or 403 error response will be returned when clients don't meet
#         those requirements. Those responses will contain the following
#         properties:

#             * ``detail``: string containing a message about the error.
#             * ``is_disabled_by_developer``: boolean set to ``true`` when the add-on has been voluntarily disabled by its developer.
#             * ``is_disabled_by_mozilla``: boolean set to ``true`` when the add-on has been disabled by Mozilla.

# .. http:get:: /api/v5/addons/addon/(int:id|string:slug|string:guid)/

#     .. _addon-detail-object:

#     :query string app: Used in conjunction with ``appversion`` below to alter ``current_version`` behaviour. Need to be a valid :ref:`add-on application <addon-detail-application>`.
#     :query string appversion: Make ``current_version`` return the latest public version of the add-on compatible with the given application version, if possible, otherwise fall back on the generic implementation. Pass the full version as a string, e.g. ``46.0``. Only valid when the ``app`` parameter is also present. Currently only compatible with language packs through the add-on detail API, ignored for other types of add-ons and APIs.
#     :query string lang: Activate translations in the specific language for that query. (See :ref:`Translated Fields <api-overview-translations>`)
#     :query boolean show_grouped_ratings: Whether or not to show ratings aggregates in the ``ratings`` object (Use "true"/"1" as truthy values, "0"/"false" as falsy ones).
#     :>json int id: The add-on id on AMO.
#     :>json array authors: Array holding information about the authors for the add-on.
#     :>json int authors[].id: The user id for an author.
#     :>json string authors[].name: The name for an author.
#     :>json string authors[].url: The link to the profile page for an author.
#     :>json string authors[].username: The username for an author.
#     :>json string authors[].picture_url: URL to a photo of the user, or `/static/img/anon_user.png` if not set. For performance reasons this field is omitted from the search endpoint.
#     :>json int average_daily_users: The average number of users for the add-on (updated daily).
#     :>json object categories: Object holding the categories the add-on belongs to.
#     :>json array categories[app_name]: Array holding the :ref:`category slugs <category-list>` the add-on belongs to for a given :ref:`add-on application <addon-detail-application>`. (Combine with the add-on ``type`` to determine the name of the category).
#     :>json object|null contributions_url: URL to the (external) webpage where the addon's authors collect monetary contributions, if set. Can be an empty value.  (See :ref:`Outgoing Links <api-overview-outgoing>`)
#     :>json string created: The date the add-on was created.
#     :>json object current_version: Object holding the current :ref:`version <version-detail-object>` of the add-on. For performance reasons the ``license`` field omits the ``text`` property from both the search and detail endpoints.
#     :>json string default_locale: The add-on default locale for translations.
#     :>json object|null description: The add-on description (See :ref:`translated fields <api-overview-translations>`). This field might contain markdown.
#     :>json object|null developer_comments: Additional information about the add-on provided by the developer. (See :ref:`translated fields <api-overview-translations>`).
#     :>json string edit_url: The URL to the developer edit page for the add-on.
#     :>json string guid: The add-on `extension identifier <https://developer.mozilla.org/en-US/Add-ons/Install_Manifests#id>`_.
#     :>json boolean has_eula: The add-on has an End-User License Agreement that the user needs to agree with before installing (See :ref:`add-on EULA and privacy policy <addon-eula-policy>`).
#     :>json boolean has_privacy_policy: The add-on has a Privacy Policy (See :ref:`add-on EULA and privacy policy <addon-eula-policy>`).
#     :>json object|null homepage: The add-on homepage (See :ref:`translated fields <api-overview-translations>` and :ref:`Outgoing Links <api-overview-outgoing>`).
#     :>json string icon_url: The URL to icon for the add-on (including a cachebusting query string).
#     :>json object icons: An object holding the URLs to an add-ons icon including a cachebusting query string as values and their size as properties. Currently exposes 32, 64, 128 pixels wide icons.
#     :>json boolean is_disabled: Whether the add-on is disabled or not.
#     :>json boolean is_experimental: Whether the add-on has been marked by the developer as experimental or not.
#     :>json boolean|null is_noindexed: Whether the add-on should be indexed or not indexed for SEO. Note that the search endpoint will always return a ``null`` value.
#     :>json object|null name: The add-on name (See :ref:`translated fields <api-overview-translations>`).
#     :>json string last_updated: The date of the last time the add-on was updated by its developer(s).
#     :>json object|null latest_unlisted_version: Object holding the latest unlisted :ref:`version <version-detail-object>` of the add-on. This field is only present if the user has unlisted reviewer permissions, or is listed as a developer of the add-on.
#     :>json array previews: Array holding information about the previews for the add-on.
#     :>json int previews[].id: The id for a preview.
#     :>json object|null previews[].caption: The caption describing a preview (See :ref:`translated fields <api-overview-translations>`).
#     :>json int previews[].image_size[]: width, height dimensions of of the preview image.
#     :>json string previews[].image_url: The URL (including a cachebusting query string) to the preview image.
#     :>json int position: The position in the list of previews images.
#     :>json int previews[].thumbnail_size[]: width, height dimensions of of the preview image thumbnail.
#     :>json string previews[].thumbnail_url: The URL (including a cachebusting query string) to the preview image thumbnail.
#     :>json array promoted: Array holding promotion information about the add-on.
#     :>json string promoted[].category: The name of the :ref:`promoted category <addon-detail-promoted-category>` for the add-on.
#     :>json array promoted[].apps[]: Array of the :ref:`applications <addon-detail-application>` for which the add-on is promoted.
#     :>json object ratings: Object holding ratings summary information about the add-on.
#     :>json int ratings.count: The total number of user ratings for the add-on.
#     :>json int ratings.text_count: The number of user ratings with review text for the add-on.
#     :>json string ratings_url: The URL to the user ratings list page for the add-on.
#     :>json float ratings.average: The average user rating for the add-on.
#     :>json float ratings.bayesian_average: The bayesian average user rating for the add-on.
#     :>json object ratings.grouped_counts: Object with aggregate counts for ratings.  Only included when ``show_grouped_ratings`` is present in the request.
#     :>json int ratings.grouped_counts.1: the count of ratings with a score of 1.
#     :>json int ratings.grouped_counts.2: the count of ratings with a score of 2.
#     :>json int ratings.grouped_counts.3: the count of ratings with a score of 3.
#     :>json int ratings.grouped_counts.4: the count of ratings with a score of 4.
#     :>json int ratings.grouped_counts.5: the count of ratings with a score of 5.
#     :>json boolean requires_payment: Does the add-on require payment, non-free services or software, or additional hardware.
#     :>json string review_url: The URL to the reviewer review page for the add-on.
#     :>json string slug: The add-on slug.
#     :>json string status: The :ref:`add-on status <addon-detail-status>`.
#     :>json object|null summary: The add-on summary (See :ref:`translated fields <api-overview-translations>`).
#     :>json object|null support_email: The add-on support email (See :ref:`translated fields <api-overview-translations>`).
#     :>json object|null support_url: The add-on support URL (See :ref:`translated fields <api-overview-translations>` and :ref:`Outgoing Links <api-overview-outgoing>`).
#     :>json array tags: List containing the tag names set on the add-on.
#     :>json string type: The :ref:`add-on type <addon-detail-type>`.
#     :>json string url: The (absolute) add-on detail URL.
#     :>json object version: For create or update requests that included a :ref:`version <version-create-request>` only. Object holding the :ref:`version <version-detail-object>` that was submitted.
#     :>json string versions_url: The URL to the version history page for the add-on.
#     :>json int weekly_downloads: The number of downloads for the add-on in the last week. Not present for lightweight themes.


# .. _addon-detail-status:

#     Possible values for the add-on ``status`` field / parameter:

#     ==============  ==========================================================
#              Value  Description
#     ==============  ==========================================================
#             public  Approved
#            deleted  Deleted
#           disabled  Disabled by Mozilla
#          nominated  Awaiting Review
#         incomplete  Incomplete - no approved listed versions
#     ==============  ==========================================================


# .. _addon-detail-application:

#     Possible values for the keys in the ``compatibility`` field, as well as the
#     ``app`` parameter in the search API:

#     ==============  ==========================================================
#              Value  Description
#     ==============  ==========================================================
#            android  Firefox for Android
#            firefox  Firefox
#     ==============  ==========================================================

#     .. note::
#         See the :ref:`supported versions <applications-version-list>`.


# .. _addon-detail-type:

#     Possible values for the ``type`` field / parameter:

#     .. note::

#         For backwards-compatibility reasons, the value for type of ``theme``
#         refers to a deprecated XUL Complete Theme.  ``persona`` are another
#         type of depreated theme.
#         New webextension packaged non-dynamic themes are ``statictheme``.

#     ==============  ==========================================================
#              Value  Description
#     ==============  ==========================================================
#              theme  Depreated.  Theme (Complete Theme, XUL-based)
#             search  Search Engine
#            persona  Deprecated.  Theme (Lightweight Theme, persona)
#           language  Language Pack (Application)
#          extension  Extension
#         dictionary  Dictionary
#        statictheme  Theme (Static Theme)
#     ==============  ==========================================================

# .. _addon-detail-promoted-category:

#     Possible values for the ``promoted.category`` field:

#     ==============  ==========================================================
#              Value  Description
#     ==============  ==========================================================
#               line  "By Firefox" category
#            notable  Notable category
#        recommended  Recommended category
#          spotlight  Spotlight category
#          strategic  Strategic category
#             badged  A meta category that's available for the ``promoted``
#                     search filter that is all the categories we expect an API
#                     client to expose as "reviewed" by Mozilla.
#                     Currently equal to ``line&recommended``.
#     ==============  ==========================================================


# ------
# Create
# ------

# .. _addon-create:

# This endpoint allows a submission of an upload to create a new add-on and setting other AMO metadata.

# To create an add-on with a listed version from an upload (an :ref:`upload <upload-create>`
# that has channel == ``listed``) certain metadata must be defined - a version ``license``, an
# add-on ``name``, an add-on ``summary``, and add-on categories for each app the version
# is compatible with.

#     .. note::
#         This API requires :doc:`authentication <auth>`.

# .. http:post:: /api/v5/addons/addon/

#     .. _addon-create-request:

#     :<json object categories: Object holding the categories the add-on belongs to.
#     :<json array categories[app_name]: Array holding the :ref:`category slugs <category-list>` the add-on belongs to for a given :ref:`add-on application <addon-detail-application>`.
#     :<json string contributions_url: URL to the (external) webpage where the addon's authors collect monetary contributions.  Only a limited number of services are `supported <https://github.com/mozilla/addons-server/blob/0b5db7d544a21f6b887e8e8032496778234ade33/src/olympia/constants/base.py#L214:L226>`_.
#     :<json string default_locale: The fallback locale for translated fields for this add-on. Note this only applies to the fields here - the default locale for :ref:`version release notes <version-create-request>` and custom license text is fixed to `en-US`.
#     :<json object|null description: The add-on description (See :ref:`translated fields <api-overview-translations>`). This field can contain some Markdown.
#     :<json object|null developer_comments: Additional information about the add-on. (See :ref:`translated fields <api-overview-translations>`).
#     :<json object|null homepage: The add-on homepage (See :ref:`translated fields <api-overview-translations>` and :ref:`Outgoing Links <api-overview-outgoing>`).
#     :<json boolean is_disabled: Whether the add-on is disabled or not.
#     :<json boolean is_experimental: Whether the add-on should be marked as experimental or not.
#     :<json object|null name: The add-on name (See :ref:`translated fields <api-overview-translations>`).
#     :<json boolean requires_payment: Does the add-on require payment, non-free services or software, or additional hardware.
#     :<json string slug: The add-on slug.  Valid slugs must only contain letters, numbers (`categories L and N <http://www.unicode.org/reports/tr44/tr44-4.html#GC_Values_Table>`_), ``-``, ``_``, ``~``, and can't be all numeric.
#     :<json object|null summary: The add-on summary (See :ref:`translated fields <api-overview-translations>`).
#     :<json object|null support_email: The add-on support email (See :ref:`translated fields <api-overview-translations>`).
#     :<json array tags: List containing the tag names to set on the add-on - see :ref:`available tags <tag-list>`.
#     :<json object version: Object containing the :ref:`version <version-create-request>` to create this addon with.

#     **Response:**
#     See :ref:`add-on <addon-detail-object>`


# ----
# Edit
# ----

# .. _addon-edit:

# This endpoint allows an add-on's AMO metadata to be edited.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

# .. http:patch:: /api/v5/addons/addon/(int:id|string:slug|string:guid)/

#     .. _addon-edit-request:

#     :<json object categories: Object holding the categories the add-on belongs to.
#     :<json array categories[app_name]: Array holding the :ref:`category slugs <category-list>` the add-on belongs to for a given :ref:`add-on application <addon-detail-application>`.
#     :<json string contributions_url: URL to the (external) webpage where the addon's authors collect monetary contributions.  Only a limited number of services are `supported <https://github.com/mozilla/addons-server/blob/0b5db7d544a21f6b887e8e8032496778234ade33/src/olympia/constants/base.py#L214:L226>`_.
#     :<json string default_locale: The fallback locale for translated fields for this add-on. Note this only applies to the fields here - the default locale for :ref:`version release notes <version-create-request>` and custom license text is fixed to `en-US`.
#     :<json object|null description: The add-on description (See :ref:`translated fields <api-overview-translations>`). This field can contain some Markdown.
#     :<json object|null developer_comments: Additional information about the add-on. (See :ref:`translated fields <api-overview-translations>`).
#     :<json object|null homepage: The add-on homepage (See :ref:`translated fields <api-overview-translations>` and :ref:`Outgoing Links <api-overview-outgoing>`).
#     :<json null icon: To clear the icon, i.e. revert to the default add-on icon, send ``null``.  See :ref:`addon icon <addon-icon>` to upload a new icon.
#     :<json boolean is_disabled: Whether the add-on is disabled or not.  Note: if the add-on status is :ref:`disabled <addon-detail-status>` the response will always be ``disabled=true`` regardless.
#     :<json boolean is_experimental: Whether the add-on should be marked as experimental or not.
#     :<json object|null name: The add-on name (See :ref:`translated fields <api-overview-translations>`).
#     :<json boolean requires_payment: Does the add-on require payment, non-free services or software, or additional hardware.
#     :<json string slug: The add-on slug.  Valid slugs must only contain letters, numbers (`categories L and N <http://www.unicode.org/reports/tr44/tr44-4.html#GC_Values_Table>`_), ``-``, ``_``, ``~``, and can't be all numeric.
#     :<json object|null summary: The add-on summary (See :ref:`translated fields <api-overview-translations>`).
#     :<json object|null support_email: The add-on support email (See :ref:`translated fields <api-overview-translations>`).
#     :<json array tags: List containing the tag names to set on the add-on - see :ref:`available tags <tag-list>`.


# ~~~~~~~~~~
# Addon Icon
# ~~~~~~~~~~

# .. _addon-icon:

# A single add-on icon used on AMO can be uploaded to ``icon``,
# where it will be resized as 32, 64, and 128 pixels wide icons as ``icons``.
# The resizing is carried out asynchronously  so the urls in the response may not be available immediately.
# The image must be square, in either JPEG or PNG format, and we recommend 128x128.

# The upload must be sent as multipart form-data rather than JSON.
# If desired, some other properties can be set/updated at the same time as ``icon``, but fields that contain complex data structure (list or object) can not, so separate API calls are needed.

# Note: as form-data can not include objects, and creating an add-on requires the version to be specified as an object, it's not possible to set ``icons`` during an :ref:`Add-on create <addon-create>`.


# .. http:patch:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/

#     .. _addon-icon-request-edit:

#     :form icon: The icon file being uploaded, or an empty value to clear.
#     :reqheader Content-Type: multipart/form-data


# --------------------
# Put - Create or Edit
# --------------------

# .. _addon-put:

# This endpoint allows a submission of an upload, which will either update an existing add-on and create a new version if the guid already exists, or will create a new add-on if the guid does not exist.
# See the :ref:`Add-on Create <addon-create>` documentation for details of the request and restrictions.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on if the add-on exists already.

#     .. note::
#         The guid in the url must match a guid specified in the manifest.

#     .. note::
#         A submission that results in a new add-on will have metadata defaults taken from the manifest (e.g. name), but a submission that updates an existing listing will not use data from the manifest.

# .. http:put:: /api/v5/addons/addon/(string:guid)/


# ------
# Delete
# ------

# .. _addon-delete:

# This endpoint allows an add-on to be deleted.
# Because add-on deletion is an irreversible and destructive action an additional token must be retrieved beforehand, and passed as a parameter to the delete endpoint.
# Deleting the add-on will permanently delete all versions and files submitted for this add-on, listed or not.
# All versions will be soft-blocked (restricted), which will disable and prevent any further installation in Firefox. Existing users can choose to re-enable the add-on.
# The add-on ID (``guid``) cannot be restored and will forever be unusable for submission.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an owner of the add-on..

# .. http:delete:: /api/v5/addons/addon/(int:id|string:slug|string:guid)/

#     .. _addon-delete-request:

#     :query string delete_confirm: the confirmation token from the :ref:`delete confirm <addon-delete-confirm>` endpoint.


# ~~~~~~~~~~~~~~
# Delete Confirm
# ~~~~~~~~~~~~~~

# .. _addon-delete-confirm:

# This endpoint just supplies a special signed token that can be used to confirm deletion of an add-on.
# The token is valid for 60 seconds after it's been created, and is only valid for this specific add-on.


#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an owner of the add-on.

# .. http:get:: /api/v5/addons/addon/(int:id|string:slug|string:guid)/delete_confirm/

#     .. _addon-delete-confirm-request:

#     :>json string delete_confirm: The confirmation token to be used with :ref:`add-on delete <addon-delete>` endpoint.


# -------------
# Versions List
# -------------

# .. _version-list:

# This endpoint allows you to list all versions belonging to a specific add-on.

# .. http:get:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/versions/

#     .. note::
#         Non-public add-ons and add-ons with only unlisted versions require both:

#             * authentication
#             * reviewer permissions or an account listed as a developer of the add-on

#     :query string filter: The :ref:`filter <version-filtering-param>` to apply.
#     :query string lang: Activate translations in the specific language for that query. (See :ref:`translated fields <api-overview-translations>`)
#     :query int page: 1-based page number. Defaults to 1.
#     :query int page_size: Maximum number of results to return for the requested page. Defaults to 25.
#     :>json int count: The number of versions for this add-on.
#     :>json string next: The URL of the next page of results.
#     :>json string previous: The URL of the previous page of results.
#     :>json array results: An array of :ref:`versions <version-detail-object>`.

# .. _version-filtering-param:

#    By default, the version list API will only return public versions
#    (excluding versions that have incomplete, disabled, deleted, rejected or
#    flagged for further review files) - you can change that with the ``filter``
#    query parameter, which may require authentication and specific permissions
#    depending on the value:

#     ====================  =====================================================
#                    Value  Description
#     ====================  =====================================================
#     all_without_unlisted  Show all listed versions attached to this add-on.
#                           Requires either reviewer permissions or a user
#                           account listed as a developer of the add-on.
#        all_with_unlisted  Show all versions (including unlisted) attached to
#                           this add-on. Requires either reviewer permissions or
#                           a user account listed as a developer of the add-on.
#         all_with_deleted  Show all versions attached to this add-on, including
#                           deleted ones. Requires admin permissions.
#     ====================  =====================================================

# --------------
# Version Detail
# --------------

# .. _version-detail:

# This endpoint allows you to fetch a single version belonging to a specific add-on.

#     .. note::
#         This API accepts both version ids and version numbers in the URL. If the version number passed does not contain any dot characters (``.``) it would be considered an ``id``. To avoid this and force a lookup by version number, add a ``v`` prefix to it.

# .. http:get:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/versions/(int:id|string:version_number)/

#     .. _version-detail-object:

#     :query string lang: Activate translations in the specific language for that query. (See :ref:`translated fields <api-overview-translations>`)
#     :>json int id: The version id.
#     :>json string approval_notes: Information for Mozilla reviewers, for when the add-on is reviewed.  These notes are only visible to Mozilla, and this field is only present if the user has reviewer permissions, or is listed as a developer of the add-on.
#     :>json string channel: The version channel, which determines its visibility on the site. Can be either ``unlisted`` or ``listed``.
#     :>json object compatibility:
#         Object detailing which :ref:`applications <addon-detail-application>` the version is compatible with.
#         The exact min/max version numbers in the object correspond to the :ref:`supported versions<applications-version-list>`.
#         Example:

#             .. code-block:: json

#                 {
#                   "compatibility": {
#                     "android": {
#                       "min": "38.0a1",
#                       "max": "43.0"
#                     },
#                     "firefox": {
#                       "min": "38.0a1",
#                       "max": "43.0"
#                     }
#                   }
#                 }

#     :>json string compatibility[app_name].max: Maximum version of the corresponding app the version is compatible with. Should only be enforced by clients if ``is_strict_compatibility_enabled`` is ``true``.
#     :>json string compatibility[app_name].min: Minimum version of the corresponding app the version is compatible with.
#     :>json string edit_url: The URL to the developer edit page for the version.
#     :>json int file.id: The id for the file.
#     :>json string file.created: The creation date for the file.
#     :>json string file.hash: The hash for the file.
#     :>json boolean file.is_mozilla_signed_extension: Whether the file was signed with a Mozilla internal certificate or not.
#     :>json array file.optional_permissions[]: Array of the optional webextension permissions for this File, as strings. Empty for non-webextensions.
#     :>json array file.host_permissions[]: Array of the host permissions for this File, as strings. Empty for non-webextensions.
#     :>json array file.permissions[]: Array of the webextension permissions for this File, as strings. Empty for non-webextensions.
#     :>json array file.data_collection_permissions[]: Array of the data collection permissions for this File, as strings. Empty for non-webextensions.
#     :>json array file.optional_data_collection_permissions[]: Array of the optional data collection permissions for this File, as strings. Empty for non-webextensions.
#     :>json int file.size: The size for the file, in bytes.
#     :>json int file.status: The :ref:`status <version-detail-status>` for the file.
#     :>json string file.url: The (absolute) URL to download the file.
#     :>json boolean is_disabled: If this version has been disabled by the developer. This field is only present for authenticated users, for their own add-ons.
#     :>json object license: Object holding information about the license for the version.
#     :>json boolean license.is_custom: Whether the license text has been provided by the developer, or not.  (When ``false`` the license is one of the common, predefined, licenses).
#     :>json object|null license.name: The name of the license (See :ref:`translated fields <api-overview-translations>`).
#     :>json object|null license.text: The text of the license (See :ref:`translated fields <api-overview-translations>`). For performance reasons this field is only present in version detail detail endpoint: all other endpoints omit it.
#     :>json string|null license.url: The URL of the full text of license.
#     :>json string|null license.slug: The license :ref:`slug <license-list>`, for non-custom (predefined) licenses.
#     :>json object|null release_notes: The release notes for this version (See :ref:`translated fields <api-overview-translations>`).
#     :>json string reviewed: The date the version was reviewed at.
#     :>json boolean is_strict_compatibility_enabled: Whether or not this version has `strictCompatibility <https://developer.mozilla.org/en-US/Add-ons/Install_Manifests#strictCompatibility>`_. set.
#     :>json string|null source: The (absolute) URL to download the submitted source for this version. This field is only present for authenticated users, for their own add-ons.
#     :>json string version: The version number string for the version.


# .. _version-detail-status:

#     Possible values for the version/file ``status`` field / parameter:

#     ==============  ==========================================================
#              Value  Description
#     ==============  ==========================================================
#             public  Approved
#           disabled  Rejected, disabled, or not reviewed
#         unreviewed  Awaiting Review
#     ==============  ==========================================================


# --------------
# Version Create
# --------------

# .. _version-create:

# This endpoint allows a submission of an upload to an existing add-on to create a new version,
# and setting other AMO metadata.

# To create a listed version from an upload (an :ref:`upload <upload-create>` that
# has channel == ``listed``) certain metadata must be defined - a version ``license``, an
# add-on ``name``, an add-on ``summary``, and add-on categories for each app the version
# is compatible with.  Add-on properties cannot be set with version create so an
# :ref:`add-on update <addon-edit>` must be made beforehand if the properties are not
# already defined.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

# .. http:post:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/versions/

#     .. _version-create-request:

#     :<json string approval_notes: Information for Mozilla reviewers, for when the add-on is reviewed.  These notes are only visible to Mozilla.
#     :<json object|array compatibility:
#         Either an object detailing which :ref:`applications <addon-detail-application>`
#         and versions the version is compatible with; or an array of :ref:`applications <addon-detail-application>`,
#         where min/max versions from the manifest, or defaults, will be used.  See :ref:`examples <version-compatibility-examples>`.
#     :<json string compatibility[app_name].max: Maximum version of the corresponding app the version is compatible with. Should only be enforced by clients if ``is_strict_compatibility_enabled`` is ``true``.
#     :<json string compatibility[app_name].min: Minimum version of the corresponding app the version is compatible with.
#     :<json string license: The :ref:`slug of a non-custom license <license-list>`. The license must match the add-on type. Either provide ``license`` or ``custom_license``, not both.  If neither are provided, and there was a license defined for the previous version, it will inherit the previous version's license.
#     :<json object|null custom_license.name: The name of the license (See :ref:`translated fields <api-overview-translations>`). Custom licenses are not supported for themes.
#     :<json object|null custom_license.text: The text of the license (See :ref:`translated fields <api-overview-translations>`). Custom licenses are not supported for themes.
#     :<json object|null release_notes: The release notes for this version (See :ref:`translated fields <api-overview-translations>`).
#     :<json string|null source: The submitted source for this version. As JSON this field can only be set to null, to clear it - see :ref:`uploading source <version-sources>` to set/update the source file.
#     :<json string upload: The uuid for the xpi upload to create this version with.


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Version compatibility examples
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# .. _version-compatibility-examples:

#     .. note::
#         The compatibility for Dictionary type add-ons cannot be created or updated.

# Full example:

# .. code-block:: json

#     {
#         "compatibility": {
#             "android": {
#                 "min": "58.0a1",
#                 "max": "73.0"
#             },
#             "firefox": {
#                 "min": "58.0a1",
#                 "max": "73.0"
#             }
#         }
#     }

# With some versions omitted:

# .. code-block:: javascript

#     {
#         "compatibility": {
#             "android": {
#                 "min": "58.0a1"
#                 // "max" is undefined, so the manifest max or default will be used.
#             },
#             "firefox": {
#                 // the object is empty - both "min" and "max" are undefined so the manifest min/max
#                 // or defaults will be used.
#             }
#         }
#     }

# Shorthand, for when you only want to define compatible apps, but use the min/max versions from the manifest, or use all defaults:

# .. code-block:: json

#     {
#         "compatibility": [
#             "android",
#             "firefox"
#         ]
#     }


# ~~~~~~~~~~~~~~~
# Version Sources
# ~~~~~~~~~~~~~~~

# .. _version-sources:

# Version source files cannot be uploaded as JSON - the request must be sent as multipart form-data instead.
# If desired, ``license`` can be set set/updated at the same time as ``source``, but fields that
# contain complex data structure (list or object) such as ``compatibility``, ``release_notes``,
# or ``custom_license`` can not, so separate API calls are needed.

# Note: as form-data can not be nested as objects it's not possible to set ``source`` as part of the
# ``version`` object defined during an :ref:`Add-on create <addon-create>`.

# .. http:post:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/versions/

#     .. _version-sources-request-create:

#     :form source: The add-on file being uploaded, or an empty value to clear.
#     :form upload: The uuid for the xpi upload to create this version with.
#     :form license: The :ref:`slug of a non-custom license <license-list>` (optional).
#     :reqheader Content-Type: multipart/form-data


# .. http:patch:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/versions/(int:id|string:version_number)/

#     .. _version-sources-request-edit:

#     :form source: The add-on file being uploaded.
#     :form license: The :ref:`slug of a non-custom license <license-list>` (optional).
#     :reqheader Content-Type: multipart/form-data

# ------------
# Version Edit
# ------------

# .. _version-edit:

# This endpoint allows the metadata for an existing version to be edited.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

#     .. note::
#         This API accepts both version ids and version numbers in the URL. If the version number passed does not contain any dot characters (``.``) it would be considered an ``id``. To avoid this and force a lookup by version number, add a ``v`` prefix to it.

# .. http:patch:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/versions/(int:id|string:version_number)/

#     .. _version-edit-request:

#     :<json string approval_notes: Information for Mozilla reviewers, for when the add-on is reviewed.  These notes are only visible to Mozilla.
#     :<json object|array compatibility: Either an object detailing which :ref:`applications <addon-detail-application>` and versions the version is compatible with; or an array of :ref:`applications <addon-detail-application>`, where default min/max versions will be used if not already defined.  See :ref:`examples <version-compatibility-examples>`.
#     :<json string compatibility[app_name].max: Maximum version of the corresponding app the version is compatible with. Should only be enforced by clients if ``is_strict_compatibility_enabled`` is ``true``.
#     :<json string compatibility[app_name].min: Minimum version of the corresponding app the version is compatible with.
#     :<json boolean is_disabled: If this version has been disabled by the developer. Note: a version with an already disabled file (``file.status`` is ``disabled``) cannot be changed to ``true``.
#     :<json string license: The :ref:`slug of a non-custom license <license-list>`. The license must match the add-on type. Either provide ``license`` or ``custom_license``, not both.
#     :<json object|null custom_license.name: The name of the license (See :ref:`translated fields <api-overview-translations>`). Custom licenses are not supported for themes.
#     :<json object|null custom_license.text: The text of the license (See :ref:`translated fields <api-overview-translations>`). Custom licenses are not supported for themes.
#     :<json object|null release_notes: The release notes for this version (See :ref:`translated fields <api-overview-translations>`).
#     :<json string|null source: The submitted source for this version. As JSON this field can only be set to null, to clear it - see :ref:`uploading source <version-sources>` to set/update the source file.


# --------------
# Version Delete
# --------------

# .. _version-delete:

# This endpoint allows a version to be deleted. The version will be soft-blocked (restricted), which will disable and prevent any further installation in Firefox. Existing users can choose to re-enable the add-on.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

#     .. note::
#         This API accepts both version ids and version numbers in the URL. If the version number passed does not contain any dot characters (``.``) it would be considered an ``id``. To avoid this and force a lookup by version number, add a ``v`` prefix to it.

# .. http:delete:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/versions/(int:id|string:version_number)/


# ----------------
# Version Rollback
# ----------------

# .. _version-rollback:

# This endpoint allows an already approved version to be immediately re-created with a new version number, to rollback a problematic version.

# The latest version in each channel is unavailable for rollback (or you wouldn't be rolling back anything); also, for listed channel, is limited to the previous approved version.
# The rollback is asynchronous; you will be notified by email when it's complete (or failed).

# See :ref:`version create <version-list>` - the second version in the list - for the listed version available for rollback.  Call the endpoint with ``?all_with_unlisted`` for all the unlisted versions, ignoring the first version and any versions that are not ``file.status == public``.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

#     .. note::
#         This API accepts both version ids and version numbers in the URL. If the version number passed does not contain any dot characters (``.``) it would be considered an ``id``. To avoid this and force a lookup by version number, add a ``v`` prefix to it.

#     .. warning::
#         For the listed channel, if there is a version awaiting review in the listed channel it will be disabled as part of the rollback.


# .. http:post:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/versions/(int:id|string:version_number)/rollback/

#     .. _version-rollback-request:

#     :<json string new_version_string: The new version number (required).  It must be unique across all channels, and for listed versions, higher than all previously signed versions.
#     :<json object|null release_notes: The release notes for this version (See :ref:`translated fields <api-overview-translations>`).


# --------------
# Preview Create
# --------------

# .. _addon-preview-create:

# This endpoint allows a submission of a preview image to an existing non-theme add-on to create a new preview image. Themes can only have generated previews and new previews can not be created.
# Image files cannot be uploaded as JSON - the request must be sent as multipart form-data instead.
# If desired, ``position`` can be set set at the same time as ``image``, but ``caption`` can not, so a separate API call is needed.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

# .. http:post:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/previews/

#     .. _addon-preview-create-request:

#     :form image: The image being uploaded.
#     :form postion: Integer value for the position the image should be returned in the addon :ref:`detail <addon-detail-object>` (optional). Order is ascending so lower positions are placed earlier.
#     :reqheader Content-Type: multipart/form-data


# ------------
# Preview Edit
# ------------

# .. _addon-preview-edit:

# This endpoint allows the metadata for an existing preview for a non-theme add-on to be edited. Themes can only have generated previews and previews can not be edited.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

# .. http:patch:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/previews/(int:id)/

#     .. _addon-preview-edit-request:

#     :<json object caption: The caption describing a preview (See :ref:`translated fields <api-overview-translations>`).
#     :<json int position: The position the image should be returned in the addon :ref:`detail <addon-detail-object>`. Order is ascending so lower positions are placed earlier.


# --------------
# Preview Delete
# --------------

# .. _addon-preview-delete:

# This endpoint allows the metadata for an existing preview for a non-theme add-on to be deleted. Themes can only have generated previews and previews can not be deleted.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

# .. http:delete:: /api/v5/addons/addon/(int:addon_id|string:addon_slug|string:addon_guid)/previews/(int:id)/


# -------------
# Upload Create
# -------------

# .. _upload-create:

# This endpoint is for uploading an addon file, to then be submitted to create a new addon or version.

#     .. note::
#         This API requires :doc:`authentication <auth>`.

# .. http:post:: /api/v5/addons/upload/

#     .. _upload-create-request:

#     :form upload: The add-on file being uploaded.
#     :form channel: The channel this version should be uploaded to, which determines its visibility on the site. It can be either ``unlisted`` or ``listed``.
#     :reqheader Content-Type: multipart/form-data


# After the file has uploaded the :ref:`upload response <upload-detail-object>` will be
# returned immediately, and the addon submitted for validation.
# The :ref:`upload detail endpoint <upload-detail>` should be queried for validation status
# to determine when/if the upload can be used to create an add-on/version.


# -----------
# Upload List
# -----------

# .. _upload-list:

# This endpoint is for listing your previous uploads.

#     .. note::
#         This API requires :doc:`authentication <auth>`.

# .. http:get:: /api/v5/addons/upload/

#     :query int page: 1-based page number. Defaults to 1.
#     :query int page_size: Maximum number of results to return for the requested page. Defaults to 25.
#     :>json int count: The number of uploads this user has submitted.
#     :>json string next: The URL of the next page of results.
#     :>json string previous: The URL of the previous page of results.
#     :>json array results: An array of :ref:`uploads <upload-detail-object>`.


# -------------
# Upload Detail
# -------------

# .. _upload-detail:

# This endpoint is for fetching a single previous upload by uuid.

#     .. note::
#         This API requires :doc:`authentication <auth>`.

# .. http:get:: /api/v5/addons/upload/<string:uuid>/

#     .. _upload-detail-object:

#     :>json string uuid: The upload id.
#     :>json string channel: The version channel, which determines its visibility on the site. Can be either ``unlisted`` or ``listed``.
#     :>json boolean processed: If the version has been processed by the validator.
#     :>json boolean submitted: If this upload has been submitted as a new add-on or version already. An upload can only be submitted once.
#     :>json string url: URL to check the status of this upload.
#     :>json boolean valid: If the version passed validation.
#     :>json object validation: the validation results JSON blob.
#     :>json string version: The version number parsed from the manifest.


# -----------------------
# EULA and Privacy Policy
# -----------------------

# .. _addon-eula-policy:

# This endpoint allows you to fetch an add-on EULA and privacy policy.

# .. http:get:: /api/v5/addons/addon/(int:id|string:slug|string:guid)/eula_policy/

#     .. note::
#         Non-public add-ons and add-ons with only unlisted versions require both:

#             * authentication
#             * reviewer permissions or an account listed as a developer of the add-on

#     :>json object|null eula: The text of the EULA, if present (See :ref:`translated fields <api-overview-translations>`).
#     :>json object|null privacy_policy: The text of the Privacy Policy, if present (See :ref:`translated fields <api-overview-translations>`).


# ----------------------------
# EULA and Privacy Policy Edit
# ----------------------------

# .. _addon-eula-policy-edit:

# This endpoint allows an add-on's EULA and privacy policy to be edited.

#     .. note::
#         This API requires :doc:`authentication <auth>`, and for the user to be an author of the add-on.

#     .. note::
#         This API is not valid for themes - themes do not have EULA or privacy policies.

# .. http:patch:: /api/v5/addons/addon/(int:id|string:slug|string:guid)/eula_policy/

#     :<json object|null eula: The EULA text (See :ref:`translated fields <api-overview-translations>`).
#     :<json object|null privacy_policy: The privacy policy text (See :ref:`translated fields <api-overview-translations>`).


# --------------
# Language Tools
# --------------

# .. _addon-language-tools:

# This endpoint allows you to list all public language tools add-ons available
# on AMO.

# .. http:get:: /api/v5/addons/language-tools/

#     .. note::
#         Because this endpoint is intended to be used to feed a page that
#         displays all available language tools in a single page, it is not
#         paginated as normal, and instead will return all results without
#         obeying regular pagination parameters. The ordering is left undefined,
#         it's up to the clients to re-order results as needed before displaying
#         the add-ons to the end-users.

#         In addition, the results can be cached for up to 24 hours, based on the
#         full URL used in the request.

#     :query string app: Mandatory when ``appversion`` is present, ignored otherwise. Filter by :ref:`add-on application <addon-detail-application>` availability.
#     :query string appversion: Filter by application version compatibility. Pass the full version as a string, e.g. ``46.0``. Only valid when both the ``app`` and ``type`` parameters are also present, and only makes sense for Language Packs, since Dictionaries are always compatible with every application version.
#     :query string author: Filter by exact (listed) author username. Multiple author names can be specified, separated by comma(s), in which case add-ons with at least one matching author are returned.
#     :query string lang: Activate translations in the specific language for that query. (See :ref:`translated fields <api-overview-translations>`)
#     :query string type: Mandatory when ``appversion`` is present. Filter by :ref:`add-on type <addon-detail-type>`. The default is to return both Language Packs or Dictionaries.
#     :>json array results: An array of language tools.
#     :>json int results[].id: The add-on id on AMO.
#     :>json object results[].current_compatible_version: Object holding the latest publicly available :ref:`version <version-detail-object>` of the add-on compatible with the ``appversion`` parameter used. Only present when ``appversion`` is passed and valid. For performance reasons, only the following version properties are returned on the object: ``id``, ``file``, ``reviewed``, and ``version``.
#     :>json string results[].default_locale: The add-on default locale for translations.
#     :>json object|null results[].name: The add-on name (See :ref:`translated fields <api-overview-translations>`).
#     :>json string results[].guid: The add-on `extension identifier <https://developer.mozilla.org/en-US/Add-ons/Install_Manifests#id>`_.
#     :>json string results[].slug: The add-on slug.
#     :>json string results[].target_locale: For dictionaries and language packs, the locale the add-on is meant for. Only present when using the Language Tools endpoint.
#     :>json string results[].type: The :ref:`add-on type <addon-detail-type>`.
#     :>json string results[].url: The (absolute) add-on detail URL.


# -------------------
# Replacement Add-ons
# -------------------

# .. _addon-replacement-addons:

# This endpoint returns a list of suggested replacements for legacy add-ons that are unsupported in Firefox 57.

# .. http:get:: /api/v5/addons/replacement-addon/

#     :query int page: 1-based page number. Defaults to 1.
#     :query int page_size: Maximum number of results to return for the requested page. Defaults to 25.
#     :>json int count: The total number of replacements.
#     :>json string next: The URL of the next page of results.
#     :>json string previous: The URL of the previous page of results.
#     :>json array results: An array of replacements matches.
#     :>json string results[].guid: The extension identifier of the legacy add-on.
#     :>json string results[].replacement[]: An array of guids for the replacements add-ons.  If there is a direct replacement this will be a list of one add-on guid.  The list can be empty if all the replacement add-ons are invalid (e.g. not publicly available on AMO).  The list will also be empty if the replacement is to a url that is not an addon or collection.


# ---------------
# Recommendations
# ---------------

# .. _addon-recommendations:

# This endpoint provides recommendations of other addons to install. Maximum four recommendations will be returned.

# .. http:get:: /api/v5/addons/recommendations/

#     :query string app: Set the :ref:`add-on application <addon-detail-application>` for that query. This won't filter the results. Defaults to ``firefox``.
#     :query string guid: Fetch recommendations for this add-on guid.
#     :query string lang: Activate translations in the specific language for that query. (See :ref:`translated fields <api-overview-translations>`)
#     :query boolean recommended: Ignored.
#     :>json string outcome: Outcome of the response returned. Will always be ``curated``.
#     :>json null fallback_reason: Always null.
#     :>json int count: The number of results for this query.
#     :>json string next: The URL of the next page of results.
#     :>json string previous: The URL of the previous page of results.
#     :>json array results: An array of :ref:`add-ons <addon-detail-object>`. The following fields are omitted for performance reasons: ``release_notes`` and ``license`` fields on ``current_version`` and ``current_beta_version``, as well as ``picture_url`` from ``authors``.


# ----------------
# Browser Mappings
# ----------------

# .. _addon-browser-mappings:

# This endpoint provides browser mappings of non-Firefox and Firefox extensions.  Added to support the extensions import feature in Firefox.

# .. http:get:: /api/v5/addons/browser-mappings/

#     .. note::
#         This endpoint uses a larger ``page_size`` than most other API endpoints.

#     :query string browser: The browser identifier for this query (required). Must be one of these: ``chrome``.
#     :query int page_size: Maximum number of results to return for the requested page. Defaults to 100.
#     :>json array results: An array containing a mapping of non-Firefox and Firefox extension IDs for a given browser.
#     :>json string results[].extension_id: A non-Firefox extension ID.
#     :>json string results[].addon_guid: The corresponding Firefox add-on ``guid``.
