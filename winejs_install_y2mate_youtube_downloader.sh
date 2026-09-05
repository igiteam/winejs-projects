#!/bin/bash
# ============================================
# WineJS Y2Mate YouTube Downloader Installer  
# Adds YouTube Video/Audio Download Service to WineJS Platform
# ============================================
# App: Y2Mate YouTube Downloader
# Category: Media Downloading
# Features: YouTube to MP3/MP4, Transcript Download, Bulk Downloads, VTT Captions
# ============================================

# What this script does:
#     ✓ Verifies WineJS platform - Checks if /opt/winejs exists
#     ✓ Creates docker network - Creates winejs-net if missing
#     ✓ Creates all necessary directories with data persistence
#     ✓ Installs yt-dlp and Python dependencies
#     ✓ Sets up API server for YouTube downloads
#     ✓ Creates bulk download JSON file support
#     ✓ Creates translator bridge service
#     ✓ Creates launch.sh with auto-heal monitor
#     ✓ Creates config.json with all app metadata
#     ✓ Sets up automated backup system
#     ✓ Creates uninstall script with cleanup
#     ✓ Sets up PM2 for service persistence
#     ✓ Creates CLI helper tools
#     ✓ Creates web frontend for easy usage
#     ✓ Restarts translator and starts containers

APP_LOGO_URL="https://cdn.gitgpt.chat/rtx/images/y2mate-fav.png"

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; 
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${MAGENTA}[SUCCESS]${NC} $1"; }
header() { echo -e "${CYAN}$1${NC}"; }

log "🚀 Installing WineJS Y2Mate YouTube Downloader..."

# ============= VERIFY WINEJS PLATFORM =============
log "Verifying WineJS platform..."

if [ ! -d "/opt/winejs" ]; then
    error "WineJS platform not found at /opt/winejs"
    exit 1
fi

# Ensure winejs-net network exists
log "Checking winejs-net network..."
if docker network ls | grep -q "winejs-net"; then
    log "✅ winejs-net network already exists"
    if ! docker network inspect winejs-net &>/dev/null; then
        log "⚠️ Network exists but is corrupted, recreating..."
        docker network rm winejs-net 2>/dev/null || true
        docker network create winejs-net
        log "✅ winejs-net network recreated"
    fi
else
    log "Creating winejs-net network..."
    docker network create winejs-net
    if [ $? -eq 0 ]; then
        log "✅ winejs-net network created"
    else
        error "Failed to create winejs-net network"
    fi
fi

# ============= GET DOMAIN FROM WINEJS CONFIG =============
if [ -f "/opt/winejs/translator/index.js" ]; then
    DOMAIN_NAME=$(grep "const DOMAIN_NAME" /opt/winejs/translator/index.js | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/")
fi

if [ -z "$DOMAIN_NAME" ]; then
    read -p "Enter your WineJS domain (e.g., wine.yourdomain.com): " DOMAIN_NAME
fi

DOMAIN_NAME=$(echo "$DOMAIN_NAME" | tr -d '"' | tr -d "'" | xargs)
info "Using domain: $DOMAIN_NAME"

# ============= FIND NEXT AVAILABLE PORT =============
log "Finding next available port..."

port_in_use() {
    local port=$1
    if ss -tln | grep -q ":$port " || netstat -tln 2>/dev/null | grep -q ":$port "; then
        return 0
    fi
    if docker ps 2>/dev/null | grep -q ":$port->"; then
        return 0
    fi
    return 1
}

START_PORT=7100
MAX_RETRIES=100
APP_PORT=""

declare -a USED_PORTS
if [ -d "/opt/winejs/apps" ]; then
    for config in /opt/winejs/apps/*/config.json; do
        if [ -f "$config" ]; then
            PORT=$(grep -o '"port": [0-9]*' "$config" | awk '{print $2}')
            if [ -n "$PORT" ]; then
                USED_PORTS+=($PORT)
            fi
        fi
    done
fi

for i in $(seq 0 $MAX_RETRIES); do
    TEST_PORT=$((START_PORT + i))
    if [[ " ${USED_PORTS[@]} " =~ " ${TEST_PORT} " ]]; then
        continue
    fi
    if ! port_in_use $TEST_PORT; then
        APP_PORT=$TEST_PORT
        break
    fi
done

if [ -z "$APP_PORT" ]; then
    error "Could not find available port"
fi

log "Using port: $APP_PORT"

# ============= CREATE APP DIRECTORIES =============
APP_NAME="y2mate"
APP_DIR="/opt/winejs/apps/$APP_NAME"
INSTANCE_DIR="/opt/winejs/kasmvnc-instances/$APP_NAME"
DATA_DIR="/opt/winejs/data/y2mate"
CONFIG_DIR="/opt/winejs/config/y2mate"
ICON_DIR="/opt/winejs/translator/public/icons"
DOWNLOADS_DIR="/opt/winejs/data/y2mate/downloads"
TRANSCRIPTS_DIR="/opt/winejs/data/y2mate/transcripts"
SHARED_VOLUMES="/opt/winejs/shared-volumes"

mkdir -p "$APP_DIR"
mkdir -p "$INSTANCE_DIR"
mkdir -p "$DATA_DIR"/{downloads,transcripts,temp,logs}
mkdir -p "$CONFIG_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$DOWNLOADS_DIR"
mkdir -p "$TRANSCRIPTS_DIR"
mkdir -p "$SHARED_VOLUMES"/{backups,imports,exports}

cd "$APP_DIR"

# ============= INSTALL SYSTEM DEPENDENCIES =============
log "Installing system dependencies..."

# Install Python and pip
apt-get update -qq
apt-get install -y -qq python3.10 python3-pip python3-venv ffmpeg wget curl git redis-server nginx certbot python3-certbot-nginx 2>/dev/null || true

# Install Node.js 18 for API server
if ! command -v node &> /dev/null; then
    log "Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y -qq nodejs
fi

# Install PM2
if ! command -v pm2 &> /dev/null; then
    log "Installing PM2..."
    npm install -g pm2
fi

# Install FFmpeg (required for yt-dlp merging)
if ! command -v ffmpeg &> /dev/null; then
    log "Installing FFmpeg..."
    apt-get install -y -qq ffmpeg
fi

# ============= SETUP PYTHON VIRTUAL ENV =============
log "Setting up Python virtual environment..."

# Find available Python version
if command -v python3.12 &> /dev/null; then
    PYTHON_CMD="python3.12"
elif command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
elif command -v python3.10 &> /dev/null; then
    PYTHON_CMD="python3.10"
else
    PYTHON_CMD="python3"
fi

log "Using Python: $PYTHON_CMD"

cd "$DATA_DIR"
$PYTHON_CMD -m venv venv
source venv/bin/activate

# Install Python dependencies
cat > "$DATA_DIR/requirements.txt" << 'EOF'
yt-dlp>=2024.11.18
requests>=2.31.0
pyperclip>=1.8.2
lameenc>=1.4.0
audioread>=3.0.0
pydub>=0.25.1
beautifulsoup4>=4.12.0
Pillow>=10.0.0
mutagen>=1.47.0
google-auth-oauthlib>=1.2.0
google-api-python-client>=2.108.0
EOF

pip install --upgrade pip
pip install -r requirements.txt

# ============= CREATE YOUTUBE DOWNLOADER SCRIPTS =============
log "Creating YouTube downloader scripts..."

# ----- Transcript Downloader Script -----
cat > "$DATA_DIR/yt_transcript.py" << 'PYTHON_EOF'
#!/usr/bin/env python3.10
import sys
import re
import requests
import pyperclip
import json
import os
from pathlib import Path
from yt_dlp import YoutubeDL

def sanitize_filename(name):
    """Sanitize filename to remove invalid characters."""
    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def get_downloads_folder():
    """Get the Downloads folder path for the current user."""
    if os.name == 'nt':
        downloads = Path.home() / 'Downloads'
    elif os.name == 'posix' and sys.platform == 'darwin':
        downloads = Path.home() / 'Downloads'
    else:
        downloads = Path.home() / 'Downloads'
    
    downloads.mkdir(exist_ok=True)
    return downloads

def parse_vtt_transcript(vtt_content):
    """Parse VTT format captions and extract clean text."""
    lines = vtt_content.split('\n')
    transcript_lines = []
    
    for line in lines:
        if line.strip() and not line.startswith(('WEBVTT', 'Kind:', 'Language:', '-->')) and not re.match(r'^\d{2}:\d{2}:\d{2}', line):
            clean_line = re.sub(r'<[^>]+>', '', line).strip()
            if clean_line:
                transcript_lines.append(clean_line)
    
    return ' '.join(transcript_lines)

def parse_json_transcript(json_content):
    """Parse JSON format captions that YouTube sometimes returns."""
    try:
        data = json.loads(json_content)
        transcript_parts = []
        
        if 'events' in data:
            for event in data['events']:
                if 'segs' in event:
                    for seg in event['segs']:
                        if 'utf8' in seg:
                            text = seg['utf8'].strip()
                            if text:
                                transcript_parts.append(text)
        
        return ' '.join(transcript_parts)
    except json.JSONDecodeError:
        return parse_vtt_transcript(json_content)

def convert_json_to_vtt(json_content):
    """Convert YouTube JSON captions to VTT format."""
    try:
        data = json.loads(json_content)
        vtt_lines = ["WEBVTT", "", "Kind: captions", "Language: en", ""]
        
        if 'events' in data:
            event_num = 1
            for event in data['events']:
                if 'segs' in event and 'tStartMs' in event:
                    start_ms = event['tStartMs']
                    duration = event.get('dDurationMs', 3000)
                    end_ms = start_ms + duration
                    
                    start_time = f"{start_ms // 3600000:02d}:{(start_ms % 3600000) // 60000:02d}:{(start_ms % 60000) // 1000:02d}.{start_ms % 1000:03d}"
                    end_time = f"{end_ms // 3600000:02d}:{(end_ms % 3600000) // 60000:02d}:{(end_ms % 60000) // 1000:02d}.{end_ms % 1000:03d}"
                    
                    text_parts = []
                    for seg in event['segs']:
                        if 'utf8' in seg:
                            text_parts.append(seg['utf8'])
                    
                    if text_parts:
                        caption_text = ''.join(text_parts).strip()
                        if caption_text:
                            vtt_lines.append(str(event_num))
                            vtt_lines.append(f"{start_time} --> {end_time}")
                            vtt_lines.append(caption_text)
                            vtt_lines.append("")
                            event_num += 1
        
        return '\n'.join(vtt_lines)
    except json.JSONDecodeError:
        return json_content

def fetch_transcript(url, save_vtt=True):
    """Fetches plain-text transcript for a YouTube video."""
    ydl_opts = {
        'quiet': False,
        'skip_download': True,
        'writesubtitles': True,
        'writeautomaticsub': True,
        'subtitlesformat': 'vtt',
        'subtitleslangs': ['en'],
    }

    try:
        with YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            title = sanitize_filename(info.get('title', 'video'))
            video_id = info.get('id', 'unknown')
            
            print(f"Video: {title}")
            
            downloads_folder = get_downloads_folder()
            
            auto_captions = info.get('automatic_captions', {})
            manual_captions = info.get('subtitles', {})
            
            transcript = ""
            caption_url = None
            vtt_content = None
            
            if 'en' in manual_captions and manual_captions['en']:
                caption_url = manual_captions['en'][0]['url']
                print("Using manual English captions")
            elif 'en' in auto_captions and auto_captions['en']:
                caption_url = auto_captions['en'][0]['url']
                print("Using automatic English captions")
            else:
                print("No English captions available for this video.")
                return ""
            
            if caption_url:
                resp = requests.get(caption_url)
                if resp.status_code == 200:
                    raw_caption_content = resp.text
                    vtt_content = raw_caption_content
                    
                    if raw_caption_content.strip().startswith('{') or '"wireMagic"' in raw_caption_content:
                        print("Detected JSON format captions")
                        transcript = parse_json_transcript(raw_caption_content)
                        vtt_content = convert_json_to_vtt(raw_caption_content)
                    else:
                        print("Detected VTT format captions")
                        transcript = parse_vtt_transcript(raw_caption_content)
                    
                    if transcript:
                        pyperclip.copy(transcript)
                        print(f"✓ Transcript copied to clipboard! ({len(transcript)} characters)")
                        
                        if save_vtt and vtt_content:
                            vtt_filename = f"{title}_{video_id}.vtt"
                            vtt_filepath = downloads_folder / vtt_filename
                            with open(vtt_filepath, 'w', encoding='utf-8') as f:
                                f.write(vtt_content)
                            print(f"✓ VTT file saved to: {vtt_filepath}")
                    else:
                        print("Failed to extract transcript from captions.")
            
            return transcript
    except Exception as e:
        print(f"Error: {e}")
        return ""

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 yt_transcript.py <YouTube-URL>")
        sys.exit(1)
    
    url = sys.argv[1]
    fetch_transcript(url, True)
PYTHON_EOF

# ----- Video Downloader Script -----
cat > "$DATA_DIR/yt_video.py" << 'PYTHON_EOF'
#!/usr/bin/env python3.10
import sys
import re
import subprocess
import os
from yt_dlp import YoutubeDL
from pathlib import Path

def sanitize_filename(name):
    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def progress_hook(d):
    if d['status'] == 'downloading':
        total_bytes = d.get('total_bytes') or d.get('total_bytes_estimate')
        downloaded_bytes = d.get('downloaded_bytes', 0)
        if total_bytes:
            percent = downloaded_bytes / total_bytes * 100
            print(f"\rDownloading: {percent:.1f}%", end='', flush=True)
    elif d['status'] == 'finished':
        print("\nDownload finished!")

def download_video(url, quality="1080"):
    downloads_path = Path("/opt/winejs/data/y2mate/downloads")
    downloads_path.mkdir(parents=True, exist_ok=True)

    print(f"🚀 YouTube Downloader - Downloading {quality}p...")
    
    try:
        with YoutubeDL({'quiet': True}) as ydl:
            info = ydl.extract_info(url, download=False)
            title = sanitize_filename(info.get('title', 'video'))
            print(f"📺 Title: {title}")
        
        # Format selection based on quality
        if quality == "1080":
            format_spec = 'bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=1080]+bestaudio/best[height<=1080]'
        elif quality == "720":
            format_spec = 'best[height<=720]'
        elif quality == "480":
            format_spec = 'best[height<=480]'
        elif quality == "360":
            format_spec = 'best[height<=360]'
        elif quality == "240":
            format_spec = 'best[height<=240]'
        else:
            format_spec = 'bestvideo[height<=1080]+bestaudio/best[height<=1080]'
        
        output_file = downloads_path / f"{title}.mp4"
        
        ydl_opts = {
            'format': format_spec,
            'outtmpl': str(downloads_path / f"{title}.%(ext)s"),
            'progress_hooks': [progress_hook],
            'merge_output_format': 'mp4',
            'noplaylist': True,
            'quiet': False,
        }
        
        with YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
        
        # Find downloaded file
        downloaded_files = list(downloads_path.glob(f"{title}.*"))
        if downloaded_files:
            final_file = downloaded_files[0]
            file_size = final_file.stat().st_size // (1024 * 1024)
            print(f"\n✨ Download completed!")
            print(f"📁 File: {final_file.name}")
            print(f"💾 Size: {file_size}MB")
            return str(final_file)
        else:
            raise Exception("Could not find downloaded file")
            
    except Exception as e:
        print(f"❌ Download failed: {e}")
        raise

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 yt_video.py <YouTube-URL> [quality]")
        sys.exit(1)
    
    url = sys.argv[1]
    quality = sys.argv[2] if len(sys.argv) > 2 else "1080"
    download_video(url, quality)
PYTHON_EOF

# ----- Audio Downloader Script -----
cat > "$DATA_DIR/yt_audio.py" << 'PYTHON_EOF'
#!/usr/bin/env python3.10
import sys
import re
from yt_dlp import YoutubeDL
from pathlib import Path
import lameenc
import audioread
import wave

def sanitize_filename(name):
    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def progress_hook(d):
    if d['status'] == 'downloading':
        total_bytes = d.get('total_bytes') or d.get('total_bytes_estimate')
        downloaded_bytes = d.get('downloaded_bytes', 0)
        if total_bytes:
            percent = downloaded_bytes / total_bytes * 100
            print(f"\rDownloading: {percent:.1f}%", end='', flush=True)
    elif d['status'] == 'finished':
        print("\nDownload finished, now converting...")

def decode_with_audioread(input_file):
    """Decode any audio file into PCM16."""
    pcm_chunks = []
    samplerate = None
    channels = None
    with audioread.audio_open(str(input_file)) as f:
        samplerate = f.samplerate
        channels = f.channels
        for buf in f:
            pcm_chunks.append(buf)
    return b"".join(pcm_chunks), samplerate, channels

def convert_to_mp3(input_file, output_file, bitrate=192):
    pcm_bytes, samplerate, channels = decode_with_audioread(input_file)
    if len(pcm_bytes) % 2 != 0:
        pcm_bytes = pcm_bytes[:-1]
    encoder = lameenc.Encoder()
    encoder.set_bit_rate(bitrate)
    encoder.set_in_sample_rate(samplerate)
    encoder.set_channels(channels)
    encoder.set_quality(2)
    mp3_data = encoder.encode(pcm_bytes)
    mp3_data += encoder.flush()
    with open(output_file, "wb") as f:
        f.write(mp3_data)
    print(f"MP3 saved to {output_file}")

def download_audio(url, bitrate="192"):
    downloads_path = Path("/opt/winejs/data/y2mate/downloads")
    downloads_path.mkdir(parents=True, exist_ok=True)

    with YoutubeDL({'quiet': True}) as ydl:
        info = ydl.extract_info(url, download=False)
    title = sanitize_filename(info.get('title', 'audio'))

    temp_file = downloads_path / f"{title}.m4a"
    outtmpl = str(temp_file)

    ydl_opts = {
        'format': 'bestaudio[ext=m4a]/bestaudio/best',
        'outtmpl': outtmpl,
        'noplaylist': True,
        'quiet': False,
        'progress_hooks': [progress_hook],
    }

    with YoutubeDL(ydl_opts) as ydl:
        print(f"Downloading '{title}'...")
        ydl.download([url])

    final_file = downloads_path / f"{title}.mp3"
    convert_to_mp3(temp_file, final_file, int(bitrate))

    temp_file.unlink(missing_ok=True)
    print(f"File saved to: {final_file}")
    return str(final_file)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 yt_audio.py <YouTube-URL> [bitrate]")
        sys.exit(1)
    
    url = sys.argv[1]
    bitrate = sys.argv[2] if len(sys.argv) > 2 else "192"
    download_audio(url, bitrate)
PYTHON_EOF

chmod +x "$DATA_DIR"/*.py

# ============= CREATE API SERVER =============
log "Creating API server..."

cat > "$DATA_DIR/server.js" << 'JAVASCRIPT_EOF'
const express = require('express');
const { exec } = require('child_process');
const util = require('util');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');

const execPromise = util.promisify(exec);
const app = express();
const PORT = process.env.PORT || 3003;

const DOWNLOADS_DIR = '/opt/winejs/data/y2mate/downloads';
const TRANSCRIPTS_DIR = '/opt/winejs/data/y2mate/transcripts';

// Ensure directories exist
fs.mkdir(DOWNLOADS_DIR, { recursive: true }).catch(() => {});
fs.mkdir(TRANSCRIPTS_DIR, { recursive: true }).catch(() => {});

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve frontend
app.get('/', async (req, res) => {
    try {
        const htmlPath = '/opt/winejs/apps/y2mate/frontend.html';
        let html = await fs.readFile(htmlPath, 'utf8');
        res.setHeader('Content-Type', 'text/html');
        res.send(html);
    } catch (err) {
        res.status(500).send('Frontend not found');
    }
});

// Clean old downloads (older than 1 hour)
async function cleanupOldFiles() {
    try {
        const files = await fs.readdir(DOWNLOADS_DIR);
        const now = Date.now();
        for (const file of files) {
            const filePath = path.join(DOWNLOADS_DIR, file);
            const stat = await fs.stat(filePath);
            if (now - stat.mtimeMs > 3600000) {
                await fs.unlink(filePath).catch(() => {});
                console.log(`Cleaned up: ${file}`);
            }
        }
    } catch (err) {}
}

setInterval(cleanupOldFiles, 1800000);

// Download video endpoint
app.post('/api/download/video', async (req, res) => {
    const { url, quality } = req.body;
    
    if (!url) {
        return res.status(400).json({ error: 'URL is required' });
    }
    
    const taskId = crypto.randomBytes(8).toString('hex');
    
    // Start async download
    (async () => {
        try {
            const scriptPath = '/opt/winejs/data/y2mate/yt_video.py';
            const command = `python3 ${scriptPath} "${url}" ${quality || '1080'}`;
            const { stdout, stderr } = await execPromise(command, { timeout: 300000 });
            console.log(`Task ${taskId} completed: ${stdout}`);
        } catch (err) {
            console.error(`Task ${taskId} failed: ${err.message}`);
        }
    })();
    
    res.json({ 
        taskId, 
        message: 'Download started',
        statusUrl: `/api/status/${taskId}`
    });
});

// Download audio endpoint
app.post('/api/download/audio', async (req, res) => {
    const { url, bitrate } = req.body;
    
    if (!url) {
        return res.status(400).json({ error: 'URL is required' });
    }
    
    const taskId = crypto.randomBytes(8).toString('hex');
    
    (async () => {
        try {
            const scriptPath = '/opt/winejs/data/y2mate/yt_audio.py';
            const command = `python3 ${scriptPath} "${url}" ${bitrate || '192'}`;
            const { stdout, stderr } = await execPromise(command, { timeout: 300000 });
            console.log(`Task ${taskId} completed: ${stdout}`);
        } catch (err) {
            console.error(`Task ${taskId} failed: ${err.message}`);
        }
    })();
    
    res.json({ 
        taskId, 
        message: 'Download started',
        statusUrl: `/api/status/${taskId}`
    });
});

// Get transcript endpoint
app.post('/api/transcript', async (req, res) => {
    const { url } = req.body;
    
    if (!url) {
        return res.status(400).json({ error: 'URL is required' });
    }
    
    try {
        const scriptPath = '/opt/winejs/data/y2mate/yt_transcript.py';
        const command = `python3 ${scriptPath} "${url}"`;
        const { stdout, stderr } = await execPromise(command, { timeout: 60000 });
        
        res.json({ 
            success: true,
            output: stdout,
            transcript: stdout
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// List downloaded files
app.get('/api/files', async (req, res) => {
    try {
        const files = await fs.readdir(DOWNLOADS_DIR);
        const fileInfo = await Promise.all(files.map(async (file) => {
            const filePath = path.join(DOWNLOADS_DIR, file);
            const stat = await fs.stat(filePath);
            return {
                name: file,
                size: stat.size,
                modified: stat.mtime,
                url: `/api/downloads/${encodeURIComponent(file)}`
            };
        }));
        res.json({ files: fileInfo });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Serve downloaded files
app.get('/api/downloads/:filename', async (req, res) => {
    const filename = req.params.filename;
    const filepath = path.join(DOWNLOADS_DIR, filename);
    
    try {
        await fs.access(filepath);
        res.download(filepath);
    } catch (err) {
        res.status(404).json({ error: 'File not found' });
    }
});

// Delete file
app.delete('/api/files/:filename', async (req, res) => {
    const filename = req.params.filename;
    const filepath = path.join(DOWNLOADS_DIR, filename);
    
    try {
        await fs.unlink(filepath);
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'OK', service: 'y2mate' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ Y2Mate API Server running on port ${PORT}`);
});
JAVASCRIPT_EOF

cd "$DATA_DIR"
npm init -y
npm install express multer

# ============= CREATE FRONTEND HTML =============
log "Creating frontend interface..."


# ============= CREATE FRONTEND HTML =============
log "Creating frontend interface..."

cat > "$APP_DIR/frontend.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">

<head>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8">
    <meta charset="utf-8">
    <meta content="width=device-width, initial-scale=1.0" name="viewport">
    <title>YouTube Video Downloader - Y2Mate</title>

    <link rel="icon" href="https://cdn.gitgpt.chat/rtx/images/y2mate-fav.png" type="image/png">
    <link rel="apple-touch-icon" href="https://cdn.gitgpt.chat/rtx/images/y2mate-fav.png" sizes="180x180">
    <link rel="icon" type="image/png" href="https://cdn.gitgpt.chat/rtx/images/y2mate-fav.png" sizes="192x192">
    <link rel="icon" type="image/png" href="https://cdn.gitgpt.chat/rtx/images/y2mate-fav.png" sizes="512x512">
    <meta itemprop="name" content="YouTube Video Downloader - Y2Mate">
    <meta property="og:title" content="YouTube Video Downloader - Y2Mate">
    <meta property="og:url" content="">
    <meta property="og:type" content="website">
    <meta name="twitter:title" content="YouTube Video Downloader - Y2Mate">
    <meta name="twitter:card" content="summary_large_image">
    <meta
        content="Y2Mate is a free and safe YouTube video downloader, allowing you to easily convert and download YouTube videos to MP4 or MP3 formats without ads."
        name="description">
    <link href="https://fonts.googleapis.com/" rel="preconnect">
    <style>
        @font-face {
            font-family: 'Dosis';
            src: url('/static/fonts/Dosis-Regular.ttf') format('truetype');
            font-weight: 400;
            font-style: normal
        }

        @font-face {
            font-family: 'Dosis';
            src: url('/static/fonts/Dosis-Bold.ttf') format('truetype');
            font-weight: 700;
            font-style: normal
        }

        @font-face {
            font-family: 'Dosis';
            src: url('/static/fonts/Dosis-Light.ttf') format('truetype');
            font-weight: 300;
            font-style: normal
        }

        @font-face {
            font-family: 'Dosis';
            src: url('/static/fonts/Dosis-Medium.ttf') format('truetype');
            font-weight: 500;
            font-style: normal
        }

        @font-face {
            font-family: 'Dosis';
            src: url('/static/fonts/Dosis-SemiBold.ttf') format('truetype');
            font-weight: 600;
            font-style: normal
        }

        @font-face {
            font-family: 'Dosis';
            src: url('/static/fonts/Dosis-ExtraBold.ttf') format('truetype');
            font-weight: 800;
            font-style: normal
        }

        body {
            font-family: "Dosis", serif;
            font-style: normal;
            margin: 0;
            padding: 0;
            color: #555;
            margin: 0 auto;
            background-color: #fff
        }

        h1, h2, h3, h4 {
            font-weight: 700;
            text-align: center;
            padding: 0;
            margin: 1rem
        }

        h2, h3, h4 {
            font-size: 18px
        }

        header {
            min-height: 120px !important;
            padding: 5px;
            text-align: center
        }

        a {
            text-decoration: none;
            color: #555
        }

        #darkModeSwitch {
            cursor: pointer
        }

        #menu {
            display: flex;
            justify-content: center;
            align-items: center
        }

        #menu>* {
            margin-inline: 20px;
            color: #eee
        }

        footer #menu>* {
            margin-inline: 20px;
            color: #000
        }

        footer {
            padding-bottom: 10px
        }

        #main {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            max-width: 600px;
            margin: auto;
            padding: 0 20px;
            box-shadow: 0 0 10px rgba(0, 0, 0, .1);
            text-align: center;
            border-radius: 10px
        }

        .tagline {
            font-weight: 400;
            line-height: 26px;
            font-size: 18px
        }

        .dark-mode .tagline {
            color: #AAFFB7
        }

        a:hover {
            color: #000 !important
        }

        header #menu>*:hover,
        #article a:hover,
        .dark-mode footer #menu>*:hover {
            color: #ccc !important
        }

        .dark-mode #url {
            background-color: #000 !important;
            color: #CCC !important;
            border: 1px solid #333;
            box-shadow: 0 0 20px rgba(255, 255, 255, .2)
        }

        .dark-mode select {
            background-color: #000 !important;
            color: #CCC !important
        }

        .dark-mode option {
            background-color: #000 !important;
            color: #CCC !important
        }

        #main #form {
            width: 500px;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            margin: 1rem;
            min-height: 300px
        }

        #form select {
            font-size: 16px !important
        }

        #quality-selector {
            width: 100%;
            min-height: 100px;
            display: flex;
            justify-content: space-evenly !important;
            align-items: center;
            margin-bottom: 1rem;
            flex-wrap: wrap;
            gap: 15px
        }

        #title {
            height: 28px
        }

        #url {
            width: 400px;
            padding: 15px;
            border: none;
            font-size: 16px !important;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0, 0, 0, .1);
            transition: box-shadow .3s ease
        }

        #url:focus {
            outline: none;
            box-shadow: 0 2px 10px rgba(0, 0, 0, .2)
        }

        .loading-spinner {
            border: 4px solid rgba(255, 255, 255, .5);
            border-radius: 50%;
            border-top: 4px solid #000;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: auto
        }

        @keyframes spin {
            0% { transform: rotate(0deg) }
            100% { transform: rotate(360deg) }
        }

        .gradient {
            background-image: linear-gradient(to left, #000, #000);
            color: white
        }

        #convert-button,
        #home-button,
        .action-button {
            display: block;
            background-color: #94c280;
            margin: auto;
            color: #000 !important;
            border: none;
            padding: 10px 20px;
            border-radius: 6px;
            font-size: 18px;
            cursor: pointer
        }

        #convert-button:hover,
        .action-button:hover {
            opacity: .85
        }

        #convert-button {
            font-size: 16px !important
        }

        #convert-button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }

        .d-none {
            display: none !important
        }

        .d-block {
            display: block !important
        }

        #home-button {
            background-color: #ffffff;
            color: #222 !important;
            text-decoration: underline
        }

        #format,
        #mp3-quality,
        #mp4-quality {
            border: none;
            border-radius: 6px;
            color: #333;
            background-color: #eee;
            height: 35px;
            border: 1px solid #eee
        }

        .dark-mode #format,
        .dark-mode #mp3-quality,
        .dark-mode #mp4-quality {
            border: 1px solid #333
        }

        #mp3-quality,
        #mp4-quality {
            width: 130px
        }

        #mp4, #transcript-options {
            display: none
        }

        #article {
            max-width: 600px;
            margin: auto;
            padding: 20px;
            line-height: 24px
        }

        #article p {
            text-align: justify
        }

        body.dark-mode {
            background-color: #000;
            color: #CCC
        }

        .dark-mode a,
        .dark-mode footer a {
            color: #eee !important
        }

        h1 {
            font-size: 24px !important
        }

        .dark-mode h1 {
            font-size: 24px !important;
            color: #ccc !important
        }

        .dark-mode #article a {
            color: #CCC !important
        }

        .result {
            margin-top: 15px;
            padding: 10px;
            border-radius: 5px;
            display: none;
            width: 100%;
            text-align: center;
        }

        .result.success {
            background: #d4edda;
            color: #155724;
            display: block;
        }

        .result.error {
            background: #f8d7da;
            color: #721c24;
            display: block;
        }

        .result.loading {
            background: #e7f3ff;
            color: #004085;
            display: block;
        }

        .transcript-text {
            background: #f5f5f5;
            padding: 15px;
            border-radius: 8px;
            max-height: 300px;
            overflow-y: auto;
            font-family: monospace;
            font-size: 12px;
            white-space: pre-wrap;
            text-align: left;
            margin-top: 15px;
        }

        .dark-mode .transcript-text {
            background: #1a1a1a;
            color: #ccc;
        }

        .copy-btn {
            background: #94c280;
            color: #000;
            border: none;
            padding: 8px 16px;
            border-radius: 5px;
            cursor: pointer;
            margin-top: 10px;
            font-family: "Dosis", serif;
            font-weight: 600;
        }

        .files-list, .playlist-files-list {
            margin-top: 15px;
            max-height: 300px;
            overflow-y: auto;
        }

        .file-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px;
            border-bottom: 1px solid #eee;
        }

        .dark-mode .file-item {
            border-bottom-color: #333;
        }

        .file-name {
            font-weight: 500;
            word-break: break-all;
            font-size: 14px;
        }

        .file-size {
            color: #666;
            font-size: 12px;
        }

        .dark-mode .file-size {
            color: #999;
        }

        .file-actions {
            display: flex;
            gap: 8px;
        }

        .file-actions a, .file-actions button {
            padding: 4px 10px;
            font-size: 12px;
            border-radius: 4px;
            text-decoration: none;
            background: #94c280;
            color: #000;
            border: none;
            cursor: pointer;
        }

        .file-actions button {
            background: #dc3545;
            color: white;
        }

        .refresh-btn, .playlist-refresh-btn {
            background: #94c280;
            color: #000;
            border: none;
            padding: 8px 16px;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
            font-family: "Dosis", serif;
            font-weight: 600;
        }

        .playlist-url-input {
            width: 100%;
            padding: 12px;
            margin: 10px 0;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            background: #fff;
        }

        .dark-mode .playlist-url-input {
            background: #000;
            color: #ccc;
            border-color: #333;
        }

        .progress-bar {
            width: 100%;
            background: #eee;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }

        .progress-fill {
            background: #94c280;
            height: 20px;
            width: 0%;
            transition: width 0.3s;
        }

        @media only screen and (max-width:780px) {
            #url {
                width: 280px;
                padding: 12px !important;
            }
            #main #form {
                width: 100%;
                max-width: 350px;
            }
            #quality-selector {
                flex-direction: column;
                gap: 10px;
            }
        }
    </style>
</head>

<body class="dark-mode">
    <header class="gradient">
        <a href="/y2mate">
            <img alt="logo" id="logo" loading="lazy" src="https://cdn.gitgpt.chat/rtx/images/y2mate-logo.png" width="200px">
        </a>
        <div id="menu" style="display: none;">
            <p id="darkModeSwitch" aria-label="Switch to light mode">Light Mode ☼</p>
        </div>
    </header>
    <div id="main">
        <h1 id="title">YouTube Video Downloader</h1>
        <p class="tagline">100% safe, Ad-free YouTube to MP3, MP4, and Transcript converter</p>
        <div id="form">
            <input autocomplete="off" id="url" placeholder="Paste YouTube URL or Playlist URL..." type="text">
            <div id="quality-selector">
                <div id="format-box">
                    <p>Format</p>
                    <select aria-label="format" id="format">
                        <option value="mp3" selected="selected">MP3</option>
                        <option value="mp4">MP4</option>
                        <option value="transcript">Transcript (VTT)</option>
                    </select>
                </div>
                <div id="mp3">
                    <p>MP3 quality</p>
                    <select aria-label="mp3-quality" id="mp3-quality">
                        <option value="64">64k</option>
                        <option value="96">96k</option>
                        <option value="128" selected="selected">128k</option>
                        <option value="192">192k</option>
                        <option value="256">256k</option>
                        <option value="320">320k</option>
                    </select>
                </div>
                <div id="mp4">
                    <p>MP4 quality</p>
                    <select aria-label="mp4-quality" id="mp4-quality">
                        <option value="240">240p</option>
                        <option value="360">360p</option>
                        <option value="480">480p</option>
                        <option value="720">720p</option>
                        <option value="1080" selected="selected">1080p</option>
                    </select>
                </div>
                <div id="transcript-options">
                    <p>Transcript format</p>
                    <select id="transcript-format">
                        <option value="text">Plain Text</option>
                        <option value="vtt">VTT File</option>
                    </select>
                </div>
            </div>
            <button aria-label="convert" id="convert-button" type="submit">Download</button>
            <div id="download-result" class="result"></div>
        </div>
    </div>

    <!-- Playlist Bulk Download Section -->
    <div id="main" style="margin-top: 20px;">
        <h3>📋 Bulk Download Playlist</h3>
        <div id="form">
            <input autocomplete="off" id="playlist-url" placeholder="Paste YouTube Playlist URL..." type="text" style="width: 400px;">
            <div style="display: flex; gap: 10px; margin-top: 10px;">
                <button id="download-playlist-btn" class="refresh-btn">Download All Videos</button>
                <button id="download-playlist-audio-btn" class="refresh-btn">Download All Audio</button>
                <button id="get-playlist-transcript-btn" class="refresh-btn">Get All Transcripts</button>
            </div>
            <div id="playlist-progress" class="progress-bar" style="display: none;">
                <div id="playlist-progress-fill" class="progress-fill"></div>
            </div>
            <div id="playlist-result" class="result"></div>
            <div id="playlist-files-list" class="playlist-files-list" style="max-height: 200px;"></div>
        </div>
    </div>

    <!-- Files Section -->
    <div id="main" style="margin-top: 20px;">
        <h3>📁 My Downloads</h3>
        <div id="form">
            <button id="refresh-files-btn" class="refresh-btn">Refresh Files</button>
            <div id="files-list" class="files-list"></div>
        </div>
    </div>

    <div id="article">
        <h2>Y2Mate: YouTube Video Downloader, Free and Safe YouTube to MP3, MP4 and Transcript Extractor</h2>
        <p>You're looking for a reliable YouTube video downloading tool that's lightning speed as well as ad-free and safe, and completely cost-free? Let me introduce <a href="/y2mate">Y2Mate</a>, the most powerful YT downloader and YouTube converter. Our tool is created to make it easy for you to download YouTube video clips, and convert them into MP3 or MP4 and stream your favourite video content offline within a few just a few seconds.</p>
        <h3>Why Choose Y2Mate?</h3>
        <ul>
            <li><p>Ad-Free and 100% Safe: In contrast to many other online tools, Y2Mate is completely free of intrusive advertisements, pop-ups, malware, and other ads. Downloads are secure as well as secure and easy to use.</p></li>
            <li><p>Lightning-Fast and User-Friendly: Copy a YouTube (or shorts) URL. Select the format you prefer -- YouTube to MP4, YouTube to MP3, or Transcript -- and you can download it instantly. There is no registration or waiting.</p></li>
            <li><p>Multiple Formats and Quality Options: Download videos with MP4 resolutions ranging from 240p up to 1080p. Or convert audio to high-quality MP3 (up to 320kbps). Or extract video transcripts as VTT files.</p></li>
            <li><p>Bulk Playlist Download: Download entire playlists at once - videos, audio, or transcripts!</p></li>
            <li><p>URL Parameters: Use ?url=VIDEO_URL&format=mp4 to auto-start downloads via hyperlinks.</p></li>
            <li><p>Works on Any Device: The browser-based Y2Mate app is compatible with Windows, Mac, Android as well as iOS with no need for additional software.</p></li>
        </ul>
        <h3>URL Parameters (For Hyperlinks)</h3>
        <ul>
            <li><code>?url=YOUTUBE_URL</code> - Auto-fill the URL</li>
            <li><code>&format=mp4</code> - Select MP4 format</li>
            <li><code>&format=mp3</code> - Select MP3 format</li>
            <li><code>&format=transcript</code> - Select Transcript format</li>
            <li><code>&quality=1080</code> - Set video quality</li>
            <li><code>&bitrate=320</code> - Set audio bitrate</li>
            <li><code>&auto=true</code> - Automatically start download/transcript</li>
        </ul>
        <p><strong>Example:</strong> <code>https://yourdomain.com/y2mate/?url=https://youtu.be/VIDEO_ID&format=mp4&auto=true</code></p>
        <h3>How It Works</h3>
        <ol>
            <li>Copy a YouTube or Shorts URL (or Playlist URL).</li>
            <li>Paste it into the Y2Mate search box.</li>
            <li>Select MP4, MP3, or Transcript format.</li>
            <li>Select your preferred quality.</li>
            <li>Click Download - Your media file will be downloaded immediately.</li>
        </ol>
        <h3>Why Y2Mate Stands Out</h3>
        <ul>
            <li>No ads, no pop-ups -- ever.</li>
            <li>Secure and private downloads. <em>Unlimited downloads and conversions.</em></li>
            <li>Free forever -- no hidden charges.</li>
            <li>Bulk playlist download support!</li>
        </ul>
    </div>

    <script>
        // ============================================
        // Y2MATE YOUTUBE DOWNLOADER WITH TRANSCRIPT & PLAYLIST SUPPORT
        // ============================================

        const API_BASE = '';

        // DOM Elements
        const urlInput = document.getElementById("url");
        const convertButton = document.getElementById("convert-button");
        const formatSelect = document.getElementById("format");
        const mp3QualitySelect = document.getElementById("mp3-quality");
        const mp4QualitySelect = document.getElementById("mp4-quality");
        const transcriptFormatSelect = document.getElementById("transcript-format");
        const mp3Div = document.getElementById("mp3");
        const mp4Div = document.getElementById("mp4");
        const transcriptDiv = document.getElementById("transcript-options");
        const darkModeSwitch = document.getElementById("darkModeSwitch");

        // ============================================
        // THEME MANAGEMENT
        // ============================================
        function initTheme() {
            const savedTheme = localStorage.getItem("theme");
            if (savedTheme === "light") {
                document.body.classList.remove("dark-mode");
                if (darkModeSwitch) darkModeSwitch.textContent = "Dark Mode ☾";
            } else {
                document.body.classList.add("dark-mode");
                if (darkModeSwitch) darkModeSwitch.textContent = "Light Mode ☼";
            }
        }

        if (darkModeSwitch) {
            darkModeSwitch.addEventListener("click", () => {
                if (document.body.classList.contains("dark-mode")) {
                    document.body.classList.remove("dark-mode");
                    localStorage.setItem("theme", "light");
                    darkModeSwitch.textContent = "Dark Mode ☾";
                } else {
                    document.body.classList.add("dark-mode");
                    localStorage.setItem("theme", "dark");
                    darkModeSwitch.textContent = "Light Mode ☼";
                }
            });
        }

        // ============================================
        // FORMAT SWITCHING (MP3/MP4/TRANSCRIPT)
        // ============================================
        function handleFormatChange() {
            const format = formatSelect.value;
            mp3Div.style.display = format === "mp3" ? "block" : "none";
            mp4Div.style.display = format === "mp4" ? "block" : "none";
            transcriptDiv.style.display = format === "transcript" ? "block" : "none";

            localStorage.setItem("preferredFormat", format);
            localStorage.setItem("preferredMp3Quality", mp3QualitySelect.value);
            localStorage.setItem("preferredMp4Quality", mp4QualitySelect.value);
        }

        function loadSavedPreferences() {
            const savedFormat = localStorage.getItem("preferredFormat");
            const savedMp3Quality = localStorage.getItem("preferredMp3Quality");
            const savedMp4Quality = localStorage.getItem("preferredMp4Quality");

            if (savedFormat) formatSelect.value = savedFormat;
            if (savedMp3Quality) mp3QualitySelect.value = savedMp3Quality;
            if (savedMp4Quality) mp4QualitySelect.value = savedMp4Quality;

            handleFormatChange();
        }

        // ============================================
        // URL VALIDATION
        // ============================================
        function extractVideoId(url) {
            const patterns = [
                /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
                /youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/,
                /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/
            ];
            for (const pattern of patterns) {
                const match = url.match(pattern);
                if (match) return match[1];
            }
            return null;
        }

        function extractPlaylistId(url) {
            const patterns = [
                /(?:youtube\.com\/playlist\?list=)([a-zA-Z0-9_-]+)/,
                /(?:youtube\.com\/watch\?.*list=)([a-zA-Z0-9_-]+)/,
                /(?:youtu\.be\/.*[?&]list=)([a-zA-Z0-9_-]+)/
            ];
            for (const pattern of patterns) {
                const match = url.match(pattern);
                if (match) return match[1];
            }
            return null;
        }

        function isValidYouTubeUrl(url) {
            if (!url || url.trim() === "") return false;
            return extractVideoId(url) !== null;
        }

        function isPlaylistUrl(url) {
            return extractPlaylistId(url) !== null;
        }

        // ============================================
        // UI HELPERS
        // ============================================
        function showResult(element, message, type) {
            if (!element) return;
            element.innerHTML = message;
            element.classList.remove('success', 'error', 'loading');
            element.classList.add(type);
        }

        function showLoading() {
            convertButton.textContent = "Processing...";
            convertButton.disabled = true;
        }

        function hideLoading() {
            convertButton.textContent = "Download";
            convertButton.disabled = false;
        }

        // ============================================
        // TRANSCRIPT HANDLER
        // ============================================
        async function getTranscript(url, format = "text") {
            try {
                const response = await fetch(`${API_BASE}/api/transcript`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ url, format })
                });
                const data = await response.json();
                return data;
            } catch (err) {
                throw new Error(err.message);
            }
        }

        // ============================================
        // DOWNLOAD HANDLER
        // ============================================
        async function handleConversion() {
            const videoUrl = urlInput.value.trim();
            const resultDiv = document.getElementById("download-result");

            if (!videoUrl) {
                showResult(resultDiv, "Please enter a YouTube URL", "error");
                return;
            }

            if (isPlaylistUrl(videoUrl)) {
                showResult(resultDiv, "Playlist detected! Please use the Playlist section below for bulk download.", "error");
                return;
            }

            if (!isValidYouTubeUrl(videoUrl)) {
                showResult(resultDiv, "Please enter a valid YouTube URL", "error");
                return;
            }

            const format = formatSelect.value;
            const quality = format === "mp3" ? mp3QualitySelect.value : mp4QualitySelect.value;
            const transcriptFormat = transcriptFormatSelect ? transcriptFormatSelect.value : "text";

            showLoading();
            showResult(resultDiv, "Processing... This may take a moment.", "loading");

            try {
                if (format === "transcript") {
                    // Handle transcript
                    const data = await getTranscript(videoUrl, transcriptFormat);
                    if (data.success) {
                        if (transcriptFormat === "vtt" && data.downloadUrl) {
                            window.location.href = data.downloadUrl;
                            showResult(resultDiv, "✅ Transcript file downloaded!", "success");
                        } else {
                            // Show text transcript
                            const transcriptText = data.transcript || data.output || "No transcript available";
                            resultDiv.innerHTML = `
                                <div class="transcript-text">${escapeHtml(transcriptText)}</div>
                                <button class="copy-btn" onclick="copyToClipboard('${escapeHtml(transcriptText).replace(/'/g, "\\'")}')">📋 Copy to Clipboard</button>
                            `;
                            resultDiv.classList.add('success');
                            resultDiv.classList.remove('loading', 'error');
                        }
                        urlInput.value = "";
                    } else {
                        showResult(resultDiv, data.error || "Failed to get transcript", "error");
                    }
                } else {
                    // Handle video/audio download
                    const endpoint = format === "mp3" ? "/api/download/audio" : "/api/download/video";
                    const body = format === "mp3" 
                        ? { url: videoUrl, bitrate: quality }
                        : { url: videoUrl, quality: quality };

                    const response = await fetch(`${API_BASE}${endpoint}`, {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify(body)
                    });

                    const data = await response.json();

                    if (response.ok) {
                        showResult(resultDiv, "✅ Download started! Check 'My Downloads' tab.", "success");
                        urlInput.value = "";
                        setTimeout(loadFiles, 2000);
                    } else {
                        showResult(resultDiv, data.error || "Download failed", "error");
                    }
                }
            } catch (err) {
                showResult(resultDiv, "Network error: " + err.message, "error");
            } finally {
                hideLoading();
            }
        }

        window.copyToClipboard = function(text) {
            navigator.clipboard.writeText(text);
            alert("Transcript copied to clipboard!");
        };

        // ============================================
        // FILES HANDLER
        // ============================================
        async function loadFiles() {
            const filesDiv = document.getElementById("files-list");
            if (!filesDiv) return;

            filesDiv.innerHTML = '<div style="text-align: center; padding: 20px;">Loading...</div>';

            try {
                const response = await fetch(`${API_BASE}/api/files`);
                const data = await response.json();

                if (data.files && data.files.length > 0) {
                    filesDiv.innerHTML = data.files.map(file => `
                        <div class="file-item">
                            <div>
                                <div class="file-name">${escapeHtml(file.name)}</div>
                                <div class="file-size">${formatBytes(file.size)}</div>
                            </div>
                            <div class="file-actions">
                                <a href="${API_BASE}/api/downloads/${encodeURIComponent(file.name)}">Download</a>
                                <button onclick="deleteFile('${escapeHtml(file.name)}')">Delete</button>
                            </div>
                        </div>
                    `).join('');
                } else {
                    filesDiv.innerHTML = '<div style="text-align: center; padding: 20px; color: #666;">No files downloaded yet</div>';
                }
            } catch (err) {
                filesDiv.innerHTML = '<div style="text-align: center; padding: 20px; color: red;">Failed to load files</div>';
            }
        }

        window.deleteFile = async (filename) => {
            if (confirm(`Delete ${filename}?`)) {
                try {
                    await fetch(`${API_BASE}/api/files/${encodeURIComponent(filename)}`, { method: 'DELETE' });
                    loadFiles();
                } catch (err) {
                    alert('Failed to delete file');
                }
            }
        };

        // ============================================
        // PLAYLIST BULK DOWNLOAD
        // ============================================
        async function downloadPlaylist(format, resultDiv, progressDiv, progressFill) {
            const playlistUrl = document.getElementById("playlist-url").value.trim();
            
            if (!playlistUrl) {
                alert("Please enter a YouTube Playlist URL");
                return false;
            }

            const playlistId = extractPlaylistId(playlistUrl);
            if (!playlistId) {
                alert("Invalid playlist URL");
                return false;
            }

            const quality = format === "mp3" ? mp3QualitySelect.value : mp4QualitySelect.value;
            const transcriptFormat = transcriptFormatSelect ? transcriptFormatSelect.value : "text";

            showResult(resultDiv, `Processing playlist... This may take a while.`, "loading");
            progressDiv.style.display = "block";
            progressFill.style.width = "0%";

            try {
                const endpoint = format === "transcript" ? "/api/playlist/transcript" : 
                                (format === "mp3" ? "/api/playlist/audio" : "/api/playlist/video");
                
                const body = format === "transcript" 
                    ? { playlistUrl, format: transcriptFormat }
                    : format === "mp3"
                    ? { playlistUrl, bitrate: quality }
                    : { playlistUrl, quality };

                const response = await fetch(`${API_BASE}${endpoint}`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(body)
                });

                const data = await response.json();

                if (response.ok) {
                    showResult(resultDiv, `✅ Playlist processing started! ${data.totalVideos || 0} videos found. Check back in 'My Downloads'.`, "success");
                    
                    // Poll for status
                    if (data.batchId) {
                        pollPlaylistStatus(data.batchId, resultDiv, progressFill);
                    }
                    
                    document.getElementById("playlist-url").value = "";
                    setTimeout(loadFiles, 3000);
                } else {
                    showResult(resultDiv, data.error || "Playlist processing failed", "error");
                }
            } catch (err) {
                showResult(resultDiv, "Network error: " + err.message, "error");
            } finally {
                setTimeout(() => { progressDiv.style.display = "none"; }, 5000);
            }
        }

        async function pollPlaylistStatus(batchId, resultDiv, progressFill) {
            try {
                const response = await fetch(`${API_BASE}/api/playlist/status/${batchId}`);
                const data = await response.json();
                
                if (data.completed) {
                    showResult(resultDiv, `✅ Playlist complete! ${data.completedCount}/${data.totalCount} videos processed.`, "success");
                    progressFill.style.width = "100%";
                    loadFiles();
                    loadPlaylistFiles();
                } else if (data.error) {
                    showResult(resultDiv, `⚠️ Playlist had errors: ${data.error}`, "error");
                } else {
                    const percent = (data.completedCount / data.totalCount) * 100;
                    progressFill.style.width = `${percent}%`;
                    setTimeout(() => pollPlaylistStatus(batchId, resultDiv, progressFill), 3000);
                }
            } catch (err) {
                console.error("Status poll error:", err);
            }
        }

        async function loadPlaylistFiles() {
            const filesDiv = document.getElementById("playlist-files-list");
            if (!filesDiv) return;
            
            try {
                const response = await fetch(`${API_BASE}/api/files`);
                const data = await response.json();
                
                if (data.files && data.files.length > 0) {
                    const recentFiles = data.files.slice(-10);
                    filesDiv.innerHTML = '<div style="font-size: 12px; color: #666; margin-bottom: 5px;">Recent downloads:</div>' +
                        recentFiles.map(file => `
                            <div class="file-item">
                                <div class="file-name" style="font-size: 12px;">${escapeHtml(file.name)}</div>
                                <div class="file-actions">
                                    <a href="${API_BASE}/api/downloads/${encodeURIComponent(file.name)}" style="font-size: 11px;">Download</a>
                                </div>
                            </div>
                        `).join('');
                }
            } catch (err) {}
        }

        // ============================================
        // URL PARAMETER HANDLER
        // ============================================
        function handleUrlParameters() {
            const urlParams = new URLSearchParams(window.location.search);
            const videoUrl = urlParams.get('url');
            const format = urlParams.get('format');
            const quality = urlParams.get('quality');
            const bitrate = urlParams.get('bitrate');
            const auto = urlParams.get('auto') === 'true';
            
            if (videoUrl) {
                urlInput.value = videoUrl;
                
                if (format) {
                    if (format === 'mp4') formatSelect.value = 'mp4';
                    else if (format === 'mp3') formatSelect.value = 'mp3';
                    else if (format === 'transcript') formatSelect.value = 'transcript';
                    handleFormatChange();
                }
                
                if (quality && format === 'mp4') {
                    const qualitySelect = document.getElementById('mp4-quality');
                    if (qualitySelect && [...qualitySelect.options].some(opt => opt.value === quality)) {
                        qualitySelect.value = quality;
                    }
                }
                
                if (bitrate && format === 'mp3') {
                    const bitrateSelect = document.getElementById('mp3-quality');
                    if (bitrateSelect && [...bitrateSelect.options].some(opt => opt.value === bitrate)) {
                        bitrateSelect.value = bitrate;
                    }
                }
                
                if (auto) {
                    setTimeout(() => handleConversion(), 500);
                }
            }
        }

        // ============================================
        // UTILITIES
        // ============================================
        function formatBytes(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // ============================================
        // EVENT LISTENERS
        // ============================================
        function init() {
            loadSavedPreferences();
            initTheme();
            handleUrlParameters();

            convertButton.addEventListener("click", handleConversion);
            formatSelect.addEventListener("change", handleFormatChange);
            urlInput.addEventListener("keypress", (e) => {
                if (e.key === "Enter") handleConversion();
            });

            const refreshBtn = document.getElementById("refresh-files-btn");
            if (refreshBtn) refreshBtn.addEventListener("click", loadFiles);

            // Playlist buttons
            const playlistResultDiv = document.getElementById("playlist-result");
            const playlistProgressDiv = document.getElementById("playlist-progress");
            const playlistProgressFill = document.getElementById("playlist-progress-fill");
            
            const downloadPlaylistBtn = document.getElementById("download-playlist-btn");
            if (downloadPlaylistBtn) {
                downloadPlaylistBtn.addEventListener("click", () => {
                    downloadPlaylist("mp4", playlistResultDiv, playlistProgressDiv, playlistProgressFill);
                });
            }
            
            const downloadPlaylistAudioBtn = document.getElementById("download-playlist-audio-btn");
            if (downloadPlaylistAudioBtn) {
                downloadPlaylistAudioBtn.addEventListener("click", () => {
                    downloadPlaylist("mp3", playlistResultDiv, playlistProgressDiv, playlistProgressFill);
                });
            }
            
            const getPlaylistTranscriptBtn = document.getElementById("get-playlist-transcript-btn");
            if (getPlaylistTranscriptBtn) {
                getPlaylistTranscriptBtn.addEventListener("click", () => {
                    downloadPlaylist("transcript", playlistResultDiv, playlistProgressDiv, playlistProgressFill);
                });
            }

            loadFiles();
        }

        document.addEventListener("DOMContentLoaded", init);
    </script>
</body>
</html>
HTML_EOF

# Replace API base placeholder
sed -i "s|const API_BASE = '';|const API_BASE = window.location.origin + '/y2mate';|g" "$APP_DIR/frontend.html"

# New Features Added:
# 1. Transcript as a Format Option
#     Three formats now: MP4, MP3, and Transcript (VTT)
#     Transcript can be downloaded as Plain Text or VTT file
#     Copy transcript to clipboard with one click
# 2. URL Parameter Support (For Tampermonkey/Bookmarklets)
#     ?url=YOUTUBE_URL - Auto-fill the URL
#     &format=mp4|mp3|transcript - Select format
#     &quality=1080 - Set video quality
#     &bitrate=320 - Set audio bitrate
#     &auto=true - Automatically start download
# Example links:
# https://yourdomain.com/y2mate/?url=https://youtu.be/VIDEO_ID&format=mp4&auto=true
# https://yourdomain.com/y2mate/?url=https://youtu.be/VIDEO_ID&format=transcript&auto=true
# 3. Bulk Playlist Download
#     Download all videos in a playlist as MP4
#     Download all audio from a playlist as MP3
#     Extract all transcripts from a playlist
#     Progress bar shows download status
#     Polls server for batch completion
#     Shows recent downloads
# 4. Transcript Display
#     Shows transcript in a scrollable text box
#     Copy to clipboard button
#     Option to download as VTT file

# Add this to your Y2Mate installer script after the existing Python scripts

# ============= CREATE PLAYLIST TO MP4 CONVERTER SCRIPT =============
log "Creating Playlist to MP4 Converter script..."

cat > "$DATA_DIR/yt_playlist_to_mp4.py" << 'PYTHON_EOF'
#!/usr/bin/env python3.10
"""
YouTube Playlist to Single MP4 Converter
Downloads entire playlist, combines into one MP3, creates MP4 with cover art
"""

import os
import sys
import re
import time
import json
import subprocess
from pathlib import Path
from datetime import timedelta
from typing import List, Dict, Optional
from dataclasses import dataclass

# Try to import required packages
try:
    from yt_dlp import YoutubeDL
    from PIL import Image
    import requests
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "yt-dlp", "Pillow", "requests"])
    from yt_dlp import YoutubeDL
    from PIL import Image
    import requests

# Configuration
@dataclass
class Config:
    DOWNLOAD_DIR: Path = Path("/opt/winejs/data/y2mate/downloads")
    OUTPUT_DIR: Path = Path("/opt/winejs/data/y2mate/mp4_output")
    TEMP_DIR: Path = Path("/opt/winejs/data/y2mate/temp")
    
    def __post_init__(self):
        for dir_path in [self.DOWNLOAD_DIR, self.OUTPUT_DIR, self.TEMP_DIR]:
            dir_path.mkdir(exist_ok=True, parents=True)

config = Config()

# ==================== UTILITIES ====================
def sanitize_filename(name: str) -> str:
    name = re.sub(r'[<>:"/\\|?*]', '', name)
    name = re.sub(r'[\n\r\t]', ' ', name)
    return name.strip()[:200]

def format_time(seconds: float) -> str:
    td = timedelta(seconds=int(seconds))
    hours = td.seconds // 3600
    minutes = (td.seconds % 3600) // 60
    secs = td.seconds % 60
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"

def setup_cookie_handling():
    """Enhanced cookie handling with browser auto-detection and cookies.txt support"""
    
    # First, try to use cookies.txt file
    cookie_file = Path("/opt/winejs/data/y2mate/cookies.txt")
    if cookie_file.exists():
        print(f"🔑 Using cookies from: {cookie_file}")
        return {'cookiefile': str(cookie_file)}
    
    # Try to extract from browsers automatically
    browser_options = ['firefox', 'chrome', 'brave', 'edge', 'safari']
    for browser in browser_options:
        try:
            # Test if we can access this browser's cookies
            test_opts = {'cookiesfrombrowser': (browser,), 'quiet': True}
            with YoutubeDL(test_opts) as ydl:
                pass
            print(f"🔑 Using cookies from browser: {browser}")
            return {'cookiesfrombrowser': (browser,)}
        except Exception as e:
            print(f"  Could not use {browser}: {str(e)[:50]}")
            continue
    
    # If no cookies found, print helpful message
    print("⚠️  No cookies found! YouTube may block downloads.")
    print("💡 To fix this, either:")
    print("   1. Run: yt-dlp --cookies-from-browser firefox --cookies /opt/winejs/data/y2mate/cookies.txt")
    print("   2. Or export cookies from browser extension to /opt/winejs/data/y2mate/cookies.txt")
    print("   3. Or install Firefox/Chrome on this server and log into YouTube once")
    return {}

def extract_playlist_id(input_str: str) -> Optional[str]:
    input_str = input_str.strip()
    if 'youtube.com' in input_str or 'youtu.be' in input_str:
        if 'list=' in input_str:
            match = re.search(r'list=([a-zA-Z0-9_-]+)', input_str)
            if match:
                return match.group(1)
        return None
    if re.match(r'^[a-zA-Z0-9_-]+$', input_str):
        return input_str
    return None

# ==================== PLAYLIST EXTRACTION ====================
def extract_playlist_videos(playlist_id: str) -> List[Dict]:
    print(f"Extracting videos from playlist...", flush=True)
    
    playlist_url = f"https://www.youtube.com/playlist?list={playlist_id}"
    videos = []
    cookie_config = setup_cookie_handling()
    
    ydl_opts = {
        'quiet': True,
        'extract_flat': True,
        **cookie_config
    }
    
    try:
        with YoutubeDL(ydl_opts) as ydl:
            playlist_info = ydl.extract_info(playlist_url, download=False)
            if 'entries' in playlist_info:
                for idx, entry in enumerate(playlist_info['entries'], 1):
                    if entry:
                        video = {
                            'id': entry.get('id'),
                            'title': sanitize_filename(entry.get('title', f'video_{idx}')),
                            'url': f"https://www.youtube.com/watch?v={entry.get('id')}",
                            'duration': entry.get('duration', 0),
                            'index': idx
                        }
                        videos.append(video)
                        print(f"  [{idx}] {video['title'][:50]}...", flush=True)
        return videos
    except Exception as e:
        print(f"Failed: {e}", flush=True)
        return []

# ==================== AUDIO DOWNLOAD ====================
def download_audio(video_url: str, output_path: Path) -> Optional[Path]:
    print(f"  Downloading audio...", flush=True)
    
    cookie_config = setup_cookie_handling()
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': str(output_path.with_suffix('')),
        'quiet': True,
        'postprocessors': [],
        **cookie_config
    }
    
    try:
        with YoutubeDL(ydl_opts) as ydl:
            ydl.download([video_url])
        
        # Find downloaded file
        downloaded_file = None
        for ext in ['.webm', '.m4a', '.opus', '.ogg', '.mp4']:
            test_path = output_path.with_suffix(ext)
            if test_path.exists():
                downloaded_file = test_path
                break
        
        if not downloaded_file:
            return None
        
        # Convert to MP3 using ffmpeg
        mp3_path = output_path.with_suffix('.mp3')
        subprocess.run([
            'ffmpeg', '-y', '-i', str(downloaded_file),
            '-acodec', 'libmp3lame', '-ab', '192k',
            '-ar', '44100', '-ac', '2', str(mp3_path)
        ], capture_output=True)
        
        if mp3_path.exists():
            downloaded_file.unlink()
            return mp3_path
        return None
    except Exception as e:
        print(f"    Failed: {e}", flush=True)
        return None

# ==================== COMBINE MP3S ====================
def combine_mp3s(mp3_files: List[Path], output_path: Path) -> bool:
    print(f"Combining {len(mp3_files)} MP3 files...", flush=True)
    
    concat_file = config.TEMP_DIR / "concat_list.txt"
    with open(concat_file, 'w') as f:
        for mp3 in mp3_files:
            f.write(f"file '{mp3.absolute()}'\n")
    
    result = subprocess.run([
        'ffmpeg', '-y', '-f', 'concat', '-safe', '0',
        '-i', str(concat_file), '-c', 'copy', str(output_path)
    ], capture_output=True)
    
    concat_file.unlink()
    return result.returncode == 0 and output_path.exists()

# ==================== MP4 CREATION ====================
def create_mp4(mp3_path: Path, cover_url: str, output_path: Path, duration: float) -> bool:
    print(f"Creating MP4 video...", flush=True)
    
    # Download cover image
    temp_cover = config.TEMP_DIR / "cover.jpg"
    try:
        response = requests.get(cover_url, timeout=30)
        response.raise_for_status()
        temp_cover.write_bytes(response.content)
    except:
        return False
    
    # Create video with ffmpeg
    result = subprocess.run([
        'ffmpeg', '-y', '-loop', '1', '-i', str(temp_cover),
        '-i', str(mp3_path), '-c:v', 'libx264', '-c:a', 'aac',
        '-b:a', '192k', '-pix_fmt', 'yuv420p', '-shortest',
        '-t', str(duration), '-movflags', '+faststart', str(output_path)
    ], capture_output=True, timeout=600)
    
    temp_cover.unlink()
    return result.returncode == 0 and output_path.exists()

# ==================== TIMESTAMP GENERATION ====================
def generate_description(videos: List[Dict], playlist_title: str, total_duration: float) -> str:
    desc = f"{playlist_title}\n\n"
    for video in videos:
        # Option 1: Timestamp first (MOST RELIABLE - YouTube never fails this)
        desc += f"{format_time(video['start_time'])} {video['title']}\n"
    desc += f"\nTotal Duration: {format_time(total_duration)}\n"
    return desc

# ==================== MAIN ====================
def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: python yt_playlist_to_mp4.py PLAYLIST_ID COVER_URL [TITLE]"}))
        sys.exit(1)
    
    playlist_id = extract_playlist_id(sys.argv[1])
    cover_url = sys.argv[2]
    playlist_title = sys.argv[3] if len(sys.argv) > 3 else f"Playlist_{playlist_id[:8]}"
    
    if not playlist_id:
        print(json.dumps({"error": "Invalid playlist ID"}))
        sys.exit(1)
    
    # Extract videos
    videos = extract_playlist_videos(playlist_id)
    if not videos:
        print(json.dumps({"error": "No videos found"}))
        sys.exit(1)
    
    print(json.dumps({"status": "extracted", "total": len(videos)}), flush=True)
    
    # Download all MP3s
    mp3_files = []
    for idx, video in enumerate(videos, 1):
        print(json.dumps({"status": "downloading", "current": idx, "total": len(videos), "title": video['title']}), flush=True)
        
        mp3_path = config.DOWNLOAD_DIR / f"{sanitize_filename(video['title'])}.mp3"
        if mp3_path.exists():
            duration = 180  # placeholder
        else:
            mp3_path = download_audio(video['url'], mp3_path)
            if not mp3_path:
                continue
        
        # Get duration (simplified)
        result = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                                '-of', 'default=noprint_wrappers=1:nokey=1', str(mp3_path)],
                               capture_output=True, text=True)
        duration = float(result.stdout.strip()) if result.stdout else video['duration']
        
        video['duration'] = duration
        video['mp3_path'] = mp3_path
        mp3_files.append(mp3_path)
    
    if not mp3_files:
        print(json.dumps({"error": "No MP3s downloaded"}))
        sys.exit(1)
    
    # Combine MP3s
    combined_mp3 = config.OUTPUT_DIR / f"{playlist_title}_full.mp3"
    if not combine_mp3s(mp3_files, combined_mp3):
        print(json.dumps({"error": "Failed to combine MP3s"}))
        sys.exit(1)
    
    # Calculate timestamps
    current_time = 0
    for video in videos:
        if video.get('mp3_path'):
            video['start_time'] = current_time
            video['end_time'] = current_time + video['duration']
            current_time += video['duration']
    
    total_duration = current_time
    
    # Create MP4
    mp4_output = config.OUTPUT_DIR / f"{playlist_title}.mp4"
    if not create_mp4(combined_mp3, cover_url, mp4_output, total_duration):
        print(json.dumps({"error": "Failed to create MP4"}))
        sys.exit(1)
    
    # Generate description
    successful_videos = [v for v in videos if v.get('mp3_path')]
    description = generate_description(successful_videos, playlist_title, total_duration)
    
    # Save description
    desc_file = config.OUTPUT_DIR / f"{playlist_title}_description.txt"
    desc_file.write_text(description)
    
    # Output result
    result = {
        "status": "completed",
        "mp4_path": str(mp4_output),
        "description_path": str(desc_file),
        "total_duration": format_time(total_duration),
        "video_count": len(successful_videos),
        "description": description
    }
    print(json.dumps(result))
    
    # Cleanup individual MP3s
    for mp3 in mp3_files:
        mp3.unlink()
    combined_mp3.unlink()

if __name__ == "__main__":
    main()
PYTHON_EOF

chmod +x "$DATA_DIR/yt_playlist_to_mp4.py"

# ============= ADD PLAYLIST TO MP4 API ENDPOINTS =============
log "Adding Playlist to MP4 API endpoints..."

# Update server.js with new endpoints
cat >> "$DATA_DIR/server.js" << 'JAVASCRIPT_EOF'

// ==================== PLAYLIST TO MP4 CONVERTER ENDPOINTS ====================

// Convert playlist to single MP4
app.post('/api/playlist/to-mp4', async (req, res) => {
    const { playlistUrl, coverUrl, title } = req.body;
    
    if (!playlistUrl || !coverUrl) {
        return res.status(400).json({ error: 'Playlist URL and Cover URL are required' });
    }
    
    const taskId = crypto.randomBytes(8).toString('hex');
    
    // Start async conversion
    (async () => {
        try {
            const scriptPath = '/opt/winejs/data/y2mate/yt_playlist_to_mp4.py';
            const playlistTitle = title || `playlist_${Date.now()}`;
            const command = `python3 ${scriptPath} "${playlistUrl}" "${coverUrl}" "${playlistTitle}"`;
            
            const { stdout, stderr } = await execPromise(command, { timeout: 3600000 });
            console.log(`Playlist conversion ${taskId} completed`);
            
            // Parse JSON output
            const match = stdout.match(/\{.*\}/s);
            if (match) {
                const result = JSON.parse(match[0]);
                // Store result for retrieval
                const conversionResults = JSON.parse(await fs.readFile(CONVERSION_FILE, 'utf8').catch(() => '{}'));
                conversionResults[taskId] = result;
                await fs.writeFile(CONVERSION_FILE, JSON.stringify(conversionResults, null, 2));
            }
        } catch (err) {
            console.error(`Playlist conversion ${taskId} failed: ${err.message}`);
        }
    })();
    
    res.json({ 
        taskId, 
        message: 'Playlist conversion started',
        statusUrl: `/api/playlist/status/${taskId}`
    });
});

// Get conversion status
app.get('/api/playlist/status/:taskId', async (req, res) => {
    const taskId = req.params.taskId;
    try {
        const conversionResults = JSON.parse(await fs.readFile(CONVERSION_FILE, 'utf8').catch(() => '{}'));
        if (conversionResults[taskId]) {
            res.json(conversionResults[taskId]);
        } else {
            res.json({ status: 'processing', taskId });
        }
    } catch (err) {
        res.json({ status: 'processing', taskId });
    }
});

// List MP4 outputs
app.get('/api/playlist/mp4-files', async (req, res) => {
    try {
        const mp4Dir = '/opt/winejs/data/y2mate/mp4_output';
        const files = await fs.readdir(mp4Dir).catch(() => []);
        const mp4Files = [];
        
        for (const file of files) {
            if (file.endsWith('.mp4')) {
                const filePath = path.join(mp4Dir, file);
                const stat = await fs.stat(filePath);
                mp4Files.push({
                    name: file,
                    size: stat.size,
                    modified: stat.mtime,
                    downloadUrl: `/api/playlist/download/${encodeURIComponent(file)}`,
                    descriptionFile: file.replace('.mp4', '_description.txt')
                });
            }
        }
        
        res.json({ files: mp4Files });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Download MP4 file
app.get('/api/playlist/download/:filename', async (req, res) => {
    const filename = req.params.filename;
    const filepath = path.join('/opt/winejs/data/y2mate/mp4_output', filename);
    
    try {
        await fs.access(filepath);
        res.download(filepath);
    } catch (err) {
        res.status(404).json({ error: 'File not found' });
    }
});

// Download description file
app.get('/api/playlist/description/:filename', async (req, res) => {
    const filename = req.params.filename;
    const filepath = path.join('/opt/winejs/data/y2mate/mp4_output', filename);
    
    try {
        await fs.access(filepath);
        res.download(filepath, 'description.txt');
    } catch (err) {
        res.status(404).json({ error: 'Description not found' });
    }
});

const CONVERSION_FILE = '/opt/winejs/data/y2mate/conversions.json';
JAVASCRIPT_EOF

# ============= UPDATE FRONTEND HTML WITH PLAYLIST TO MP4 FEATURE =============
log "Updating frontend with Playlist to MP4 feature..."

# Add new section to frontend.html before the closing body tag
sed -i '/<div id="main" style="margin-top: 20px;">/a\
    <!-- Playlist to MP4 Converter Section -->\
    <div id="main" style="margin-top: 20px;">\
        <h3>🎬 Playlist to Single MP4 Converter</h3>\
        <div id="form">\
            <input autocomplete="off" id="playlist-to-mp4-url" placeholder="YouTube Playlist URL..." type="text" style="width: 400px;">\
            <input autocomplete="off" id="cover-image-url" placeholder="Cover Image URL (square image)" type="text" style="width: 400px; margin-top: 10px;">\
            <input autocomplete="off" id="playlist-title" placeholder="Playlist Title (optional)" type="text" style="width: 400px; margin-top: 10px;">\
            <button id="convert-playlist-btn" class="refresh-btn" style="margin-top: 15px;">🎬 Convert Playlist to MP4</button>\
            <div id="playlist-to-mp4-progress" class="progress-bar" style="display: none; margin-top: 15px;">\
                <div id="playlist-to-mp4-fill" class="progress-fill"></div>\
            </div>\
            <div id="playlist-to-mp4-result" class="result"></div>\
        </div>\
    </div>\
    \
    <div id="main" style="margin-top: 20px;">\
        <h3>📁 Generated MP4 Videos</h3>\
        <div id="form">\
            <button id="refresh-mp4-btn" class="refresh-btn">Refresh MP4 List</button>\
            <div id="mp4-files-list" class="files-list"></div>\
        </div>\
    </div>' "$APP_DIR/frontend.html"

# Add JavaScript for playlist to MP4 feature
cat >> "$APP_DIR/frontend.html" << 'JAVASCRIPT_EOF'
<script>
// Playlist to MP4 Converter
const playlistToMp4Url = document.getElementById("playlist-to-mp4-url");
const coverImageUrl = document.getElementById("cover-image-url");
const playlistTitle = document.getElementById("playlist-title");
const convertPlaylistBtn = document.getElementById("convert-playlist-btn");
const playlistToMp4Progress = document.getElementById("playlist-to-mp4-progress");
const playlistToMp4Fill = document.getElementById("playlist-to-mp4-fill");
const playlistToMp4Result = document.getElementById("playlist-to-mp4-result");

if (convertPlaylistBtn) {
    convertPlaylistBtn.addEventListener("click", async () => {
        const playlistUrl = playlistToMp4Url?.value.trim();
        const coverUrl = coverImageUrl?.value.trim();
        const title = playlistTitle?.value.trim();
        
        if (!playlistUrl) {
            alert("Please enter a YouTube Playlist URL");
            return;
        }
        
        if (!coverUrl) {
            alert("Please enter a cover image URL (must be square image)");
            return;
        }
        
        // Validate cover URL is an image
        if (!coverUrl.match(/\.(jpg|jpeg|png|webp)/i) && !coverUrl.includes('images/')) {
            alert("Cover URL should point to an image file (JPG, PNG, etc.)");
            return;
        }
        
        showResult(playlistToMp4Result, "Starting playlist conversion... This will take several minutes.", "loading");
        playlistToMp4Progress.style.display = "block";
        playlistToMp4Fill.style.width = "0%";
        convertPlaylistBtn.disabled = true;
        
        try {
            const response = await fetch(`${API_BASE}/api/playlist/to-mp4`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ playlistUrl, coverUrl, title })
            });
            
            const data = await response.json();
            
            if (response.ok) {
                showResult(playlistToMp4Result, `✅ Conversion started! Task ID: ${data.taskId}. Check back in a few minutes.`, "success");
                pollConversionStatus(data.taskId);
            } else {
                showResult(playlistToMp4Result, data.error || "Conversion failed", "error");
                playlistToMp4Progress.style.display = "none";
            }
        } catch (err) {
            showResult(playlistToMp4Result, "Network error: " + err.message, "error");
            playlistToMp4Progress.style.display = "none";
        } finally {
            convertPlaylistBtn.disabled = false;
        }
    });
}

async function pollConversionStatus(taskId) {
    let attempts = 0;
    const maxAttempts = 120; // 10 minutes max (5 seconds * 120)
    
    const interval = setInterval(async () => {
        attempts++;
        
        try {
            const response = await fetch(`${API_BASE}/api/playlist/status/${taskId}`);
            const data = await response.json();
            
            if (data.status === "completed") {
                clearInterval(interval);
                showResult(playlistToMp4Result, 
                    `✅ Conversion complete! Video: ${data.video_count} songs, Duration: ${data.total_duration}`, 
                    "success");
                playlistToMp4Fill.style.width = "100%";
                setTimeout(() => { playlistToMp4Progress.style.display = "none"; }, 3000);
                loadMp4Files();
            } else if (data.status === "error") {
                clearInterval(interval);
                showResult(playlistToMp4Result, `❌ Conversion failed: ${data.error}`, "error");
                playlistToMp4Progress.style.display = "none";
            } else if (data.current && data.total) {
                // Update progress
                const percent = (data.current / data.total) * 100;
                playlistToMp4Fill.style.width = `${percent}%`;
                showResult(playlistToMp4Result, `Processing: ${data.current}/${data.total} - ${data.title || ''}`, "loading");
            }
            
            if (attempts >= maxAttempts) {
                clearInterval(interval);
                showResult(playlistToMp4Result, "Conversion timed out. Check the output directory.", "error");
                playlistToMp4Progress.style.display = "none";
            }
        } catch (err) {
            console.error("Status poll error:", err);
        }
    }, 5000);
}

async function loadMp4Files() {
    const mp4FilesDiv = document.getElementById("mp4-files-list");
    if (!mp4FilesDiv) return;
    
    mp4FilesDiv.innerHTML = '<div style="text-align: center; padding: 20px;">Loading...</div>';
    
    try {
        const response = await fetch(`${API_BASE}/api/playlist/mp4-files`);
        const data = await response.json();
        
        if (data.files && data.files.length > 0) {
            mp4FilesDiv.innerHTML = data.files.map(file => `
                <div class="file-item">
                    <div>
                        <div class="file-name">${escapeHtml(file.name)}</div>
                        <div class="file-size">${formatBytes(file.size)}</div>
                    </div>
                    <div class="file-actions">
                        <a href="${API_BASE}/api/playlist/download/${encodeURIComponent(file.name)}">Download MP4</a>
                        <a href="${API_BASE}/api/playlist/description/${encodeURIComponent(file.descriptionFile)}">Description</a>
                        <button onclick="copyDescriptionToClipboard('${escapeHtml(file.descriptionFile)}')">Copy Desc</button>
                    </div>
                </div>
            `).join('');
        } else {
            mp4FilesDiv.innerHTML = '<div style="text-align: center; padding: 20px; color: #666;">No MP4 videos generated yet</div>';
        }
    } catch (err) {
        mp4FilesDiv.innerHTML = '<div style="text-align: center; padding: 20px; color: red;">Failed to load MP4 files</div>';
    }
}

window.copyDescriptionToClipboard = async (descFile) => {
    try {
        const response = await fetch(`${API_BASE}/api/playlist/description/${descFile}`);
        const text = await response.text();
        navigator.clipboard.writeText(text);
        alert("Description copied to clipboard!");
    } catch (err) {
        alert("Failed to copy description");
    }
};

// Refresh MP4 files button
const refreshMp4Btn = document.getElementById("refresh-mp4-btn");
if (refreshMp4Btn) {
    refreshMp4Btn.addEventListener("click", loadMp4Files);
}

// Load MP4 files on page load
setTimeout(loadMp4Files, 1000);
</script>
JAVASCRIPT_EOF

log "✅ Playlist to MP4 Converter feature added!"

# ============= DOWNLOAD ICON =============
log "📥 Downloading app icon..."
curl -L "$APP_LOGO_URL" -o "$ICON_DIR/${APP_NAME}.png" 2>/dev/null || \
warn "Failed to download icon, using default"

# ============= CREATE LAUNCH SCRIPT =============
log "Creating launch.sh..."

cat > "$APP_DIR/launch.sh" << LAUNCH_EOF
#!/bin/bash

log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1"
}

log "🚀 Starting WineJS Y2Mate YouTube Downloader..."

# Start API server with PM2
cd /opt/winejs/data/y2mate
source venv/bin/activate
pm2 start server.js --name y2mate-api -- --port ${APP_PORT}

log "✅ Y2Mate YouTube Downloader started"
log "   Frontend: https://${DOMAIN_NAME}/y2mate"

# Keep script running
tail -f /dev/null
LAUNCH_EOF

chmod +x "$APP_DIR/launch.sh"

# ============= CREATE CONFIG.JSON =============
log "Creating config.json..."

cat > "$APP_DIR/config.json" << CONF_EOF
{
    "name": "Y2Mate YouTube Downloader",
    "version": "1.0",
    "description": "Download YouTube videos as MP4 or MP3 audio, extract transcripts, and bulk download support",
    "executable": "launch.sh",
    "port": ${APP_PORT},
    "vnc_password": "winejs-y2mate",
    "icon": "icons/${APP_NAME}.png",
    "category": "media",
    "features": [
        "YouTube to MP4 download",
        "YouTube to MP3 conversion",
        "Video quality: 240p to 1080p",
        "Audio bitrate: 64k to 320k",
        "Transcript extraction (VTT format)",
        "Bulk download via JSON file",
        "Queue system for reliability",
        "Web frontend interface"
    ]
}
CONF_EOF

# ============= CREATE PM2 ECOSYSTEM =============
log "Creating PM2 ecosystem..."

cat > "$APP_DIR/ecosystem.config.js" << EOF
module.exports = {
    apps: [
        {
            name: 'y2mate-api',
            cwd: '${DATA_DIR}',
            script: 'server.js',
            instances: 1,
            exec_mode: 'fork',
            max_memory_restart: '300M',
            env: {
                NODE_ENV: 'production',
                PORT: ${APP_PORT}
            }
        }
    ]
};
EOF

# ============= CREATE UNINSTALL SCRIPT =============
log "Creating uninstall script..."

cat > "$(dirname "$APP_DIR")/uninstall_y2mate.sh" << 'UNINSTALL_EOF'
#!/bin/bash
# WineJS Y2Mate YouTube Downloader Uninstaller

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Change to safe directory first
cd /tmp || cd /root || exit 1

log "🧹 Uninstalling Y2Mate YouTube Downloader..."

# ============= STOP PM2 PROCESSES =============
log "Stopping PM2 processes..."
if command -v pm2 &> /dev/null; then
    if pm2 list 2>/dev/null | grep -q "y2mate-api"; then
        log "Stopping y2mate-api..."
        pm2 stop y2mate-api 2>/dev/null || true
        pm2 delete y2mate-api 2>/dev/null || true
        pm2 save 2>/dev/null || true
        log "✅ PM2 process stopped"
    fi
fi

# ============= REMOVE APP DIRECTORIES =============
log "Removing app directories..."

APP_NAME="y2mate"
APP_DIR="/opt/winejs/apps/${APP_NAME}"
INSTANCE_DIR="/opt/winejs/kasmvnc-instances/${APP_NAME}"
DATA_DIR="/opt/winejs/data/${APP_NAME}"
CONFIG_DIR="/opt/winejs/config/${APP_NAME}"
ICON_FILE="/opt/winejs/translator/public/icons/${APP_NAME}.png"

# Remove directories if they exist
[ -d "$INSTANCE_DIR" ] && rm -rf "$INSTANCE_DIR" && log "✅ Instance directory removed"
[ -d "$APP_DIR" ] && rm -rf "$APP_DIR" && log "✅ App directory removed"
[ -d "$DATA_DIR" ] && rm -rf "$DATA_DIR" && log "✅ Data directory removed"
[ -d "$CONFIG_DIR" ] && rm -rf "$CONFIG_DIR" && log "✅ Config directory removed"
[ -f "$ICON_FILE" ] && rm -f "$ICON_FILE" && log "✅ Icon removed"

# ============= REMOVE NGINX CONFIGURATION =============
log "Removing nginx configuration..."

NGINX_SITE="/etc/nginx/sites-available/winejs"

if [ ! -f "$NGINX_SITE" ]; then
    warn "nginx config not found at $NGINX_SITE"
else
    # Check if any Y2Mate routes exist
    if ! grep -q "y2mate" "$NGINX_SITE"; then
        log "No Y2Mate routes found in nginx config"
    else
        log "Removing Y2Mate routes from nginx config..."
        
        # Create backup with timestamp
        BACKUP_FILE="${NGINX_SITE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$NGINX_SITE" "$BACKUP_FILE"
        log "✅ Backup created: $BACKUP_FILE"
        
        # Use Perl for more reliable multi-line removal (if available)
        if command -v perl &> /dev/null; then
            perl -i -0777 -pe 's/^[[:space:]]*# Y2Mate YouTube Downloader\s*\n.*?location = \/y2mate\/health.*?^\s*}\s*$//gms' "$NGINX_SITE"
            perl -i -0777 -pe 's/^[[:space:]]*location \/y2mate\s*\{.*?^\s*\}\s*$//gms' "$NGINX_SITE"
        else
            # Fallback to sed for multi-line removal
            sed -i '/# Y2Mate YouTube Downloader/,/location = \/y2mate\/health/d' "$NGINX_SITE"
            sed -i '/location \/y2mate {/,/}/d' "$NGINX_SITE"
        fi
        
        # Remove any orphaned y2mate lines
        sed -i '/y2mate/d' "$NGINX_SITE"
        
        # Clean up multiple blank lines
        sed -i '/^$/N;/^\n$/D' "$NGINX_SITE"
        
        # Test and reload nginx
        log "Testing nginx configuration..."
        if nginx -t 2>&1 | tee /tmp/nginx_test.log; then
            systemctl reload nginx
            log "✅ Nginx configuration successfully updated - Y2Mate routes removed"
        else
            warn "Nginx test failed! Restoring from backup..."
            if [ -f "$BACKUP_FILE" ]; then
                cp "$BACKUP_FILE" "$NGINX_SITE"
                if nginx -t 2>/dev/null; then
                    systemctl reload nginx
                    log "✅ Successfully restored previous nginx config"
                else
                    error "CRITICAL: Even backup config fails! Check nginx manually"
                    exit 1
                fi
            else
                error "No backup available! Manual intervention required"
                log "Check nginx config at: $NGINX_SITE"
                log "Previous error: $(cat /tmp/nginx_test.log)"
                exit 1
            fi
        fi
    fi
fi

# ============= REMOVE HELPER SCRIPT =============
if [ -f "/usr/local/bin/winejs-y2mate" ]; then
    rm -f "/usr/local/bin/winejs-y2mate"
    log "✅ Helper script removed"
fi

# ============= RELOAD WINEJS TRANSLATOR =============
log "Reloading WineJS translator..."
if command -v pm2 &> /dev/null; then
    pm2 restart translator 2>/dev/null || true
    log "✅ Translator reloaded"
fi

# ============= VERIFY REMOVAL =============
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Y2MATE YOUTUBE DOWNLOADER UNINSTALLED!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
log "✅ Y2Mate YouTube Downloader has been completely removed"
echo ""
UNINSTALL_EOF

chmod +x "$(dirname "$APP_DIR")/uninstall_y2mate.sh"


# ============= START SERVICES =============
log "Starting PM2 services..."
pm2 start "$APP_DIR/ecosystem.config.js"
pm2 save

# ============= UPDATE NGINX CONFIG =============
log "📝 Updating nginx configuration for Y2Mate..."

# The pattern for ALL installers (Mumble, PufferPanel, Forgejo, VSCode, Y2Mate):
#   1. Find the HTTPS server block by locating "listen 443"
#   2. Count braces { and } to find the exact closing brace of that server block
#   3. Insert new location blocks BEFORE that closing brace
#   4. This guarantees routes are safely INSIDE the correct server block

if [ -f "/etc/nginx/sites-available/winejs" ]; then
    # Check if Y2Mate routes already exist
    if ! grep -q "location /y2mate/" /etc/nginx/sites-available/winejs; then
        # Backup the current config
        cp /etc/nginx/sites-available/winejs /etc/nginx/sites-available/winejs.backup
        
        # Find the HTTPS server block (listen 443)
        HTTPS_START=$(grep -n "listen 443" /etc/nginx/sites-available/winejs | head -1 | cut -d: -f1)
        
        if [ -n "$HTTPS_START" ]; then
            # Find the closing brace of the HTTPS block by counting braces
            BRACE_COUNT=0
            LINE_NUM=$HTTPS_START
            TOTAL_LINES=$(wc -l < /etc/nginx/sites-available/winejs)
            HTTPS_END=""
            
            while [ $LINE_NUM -le $TOTAL_LINES ]; do
                LINE=$(sed -n "${LINE_NUM}p" /etc/nginx/sites-available/winejs)
                for ((i=0; i<${#LINE}; i++)); do
                    char="${LINE:$i:1}"
                    if [ "$char" = "{" ]; then
                        BRACE_COUNT=$((BRACE_COUNT + 1))
                    elif [ "$char" = "}" ]; then
                        BRACE_COUNT=$((BRACE_COUNT - 1))
                    fi
                done
                if [ $BRACE_COUNT -eq 0 ]; then
                    HTTPS_END=$LINE_NUM
                    break
                fi
                LINE_NUM=$((LINE_NUM + 1))
            done
            
            if [ -n "$HTTPS_END" ]; then
                # Insert routes BEFORE the closing brace (safe inside server block)
                sed -i "${HTTPS_END}i\\
    # Y2Mate YouTube Downloader\n\
    location /y2mate/ {\n\
        proxy_pass http://127.0.0.1:${APP_PORT}/;\n\
        proxy_set_header Host \$host;\n\
        proxy_set_header X-Real-IP \$remote_addr;\n\
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n\
        proxy_set_header X-Forwarded-Proto \$scheme;\n\
        proxy_buffering off;\n\
        proxy_connect_timeout 300s;\n\
        proxy_send_timeout 300s;\n\
        proxy_read_timeout 300s;\n\
    }\n\
    \n\
    location = /y2mate {\n\
        return 301 /y2mate/;\n\
    }\n\
    \n\
    location = /y2mate/health {\n\
        proxy_pass http://127.0.0.1:${APP_PORT}/health;\n\
        access_log off;\n\
    }\n" /etc/nginx/sites-available/winejs
                
                log "✅ Y2Mate routes inserted safely"
                
                # Test and reload
                if nginx -t; then
                    systemctl reload nginx
                    log "✅ Nginx updated with Y2Mate routes"
                    log "   • /y2mate/ → Y2Mate (port ${APP_PORT})"
                    log "   • /y2mate/health → Health check"
                else
                    warn "Nginx test failed, restoring backup"
                    cp /etc/nginx/sites-available/winejs.backup /etc/nginx/sites-available/winejs
                    nginx -t && systemctl reload nginx
                    log "⚠️ Could not add Y2Mate routes automatically"
                fi
            else
                warn "Could not find HTTPS block closing brace"
            fi
        else
            warn "Could not find HTTPS server block (listen 443)"
        fi
    else
        log "Y2Mate routes already exist in nginx config"
    fi
else
    warn "nginx config not found, skipping"
fi

# ============= RESTART TRANSLATOR TO REGISTER APP =============
log "🔄 Restarting WineJS translator to register app..."
pm2 restart translator 2>/dev/null || systemctl restart winejs-translator 2>/dev/null || true

sleep 3

# ============= CREATE HELPER SCRIPT =============
log "Creating helper script..."

cat > /usr/local/bin/winejs-y2mate << EOF
#!/bin/bash
# Quick Y2Mate launcher for WineJS

case "\$1" in
    open)
        if command -v xdg-open &> /dev/null; then
            xdg-open "https://${DOMAIN_NAME}/y2mate"
        elif command -v open &> /dev/null; then
            open "https://${DOMAIN_NAME}/y2mate"
        else
            echo "Visit: https://${DOMAIN_NAME}/y2mate"
        fi
        ;;
    health)
        curl -s "https://${DOMAIN_NAME}/y2mate/health" | python3 -m json.tool 2>/dev/null || curl -s "https://${DOMAIN_NAME}/y2mate/health"
        ;;
    clean)
        echo "Cleaning old downloads..."
        find /opt/winejs/data/y2mate/downloads -type f -mmin +60 -delete
        echo "Done"
        ;;
    *)
        echo "WineJS Y2Mate YouTube Downloader Helper"
        echo ""
        echo "Commands:"
        echo "  winejs-y2mate open        - Open Y2Mate in browser"
        echo "  winejs-y2mate health      - Check service health"
        echo "  winejs-y2mate clean       - Clean old downloads (>1 hour)"
        ;;
esac
EOF

chmod +x /usr/local/bin/winejs-y2mate

# ============= FINAL OUTPUT =============
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Y2MATE YOUTUBE DOWNLOADER INSTALLED!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
success "✅ Y2Mate YouTube Downloader installed as a WineJS app!"
echo ""
info "🌐 Access URLs:"
info "   • Frontend UI: https://$DOMAIN_NAME/y2mate"
info "   • Health Check: https://$DOMAIN_NAME/y2mate/health"
echo ""
info "🎯 Quick Commands:"
info "   • winejs-y2mate open        # Open in browser"
info "   • winejs-y2mate health      # Check health"
info "   • winejs-y2mate clean       # Clean old downloads"
echo ""
info "🎬 Features:"
info "   • YouTube to MP4 download (240p-1080p)"
info "   • YouTube to MP3 conversion (64k-320k)"
info "   • Transcript extraction with VTT support"
info "   • Bulk downloads via JSON file"
info "   • Copy transcript to clipboard"
info "   • Web frontend interface"
echo ""
info "📁 Download Location:"
info "   /opt/winejs/data/y2mate/downloads"
echo ""
info "📝 To uninstall: sudo bash $(dirname "$APP_DIR")/uninstall_y2mate.sh"
echo ""
success "✨ Y2Mate YouTube Downloader is ready! Visit https://$DOMAIN_NAME/y2mate"
echo ""

echo "Find all uninstall scripts in the apps directory"
echo "find /opt/winejs/apps -name \"uninstall_*\" -type f"  

# This WineJS-compatible installer transforms your Y2Mate YouTube downloader service into a fully integrated WineJS app with:
# Features Included:
#     YouTube to MP4 - Download videos in 240p to 1080p quality
#     YouTube to MP3 - Convert to audio with bitrates 64k-320k
#     Transcript Extraction - Get VTT captions as plain text
#     Copy to Clipboard - One-click transcript copying
#     Bulk Downloads - Support for JSON file bulk downloading
#     Queue System - Async download processing
#     Web Frontend - Beautiful modern UI with tabs
#     File Management - List, download, and delete files
#     Auto Cleanup - Removes old downloads after 1 hour
#     PM2 Management - Auto-restart on failure
#     WineJS Integration - Proper directory structure, config.json, launch.sh, uninstall script
#     Nginx Integration - Routes added to existing WineJS nginx config
#     Helper CLI - winejs-y2mate command for common operations
#     Health Checks - Endpoint for monitoring

# The app will be available at https://your-domain.com/y2mate and 
# automatically integrates with the WineJS platform!