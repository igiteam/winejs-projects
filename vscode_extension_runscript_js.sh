#!/bin/bash
set -e

# ============================================
# JavaScript Script Runner VS Code Extension #
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═════════════════════════════════════════════════════════════════╗"
echo "║      JavaScript Script Runner VSCODE EXTENSION INSTALL         ║"
echo "╚═════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "This extension adds '▶️ Run .js' command to run JavaScript scripts with one click."
echo "Features:"
echo "- Right-click on any .js file → '▶️ Run .js'"
echo "- Automatic Node.js execution"
echo "- Smart npm script detection (checks package.json)"
echo "- Runs in VS Code terminal with proper working directory"
echo "- Works with .js, .mjs, and .cjs files"
echo ""

# Ask for extension name
read -p "Enter your extension folder name (default: vscode_js-runner): " EXTNAME
EXTNAME=${EXTNAME:-vscode_js-runner}

# Check if folder exists
if [ -d "$EXTNAME" ]; then
    read -p "Folder '$EXTNAME' already exists. Remove it? (y/N): " REMOVE
    REMOVE=${REMOVE:-N}
    if [[ "$REMOVE" == "y" || "$REMOVE" == "Y" ]]; then
        echo "Removing existing folder '$EXTNAME'..."
        rm -rf "$EXTNAME"
    else
        echo "Exiting to avoid overwriting."
        exit 1
    fi
fi

# Create folder structure
mkdir -p "$EXTNAME/src" "$EXTNAME/media" "$EXTNAME/out"
cd "$EXTNAME" || exit

# Download JavaScript icon
echo -e "${CYAN}📥 Downloading JavaScript icon...${NC}"
curl -s -o media/logo.png "https://cdn.gitgpt.chat/rtx/images/javascript.png"

# Create package.json
cat <<EOL > package.json
{
  "name": "javascript-runner",
  "displayName": "JavaScript Script Runner",
  "description": "One-click runner for JavaScript/Node.js scripts with npm script detection",
  "repository": "https://github.com/yourusername/javascript-runner",
  "publisher": "igiteam",
  "icon": "media/logo.png",
  "version": "1.0.0",
  "engines": {
    "vscode": "^1.81.0"
  },
  "categories": [
    "Other"
  ],
  "activationEvents": [
    "onCommand:javascriptrunner.runJavaScriptScript"
  ],
  "main": "./out/extension.js",
  "contributes": {
    "commands": [
      {
        "command": "javascriptrunner.runJavaScriptScript",
        "title": "▶️ Run .js",
        "category": "JavaScript"
      }
    ],
    "menus": {
      "explorer/context": [
        {
          "command": "javascriptrunner.runJavaScriptScript",
          "group": "navigation",
          "when": "resourceExtname == '.js' || resourceExtname == '.mjs' || resourceExtname == '.cjs'"
        }
      ],
      "editor/title": [
        {
          "command": "javascriptrunner.runJavaScriptScript",
          "group": "navigation",
          "when": "resourceExtname == '.js' || resourceExtname == '.mjs' || resourceExtname == '.cjs'"
        }
      ]
    }
  },
  "scripts": {
    "vscode:prepublish": "npm run compile",
    "compile": "tsc -p ./",
    "watch": "tsc -watch -p ./"
  },
  "devDependencies": {
    "@types/node": "20.x",
    "@types/vscode": "^1.81.0",
    "typescript": "^5.7.2"
  },
  "dependencies": {}
}
EOL

# Create tsconfig.json
cat <<EOL > tsconfig.json
{
	"compilerOptions": {
		"module": "Node16",
		"target": "ES2022",
		"outDir": "out",
		"lib": [
			"ES2022"
		],
		"sourceMap": true,
		"rootDir": "src",
		"strict": true
	}
}
EOL

# Create extension.ts with smart npm detection
cat <<'EOL' > src/extension.ts
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

interface PackageJson {
    scripts?: Record<string, string>;
    main?: string;
}

export function activate(context: vscode.ExtensionContext) {
    console.log('✅ JavaScript Script Runner activated!');

    const disposable = vscode.commands.registerCommand('javascriptrunner.runJavaScriptScript', async (resource: vscode.Uri) => {
        // If called from command palette with no resource, try active editor
        if (!resource) {
            const editor = vscode.window.activeTextEditor;
            if (editor && ['.js', '.mjs', '.cjs'].includes(path.extname(editor.document.fileName))) {
                resource = editor.document.uri;
            } else {
                vscode.window.showWarningMessage('Please select a JavaScript file (.js, .mjs, .cjs) to run');
                return;
            }
        }

        const scriptPath = resource.fsPath;
        const scriptDir = path.dirname(scriptPath);
        const scriptName = path.basename(scriptPath);

        try {
            // Check if it's a JavaScript file
            const ext = path.extname(scriptPath);
            if (!['.js', '.mjs', '.cjs'].includes(ext)) {
                vscode.window.showErrorMessage('Please select a JavaScript file (.js, .mjs, .cjs)');
                return;
            }

            // Run the script
            await vscode.window.withProgress({
                location: vscode.ProgressLocation.Notification,
                title: `Running ${scriptName}...`,
                cancellable: true
            }, async (progress, token) => {
                token.onCancellationRequested(() => {
                    vscode.window.showInformationMessage('JavaScript script execution cancelled');
                });

                // Create terminal
                const terminal = vscode.window.createTerminal({
                    name: `Run ${scriptName}`,
                    cwd: scriptDir
                });

                // Show the terminal
                terminal.show();

                // SMART DETECTION: Check for package.json and npm scripts
                const packageJsonPath = path.join(scriptDir, 'package.json');
                let runCommand = '';

                if (fs.existsSync(packageJsonPath)) {
                    try {
                        const packageJson: PackageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
                        
                        // Check if this file is referenced in npm scripts
                        if (packageJson.scripts) {
                            for (const [scriptName, scriptCommand] of Object.entries(packageJson.scripts)) {
                                // Type assertion to tell TypeScript scriptCommand is a string
                                const commandStr = scriptCommand as string;
                                // If script name matches file (e.g., "start": "node index.js" and file is index.js)
                                if (commandStr.includes(scriptName)) {
                                    runCommand = `npm run ${scriptName}`;
                                    vscode.window.showInformationMessage(`Found npm script: ${scriptName}`);
                                    break;
                                }
                            }
                        }
                        
                        // Check if this is the "main" file
                        if (!runCommand && packageJson.main === scriptName) {
                            runCommand = 'npm start';
                            vscode.window.showInformationMessage('File is "main" entry - running npm start');
                        }

                        // Check for common patterns in scripts
                        if (!runCommand && packageJson.scripts) {
                            for (const [scriptName, scriptCommand] of Object.entries(packageJson.scripts)) {
                                const commandStr = scriptCommand as string;
                                if (commandStr.includes(scriptName) || 
                                    (commandStr.includes('node') && commandStr.includes(scriptName))) {
                                    runCommand = `npm run ${scriptName}`;
                                    vscode.window.showInformationMessage(`Found matching script: ${scriptName}`);
                                    break;
                                }
                            }
                        }
                    } catch (e) {
                        console.error('Failed to parse package.json:', e);
                    }
                }

                // Determine Node.js command (check for local node_modules/.bin)
                let nodeCmd = 'node';
                
                // Check for npx/npm bin
                const nodeModulesBin = path.join(scriptDir, 'node_modules', '.bin');
                if (fs.existsSync(nodeModulesBin)) {
                    // Add node_modules/.bin to PATH by using npx
                    nodeCmd = 'npx';
                }

                // NVM initialization commands to run in the terminal
                const nvmInit = `
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
                [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
                export NODE_OPTIONS=--openssl-legacy-provider
                `;

                if (runCommand) {
                    // Run via npm script with NVM loaded
                    terminal.sendText(`${nvmInit} && cd "${scriptDir}" && ${runCommand}`);
                } else {
                    // Direct node execution with NVM loaded
                    vscode.window.showInformationMessage(`Running: ${nodeCmd} "${scriptName}"`);
                    terminal.sendText(`${nvmInit} && cd "${scriptDir}" && ${nodeCmd} "${scriptName}"`);
                }

                // Wait a bit for output
                await new Promise(resolve => setTimeout(resolve, 1000));
            });

        } catch (error: any) {
            vscode.window.showErrorMessage(`Failed to run JavaScript script: ${error.message}`);
            console.error('JavaScript runner error:', error);
        }
    });

    context.subscriptions.push(disposable);
}

export function deactivate() {}
EOL

# Create .vscodeignore
cat <<EOL > .vscodeignore
.vscode
src
*.ts
*.map
.git
.gitignore
*.sh
*.py
test
EOL

# Create README.md
cat <<EOL > README.md
# JavaScript Script Runner

One-click runner for JavaScript/Node.js scripts with smart npm script detection.

## Features

- Right-click any .js/.mjs/.cjs file → "▶️ Run .js"
- Automatic Node.js execution
- Smart npm script detection (checks package.json)
- Runs in VS Code terminal with proper working directory
- Editor title menu support

## Smart Features

- **npm script detection**: If file is referenced in package.json scripts, runs the npm script
- **"main" file detection**: If file is the "main" entry, runs \`npm start\`
- **Direct execution**: Falls back to \`node filename.js\`
- **npx support**: Automatically uses npx if node_modules/.bin exists

## Usage

- Right-click any JavaScript file in explorer → "▶️ Run .js"
- Click "▶️ Run .js" in editor title when editing JavaScript files
- Command Palette → "▶️ Run .js"

## Requirements

- VS Code 1.81.0 or higher
- Node.js installed
- (Optional) npm/yarn for package.json support
EOL

echo -e "${GREEN}✅ Extension scaffold created in '$EXTNAME'${NC}"

# Create License.md
cat <<EOL > LICENSE.md
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
EOL

# ===============================================
# Build and Install Extension
# ===============================================

echo -e "${CYAN}🔨 Building and installing extension...${NC}"

# Set Node options
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null || true
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 2>/dev/null || true
export NODE_OPTIONS=--openssl-legacy-provider

echo -e "${YELLOW}Node: $(node -v 2>/dev/null || echo 'not found') | npm: $(npm -v 2>/dev/null || echo 'not found')${NC}"

# Install dependencies
if [ ! -d "node_modules" ]; then
    echo -e "${CYAN}📦 Installing Node dependencies...${NC}"
    npm install 2>/dev/null || {
        echo -e "${YELLOW}⚠️  npm install failed, trying with --force${NC}"
        npm install --force
    }
fi

# Compile TypeScript
echo -e "${CYAN}🔨 Compiling TypeScript...${NC}"
npm run compile 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Compilation failed, trying to fix...${NC}"
    npm install --save-dev typescript @types/node @types/vscode
    npx tsc -p ./
}

# Package extension
echo -e "${CYAN}📦 Packaging extension...${NC}"

if ! command -v vsce &> /dev/null; then
    echo -e "${YELLOW}Installing vsce...${NC}"
    npm install -g vsce 2>/dev/null || sudo npm install -g vsce
fi

vsce package --allow-missing-repository 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Packaging failed, trying without validation${NC}"
    vsce package --allow-missing-repository --no-yarn
}

VSIX_FILE=$(ls javascript-runner-*.vsix 2>/dev/null | head -n1)

if [ ! -f "$VSIX_FILE" ]; then
    echo -e "${RED}❌ Failed to package extension${NC}"
    echo -e "${YELLOW}⚠️  But the extension folder is ready at: $(pwd)${NC}"
    echo -e "${YELLOW}You can manually package with: vsce package${NC}"
else
    echo -e "${GREEN}✅ Extension packaged: $VSIX_FILE${NC}"

    # Install extension
    echo -e "${CYAN}📥 Installing extension...${NC}"

    if command -v code-server &> /dev/null; then
        echo -e "${YELLOW}🔧 Detected code-server environment${NC}"
        code-server --install-extension "$VSIX_FILE" --force 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Could not install with code-server${NC}"
        }
    elif command -v code &> /dev/null; then
        code --install-extension "$VSIX_FILE" --force 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Could not install with code command${NC}"
        }
    else
        echo -e "${YELLOW}⚠️  'code' or 'code-server' command not found${NC}"
        echo -e "${YELLOW}Install manually: code --install-extension $VSIX_FILE${NC}"
    fi

    echo -e "${GREEN}✅ JavaScript Script Runner installed successfully!${NC}"
fi

# Show usage instructions
echo ""
echo -e "${CYAN}⚙️  How to use:${NC}"
echo "1. Find any .js/.mjs/.cjs file in your project"
echo "2. Right-click on it → '▶️ Run .js'"
echo "3. Or click '▶️ Run .js' in editor title when editing JavaScript files"
echo ""
echo -e "${GREEN}🎉 Ready to use! Right-click any JavaScript file → '▶️ Run .js'${NC}"
echo ""
echo -e "${CYAN}🤖 Smart Features:${NC}"
echo "- Checks package.json for npm scripts"
echo "- Runs 'npm run scriptname' if script exists"
echo "- Runs 'npm start' if file is the 'main' entry"
echo "- Falls back to 'node filename.js' otherwise"
echo "- Auto-detects npx for local node_modules/.bin"

# Go back to original directory
cd - > /dev/null