#!/bin/bash
# to_mp4_converter.sh - Convert & Upscale videos to QuickTime-compatible MP4
# Place this script in the folder containing your video files

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set input directory to script location
INPUT_DIR="$SCRIPT_DIR"

# Set output directory to OUTPUT_MP4 subfolder in the same location
OUTPUT_DIR="${SCRIPT_DIR}/OUTPUT_MP4"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "🎬 Video to QuickTime MP4 Converter"
echo "========================================="
echo "📁 Script location: $SCRIPT_DIR"
echo "📁 Input directory:  $INPUT_DIR"
echo "📁 Output directory: $OUTPUT_DIR"
echo ""
echo "🔄 Supported formats: MP4, AVI, MPG, MPEG, MOV, WMV, MKV, FLV, WEBM"
echo ""
echo "📐 UPSCALING OPTIONS:"
echo "   1) No upscaling (original resolution)"
echo "   2) 2x upscale (double width/height)"
echo "   3) 4x upscale (quadruple width/height)"
echo "   4) Upscale to 720p (1280x720)"
echo "   5) Upscale to 1080p (1920x1080)"
echo "   6) Upscale to 4K (3840x2160) [DEFAULT]"
echo "   7) AI-style upscale (smooth, better for cartoons/games)"
echo "========================================="
echo ""

# Ask for upscaling preference
read -p "Choose upscaling option (1-7) [default: 6 for 4K]: " UPSCALE_OPTION
UPSCALE_OPTION=${UPSCALE_OPTION:-6}

# Set upscale filter based on choice
case $UPSCALE_OPTION in
    2)
        SCALE_FILTER="scale=iw*2:ih*2"
        UPSCALE_NAME="2x_upscale"
        ;;
    3)
        SCALE_FILTER="scale=iw*4:ih*4"
        UPSCALE_NAME="4x_upscale"
        ;;
    4)
        SCALE_FILTER="scale=1280:720:force_original_aspect_ratio=1,pad=1280:720:(ow-iw)/2:(oh-ih)/2"
        UPSCALE_NAME="720p"
        ;;
    5)
        SCALE_FILTER="scale=1920:1080:force_original_aspect_ratio=1,pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
        UPSCALE_NAME="1080p"
        ;;
    6)
        # FIXED: Better 4K upscaling with proper aspect ratio handling
        SCALE_FILTER="scale=3840:2160:force_original_aspect_ratio=decrease:flags=lanczos,pad=3840:2160:(ow-iw)/2:(oh-ih)/2:color=black"
        UPSCALE_NAME="4K"
        ;;
    7)
        # AI-style upscaling with smoother edges (good for game footage/cartoons)
        SCALE_FILTER="scale=iw*2:ih*2:flags=lanczos,unsharp=5:5:1.0:5:5:0.5"
        UPSCALE_NAME="AI-style_2x_smooth"
        ;;
    *)
        SCALE_FILTER="scale=trunc(iw/2)*2:trunc(ih/2)*2"
        UPSCALE_NAME="original"
        ;;
esac

# Create subdirectory for this upscale type
OUTPUT_SUBDIR="${OUTPUT_DIR}/${UPSCALE_NAME}"
mkdir -p "$OUTPUT_SUBDIR"

echo ""
echo "✅ Using: $UPSCALE_NAME"
echo "📁 Output subfolder: ${UPSCALE_NAME}/"
echo ""

# Counter for processed files
COUNT=0
SUCCESS=0
FAILED=0

# Process all video files
for VIDEO_FILE in "$INPUT_DIR"/*.mp4 "$INPUT_DIR"/*.avi "$INPUT_DIR"/*.mpg "$INPUT_DIR"/*.mpeg "$INPUT_DIR"/*.mov "$INPUT_DIR"/*.wmv "$INPUT_DIR"/*.mkv "$INPUT_DIR"/*.flv "$INPUT_DIR"/*.webm; do
    # Skip if no files found
    if [ ! -f "$VIDEO_FILE" ]; then
        continue
    fi
    
    # Get file info
    BASENAME=$(basename "$VIDEO_FILE")
    EXTENSION="${BASENAME##*.}"
    NAME_WITHOUT_EXT="${BASENAME%.*}"
    
    # Set output file path (now using the subdirectory we created)
    OUTPUT_FILE="${OUTPUT_SUBDIR}/${NAME_WITHOUT_EXT}.mp4"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📹 Processing [$((COUNT+1))]: $BASENAME"
    echo "   Type: $(echo $EXTENSION | tr '[:lower:]' '[:upper:]')"
    
    # Get original file size and resolution
    ORIG_SIZE=$(du -h "$VIDEO_FILE" | cut -f1)
    echo "   Original size: $ORIG_SIZE"
    
    # Get original resolution (if ffprobe available)
    if command -v ffprobe &> /dev/null; then
        ORIG_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$VIDEO_FILE" 2>/dev/null | tr ',' 'x')
        if [ ! -z "$ORIG_RES" ]; then
            echo "   Original resolution: ${ORIG_RES}"
        fi
    fi
    
    # Create temp directory for this file
    TEMP_DIR="/tmp/vidconv_$$_${NAME_WITHOUT_EXT}"
    mkdir -p "$TEMP_DIR"
    
    # Copy file to temp directory (handles spaces in filenames)
    cp "$VIDEO_FILE" "$TEMP_DIR/input.${EXTENSION}"
    
    echo "   Converting & upscaling to MP4 (H.264/AAC)..."
    
    # Run ffmpeg conversion with upscaling
    if command -v ffmpeg &> /dev/null; then
        # Local ffmpeg available
        ffmpeg -y \
            -i "$TEMP_DIR/input.${EXTENSION}" \
            -vf "$SCALE_FILTER" \
            -c:v libx264 \
            -profile:v main \
            -level 4.0 \
            -pix_fmt yuv420p \
            -movflags +faststart \
            -preset medium \
            -crf 18 \
            -c:a aac \
            -b:a 192k \
            -ac 2 \
            "$TEMP_DIR/output.mp4" 2>&1 | grep -E "(frame=|error|Output|width|height)" | tail -10
    else
        # Use docker ffmpeg
        docker run --rm \
            -v "$TEMP_DIR:/work" \
            jrottenberg/ffmpeg:latest \
            -y \
            -i "/work/input.${EXTENSION}" \
            -vf "$SCALE_FILTER" \
            -c:v libx264 \
            -profile:v main \
            -level 4.0 \
            -pix_fmt yuv420p \
            -movflags +faststart \
            -preset medium \
            -crf 18 \
            -c:a aac \
            -b:a 192k \
            -ac 2 \
            "/work/output.mp4" 2>&1 | grep -E "(frame=|error|Output|width|height)" | tail -10
    fi
    
    # Check if conversion succeeded
    if [ $? -eq 0 ] && [ -f "$TEMP_DIR/output.mp4" ]; then
        # Copy output to destination
        cp "$TEMP_DIR/output.mp4" "$OUTPUT_FILE"
        
        # Get new file size and resolution
        NEW_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        
        if command -v ffprobe &> /dev/null; then
            NEW_RES=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$OUTPUT_FILE" 2>/dev/null | tr ',' 'x')
            echo "   New resolution: ${NEW_RES}"
        fi
        
        echo "   ✅ SUCCESS!"
        echo "   📎 Output: ${UPSCALE_NAME}/$(basename "$OUTPUT_FILE")"
        echo "   💾 New size: $NEW_SIZE"
        ((SUCCESS++))
    else
        echo "   ❌ FAILED to convert $BASENAME"
        echo "   ⚠️  File may be corrupted or unsupported"
        ((FAILED++))
    fi
    
    # Cleanup temp directory
    rm -rf "$TEMP_DIR"
    
    ((COUNT++))
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "========================================="
echo "📊 CONVERSION SUMMARY"
echo "========================================="
echo "✅ Successfully converted: $SUCCESS files"
echo "❌ Failed: $FAILED files"
echo "📁 Total processed: $COUNT files"
echo "🎨 Upscaling applied: $UPSCALE_NAME"
echo ""
echo "💿 Output location: ${OUTPUT_SUBDIR}"
echo ""
echo "🎉 All converted videos are now QuickTime-compatible!"
echo "   • Play with QuickTime Player"
echo "   • Import to iMovie/Final Cut Pro"
echo "   • Share via Messages/AirDrop"
echo "========================================="

# Open output directory in Finder (macOS)
if [ $SUCCESS -gt 0 ]; then
    echo ""
    read -p "📂 Open output directory in Finder? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$OUTPUT_SUBDIR"
    fi
fi