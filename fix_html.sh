#!/bin/bash

cd /var/www/flipbook/output

echo "========================================="
echo "  Complete Flipbook Fix Workflow"
echo "========================================="
echo ""

# Step 1: Remove all zip files
echo "📦 Step 1: Removing all zip files..."
ZIP_COUNT=$(ls -1 *.zip 2>/dev/null | wc -l)
if [ "$ZIP_COUNT" -gt 0 ]; then
    rm -f *.zip
    echo "  ✅ Removed $ZIP_COUNT zip files"
else
    echo "  ℹ️ No zip files found"
fi
echo ""

# Step 2: Run your fix script
echo "📄 Step 2: Running HTML fix script..."

# Save your Python script to a file if it doesn't exist
if [ ! -f "/tmp/fix_htmls.py" ]; then
    cat > /tmp/fix_htmls.py << 'EOF'
#!/usr/bin/env python3
import os
import re
import shutil
from pathlib import Path

def process_html_file(filepath, output_name=None):
    """Process a single HTML file and save it"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        modified = False
        
        # 1. Add meta tag if not exists
        if 'apple-mobile-web-app-capable' not in content:
            content = content.replace('<head>', '<head>\n    <meta name="apple-mobile-web-app-capable" content="yes">')
            modified = True
            print("    ✓ Added meta tag")
        
        # 2. Add JavaScript for iOS gesture prevention
        if 'Prevent iOS swipe back gesture' not in content:
            gesture_js = """    <script>
        // Prevent iOS swipe back gesture
        document.addEventListener('touchstart', function(e) {
            if (e.touches.length === 1 && e.touches[0].clientX < 20) {
                e.preventDefault();
            }
        }, { passive: false });

        // Also prevent it on the magazine
        $('#magazine').on('touchstart', function(e) {
            if (e.originalEvent.touches.length === 1 && e.originalEvent.touches[0].clientX < 20) {
                e.preventDefault();
                return false;
            }
        });
    </script>"""
            
            if '</body>' in content:
                content = content.replace('</body>', gesture_js + '\n</body>')
                modified = True
                print("    ✓ Added iOS gesture prevention script")
            else:
                content = content.replace('</html>', gesture_js + '\n</html>')
                modified = True
                print("    ✓ Added iOS gesture prevention script")
        
        # 3. Add CSS fixes
        if 'Fix for ALL elements during zoom' not in content:
            css_fixes = """
        /* Fix for ALL elements during zoom - not just the magazine */
        html, body {
            height: 100% !important;
            min-height: 100% !important;
            overflow: hidden !important;
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            right: 0 !important;
            bottom: 0 !important;
            width: 100% !important;
        }

        #magazine {
            height: 100% !important;
            min-height: 100% !important;
            width: 100% !important;
            position: absolute !important;
            top: 0 !important;
            left: 0 !important;
        }

        #magazine.single-mode {
            height: 100% !important;
            min-height: 100% !important;
        }

        #magazine.single-mode .turn-page {
            height: 100% !important;
            min-height: 100% !important;
            background-size: contain !important;
            background-position: center !important;
            background-repeat: no-repeat !important;
        }"""
            
            if '</style>' in content:
                content = content.replace('</style>', css_fixes + '\n    </style>')
                modified = True
                print("    ✓ Added CSS fixes")
        
        if not modified:
            print("    ⚠ No changes needed (all fixes already present)")
            output_path = output_name if output_name else filepath
            shutil.copy2(filepath, output_path)
            return True
        
        output_path = output_name if output_name else filepath
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return True
        
    except Exception as e:
        print(f"    ✗ ERROR: {e}")
        return False

def main():
    current_dir = os.getcwd()
    print(f"📁 Working in: {current_dir}")
    print("=" * 60)
    
    # Find all HTML files in subdirectories
    html_files = []
    for root, dirs, files in os.walk('.'):
        if 'backup' in root:
            continue
        for file in files:
            if file.endswith('.html') or file.endswith('.htm'):
                full_path = os.path.join(root, file)
                if root == '.':
                    continue
                html_files.append(full_path)
    
    if not html_files:
        print("❌ No HTML files found in subfolders!")
        return
    
    print(f"📄 Found {len(html_files)} HTML files in subfolders")
    print("=" * 60)
    
    os.makedirs('backup', exist_ok=True)
    
    processed = 0
    failed = 0
    renamed = 0
    
    for filepath in html_files:
        filename = os.path.basename(filepath)
        folder = os.path.dirname(filepath).replace('./', '').replace('/', '_')
        
        if os.path.exists(filename):
            new_name = f"{folder}_{filename}"
            renamed += 1
            print(f"\n📝 Copying: {filepath}")
            print(f"   → Renamed to: {new_name} (duplicate filename)")
        else:
            new_name = filename
            print(f"\n📝 Copying: {filepath}")
            print(f"   → {new_name}")
        
        backup_path = f"backup/{new_name}"
        shutil.copy2(filepath, backup_path)
        print(f"   💾 Backup saved: {backup_path}")
        
        print("   🔧 Applying fixes:")
        if process_html_file(filepath, new_name):
            processed += 1
        else:
            failed += 1
    
    print("\n" + "=" * 60)
    print("✅ COMPLETE!")
    print(f"   📊 Processed: {processed} files")
    print(f"   📊 Failed: {failed} files")
    print(f"   📊 Renamed: {renamed} files (due to duplicates)")
    print(f"   💾 Backups: backup/ folder")
    print("=" * 60)

if __name__ == "__main__":
    main()
EOF
    chmod +x /tmp/fix_htmls.py
fi

# Run the fix script
python3 /tmp/fix_htmls.py

echo ""
echo "📄 Step 3: Copying fixed HTMLs back to their folders..."

# Copy each fixed HTML back to its folder
RESTORED=0
SKIPPED=0

# Find all fixed HTML files in the current directory (created by the script)
for fixed_file in *.html; do
    if [ ! -f "$fixed_file" ]; then continue; fi
    
    # Skip if it's not a fixed file (check if it has the folder prefix or is a standard filename)
    if [[ "$fixed_file" == *_flipbook.html ]] || [[ "$fixed_file" == *__*.html ]]; then
        # Extract the folder name from the filename
        # Example: flipbook_0289159ffbdaf3beea2087217c5b898a_PC_Zone_Issue_10__January_1994__flipbook.html
        # Or if it was renamed with folder prefix, we need to extract the original folder
        
        # Try to find matching folder
        # First, extract the base name without _flipbook
        base_name=$(echo "$fixed_file" | sed 's/_flipbook.html$//')
        
        # Search for a folder containing this base name
        FOUND_FOLDER=""
        for folder in flipbook_*/; do
            # Check if the folder contains any HTML with this base name
            if ls "$folder"*"$base_name"*.html 2>/dev/null | grep -q .; then
                FOUND_FOLDER="$folder"
                break
            fi
        done
        
        if [ -n "$FOUND_FOLDER" ]; then
            # Find the existing HTML in the folder
            HTML_FILE=$(ls -1 "$FOUND_FOLDER"*.html 2>/dev/null | head -1)
            if [ -n "$HTML_FILE" ]; then
                # Use the fixed file to replace it
                cp "$fixed_file" "$HTML_FILE"
                echo "  ✅ $fixed_file → $HTML_FILE"
                RESTORED=$((RESTORED + 1))
            else
                # No HTML found, create index.html
                cp "$fixed_file" "$FOUND_FOLDER/index.html"
                echo "  ✅ $fixed_file → $FOUND_FOLDER/index.html"
                RESTORED=$((RESTORED + 1))
            fi
        else
            echo "  ⚠️ Skipped: $fixed_file (no matching folder found)"
            SKIPPED=$((SKIPPED + 1))
        fi
    fi
done

echo ""
echo "  📊 Copy Summary:"
echo "    ✅ Restored: $RESTORED files"
echo "    ⏭️ Skipped: $SKIPPED files"
echo ""

# Step 4: Re-zip all folders
echo "📦 Step 4: Re-zipping all folders..."

ZIP_CREATED=0
ZIP_FAILED=0

for folder in flipbook_*/; do
    # Check if folder has HTML files
    HTML_COUNT=$(ls -1 "$folder"*.html 2>/dev/null | wc -l)
    
    if [ "$HTML_COUNT" -gt 0 ]; then
        zip_name="${folder%/}.zip"
        
        echo "  📦 Creating $zip_name..."
        if zip -r -q "$zip_name" "$folder" 2>/dev/null; then
            echo "    ✅ Created: $zip_name"
            ZIP_CREATED=$((ZIP_CREATED + 1))
        else
            echo "    ❌ Failed to create: $zip_name"
            ZIP_FAILED=$((ZIP_FAILED + 1))
        fi
    else
        echo "  ⚠️ No HTML in $folder, skipping zip"
    fi
done

echo ""
echo "  📊 ZIP Summary:"
echo "    ✅ Created: $ZIP_CREATED zip files"
if [ "$ZIP_FAILED" -gt 0 ]; then
    echo "    ❌ Failed: $ZIP_FAILED zip files"
fi
echo ""

# Final summary
echo "========================================="
echo "  ✅ All Done!"
echo "========================================="
echo ""
echo "📊 Final Summary:"
echo "  📂 Total folders: $(ls -d flipbook_*/ 2>/dev/null | wc -l)"
echo "  📦 ZIP files created: $ZIP_CREATED"
echo "  📄 HTML files restored: $RESTORED"
echo "  💾 Backups in: backup/"
echo ""
echo "🔍 Next steps:"
echo "  1. Test a flipbook: https://your-domain.com/output/flipbook_XXX/index.html"
echo "  2. Check history: /api/history"
echo "  3. View shelf: /api/shelf"
echo "========================================="