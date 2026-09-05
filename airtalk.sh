#!/bin/bash

# Artalk Comment System Setup Script v1.0
# Complete commenting system with SSL, Docker deployment, and management tools
# Usage: curl -sL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/setup-artalk.sh | sudo bash

# curl -o artalk.sh https://cdn.sdappnet.cloud/rtx/sh/artalk.sh && chmod +x artalk.sh && sudo ./artalk.sh

# Force non-interactive mode for all apt commands
export DEBIAN_FRONTEND=noninteractive

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to get user input with default
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "$prompt [$default]: " input
    eval "$var_name=\${input:-\$default}"
}

# Validate email format
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate domain format
validate_domain() {
    local domain="$1"
    
    # Remove trailing dot if present
    domain="${domain%.}"
    
    # Check if empty
    if [ -z "$domain" ]; then
        warn "Domain cannot be empty"
        return 1
    fi
    
    # Check length (max 253 characters)
    if [ ${#domain} -gt 253 ]; then
        warn "Domain is too long (max 253 characters)"
        return 1
    fi
    
    # Check for invalid characters
    if [[ "$domain" =~ [^a-zA-Z0-9.-] ]]; then
        warn "Domain contains invalid characters (only letters, numbers, dots, and hyphens allowed)"
        return 1
    fi
    
    # Check if it starts or ends with dot
    if [[ "$domain" == .* ]] || [[ "$domain" == *. ]]; then
        warn "Domain cannot start or end with a dot"
        return 1
    fi
    
    # Check for double dots
    if [[ "$domain" == *..* ]]; then
        warn "Domain cannot contain consecutive dots"
        return 1
    fi
    
    # Check if it contains at least one dot
    if [[ ! "$domain" =~ \. ]]; then
        warn "Domain must contain at least one dot (e.g., comments.yourdomain.com)"
        return 1
    fi
    
    return 0
}

# Check if port is available
check_port_availability() {
    local port=$1
    if ss -tulpn 2>/dev/null | grep -q ":$port "; then
        return 1  # Port is in use
    fi
    return 0  # Port is available
}

# Display banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Artalk Comment System Setup v1.0                ║"
echo "║      Lightweight, Self-hosted Commenting System         ║"
echo "║           with SSL, Docker, and Management Tools        ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    warn "Not running as root. Some commands may need sudo."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get user configuration
echo ""
info "Please provide configuration details:"
echo "-------------------------------------"

while true; do
    get_input "Enter your Artalk domain (e.g., comments.yourdomain.com)" "comments.sdappnet.cloud" DOMAIN_NAME
    
    if validate_domain "$DOMAIN_NAME"; then
        break
    else
        warn "Invalid domain format. Please enter a full domain (e.g., comments.yourdomain.com)"
    fi
done

# Get email for SSL
while true; do
    get_input "Enter email for SSL certificate (Let's Encrypt)" "admin@$DOMAIN_NAME" SSL_EMAIL
    if validate_email "$SSL_EMAIL"; then
        break
    else
        error "Invalid email format. Please enter a valid email (e.g., admin@google.com)."
    fi
done

# Get site name
get_input "Enter your site name (e.g., My Blog)" "Artalk Comments" SITE_NAME

# Get site URL
get_input "Enter your main site URL (e.g., https://myblog.com)" "https://$DOMAIN_NAME" SITE_URL

# Get droplet IP
DROPLET_IP=$(curl -s --fail ifconfig.me 2>/dev/null || curl -s --fail http://checkip.amazonaws.com 2>/dev/null || echo "UNKNOWN")
info "Detected droplet IP: $DROPLET_IP"

echo ""
log "Starting Artalk Comment System Setup..."
log "Domain: $DOMAIN_NAME"
log "Email: $SSL_EMAIL"
log "Site Name: $SITE_NAME"
log "Site URL: $SITE_URL"
log "Droplet IP: $DROPLET_IP"

# Check port availability
if ! check_port_availability 80; then
    warn "Port 80 is already in use. This may affect SSL certificate creation."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if ! check_port_availability 443; then
    warn "Port 443 is already in use. This may affect HTTPS setup."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
log "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq

# Install required tools
log "Installing required tools..."
apt-get install -y -qq curl wget git ufw ca-certificates gnupg lsb-release

# ============= INSTALL DOCKER =============
log "Installing Docker..."
if ! command -v docker &> /dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl start docker
    systemctl enable docker
    log "✅ Docker installed successfully"
else
    log "Docker already installed"
fi

# Install docker-compose
if ! command -v docker-compose &> /dev/null; then
    log "Installing docker-compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# ============= CREATE ARTALK DIRECTORY =============
ARTALK_DIR="/opt/artalk"
log "Creating Artalk directory at $ARTALK_DIR..."
mkdir -p $ARTALK_DIR/data
cd $ARTALK_DIR

# ============= CREATE DOCKER COMPOSE FILE =============
log "Creating Docker Compose configuration..."
cat > docker-compose.yml << EOF
version: '3.8'

services:
  artalk:
    image: artalk/artalk-go:latest
    container_name: artalk
    restart: unless-stopped
    ports:
      - "8080:23366"
    volumes:
      - ./data:/data
      - ./artalk.yml:/conf/artalk.yml:ro
    environment:
      - TZ=UTC
      - ATK_LOCALE=en
    networks:
      - artalk-net
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:23366/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  artalk-net:
    driver: bridge
EOF

# ============= CREATE ARTALK CONFIGURATION =============
log "Creating Artalk configuration file..."
cat > artalk.yml << EOF
# Artalk Configuration File
# https://artalk.js.org/guide/config.html

app:
  # Debug mode
  debug: false
  # Application host
  host: "0.0.0.0"
  # Application port
  port: 23366

# Database configuration
db:
  # Database type: sqlite, mysql, pgsql, mssql
  type: sqlite
  # SQLite file path
  file: "/data/artalk.db"
  # MySQL/PostgreSQL connection string (uncomment if using MySQL)
  # dsn: "root:password@tcp(localhost:3306)/artalk?charset=utf8mb4&parseTime=True&loc=Local"

# Site configuration
site:
  # Default site name
  default: "$SITE_NAME"
  # Default site URL
  url: "$SITE_URL"

# Cache configuration
cache:
  # Cache type: redis, memory
  type: memory
  # Redis connection string (uncomment if using Redis)
  # redis: "redis://localhost:6379/0"

# Captcha configuration
captcha:
  # Captcha type: turnstile, hcaptcha, recaptcha, none
  type: "turnstile"
  # Turnstile site key (Cloudflare)
  turnstile_site_key: ""
  # Turnstile secret key
  turnstile_secret_key: ""

# Email notification
email:
  # Email enabled
  enabled: false
  # Email sender address
  send_addr: ""
  # Email sender name
  send_name: "Artalk"
  # Email client: smtp, sendmail, api
  client:
    type: smtp
    smtp:
      host: "smtp.gmail.com"
      port: 587
      username: ""
      password: ""
      insecure_skip_verify: false

# Multi-channel push
notify:
  # Push type: dingtalk, lark, wecom, bark, telegram, none
  type: "none"
  # Webhook URL for notifications
  webhook_url: ""

# Image upload
img_upload:
  # Image upload enabled
  enabled: true
  # Max file size (MB)
  max_size: 10
  # Allowed file types
  public_path: "/static/images/"
  # Upload directory
  upload_dir: "/data/images/"
  # Upload via API
  up_uri: "/api/upload"

# Moderation settings
moderator:
  # Pending default (true = comments need approval)
  pending_default: false
  # Admin email
  admin_emails:
    - "$SSL_EMAIL"
  # Trusted domains
  trusted_domains: []
  # Spam keywords (regex)
  spam_keywords: []

# Security settings
security:
  # Allow origins for CORS (comma separated)
  allow_origins: ["$SITE_URL"]
  # Admin-only API (if true, only admin can use the API)
  admin_only: false
  # Limit for requests per minute
  limit:
    # Enabled
    enabled: false
    # Max requests per minute per IP
    max: 60

# UI configuration (frontend)
ui:
  # Enable voting
  vote: true
  # Enable nested comments
  nested_comments: true
  # Enable page view statistics
  page_view: false
  # Enable markdown
  markdown: true
  # Enable emoji
  emoji: true
  # Enable user badge
  user_badge: true
  # Avatar gravatar type
  gravatar: "mp"
EOF

# ============= CREATE .ENV FILE =============
log "Creating environment file..."
cat > .env << EOF
# Artalk Environment Configuration
DOMAIN_NAME=$DOMAIN_NAME
SITE_NAME=$SITE_NAME
SITE_URL=$SITE_URL
SSL_EMAIL=$SSL_EMAIL
DROPLET_IP=$DROPLET_IP
EOF

# ============= CREATE ADMIN SCRIPT =============
log "Creating admin management script..."
cat > /usr/local/bin/artalk-admin << 'EOF'
#!/bin/bash

ARTALK_DIR="/opt/artalk"

case "$1" in
  create-admin)
    echo "Creating Artalk admin user..."
    docker exec -it artalk artalk admin
    ;;
    
  reset-password)
    if [ -z "$2" ]; then
      echo "Usage: $0 reset-password <email>"
      exit 1
    fi
    echo "Resetting password for $2..."
    docker exec -it artalk artalk admin reset -e "$2"
    ;;
    
  list-users)
    echo "Listing Artalk users..."
    docker exec -it artalk artalk admin ls
    ;;
    
  export)
    echo "Exporting comments..."
    docker exec artalk artalk export /data/export-$(date +%Y%m%d-%H%M%S).json
    echo "Export saved to $ARTALK_DIR/data/"
    ;;
    
  import)
    if [ -z "$2" ]; then
      echo "Usage: $0 import <filename>"
      echo "Available files:"
      ls -la $ARTALK_DIR/data/
      exit 1
    fi
    echo "Importing from $2..."
    docker exec artalk artalk import /data/$2
    ;;
    
  logs)
    docker logs -f artalk
    ;;
    
  status)
    docker ps --filter "name=artalk" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "Disk usage:"
    du -sh $ARTALK_DIR/data/
    ;;
    
  start)
    cd $ARTALK_DIR && docker-compose up -d
    ;;
    
  stop)
    cd $ARTALK_DIR && docker-compose down
    ;;
    
  restart)
    cd $ARTALK_DIR && docker-compose restart
    ;;
    
  update)
    echo "Updating Artalk..."
    cd $ARTALK_DIR && docker-compose pull && docker-compose up -d
    ;;
    
  backup)
    BACKUP_DIR="$ARTALK_DIR/backups"
    mkdir -p $BACKUP_DIR
    BACKUP_FILE="$BACKUP_DIR/artalk-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf $BACKUP_FILE -C $ARTALK_DIR data
    echo "Backup created: $BACKUP_FILE"
    ;;
    
  *)
    echo "Artalk Admin Management Script"
    echo "==============================="
    echo "Usage: $0 {command}"
    echo ""
    echo "User Management:"
    echo "  create-admin          Create admin user"
    echo "  reset-password <email> Reset user password"
    echo "  list-users           List all users"
    echo ""
    echo "Data Management:"
    echo "  export               Export comments"
    echo "  import <filename>    Import comments"
    echo "  backup               Create backup"
    echo ""
    echo "Service Control:"
    echo "  start                Start Artalk"
    echo "  stop                 Stop Artalk"
    echo "  restart              Restart Artalk"
    echo "  status               Show status"
    echo "  logs                 View logs"
    echo "  update               Update Artalk"
    exit 1
    ;;
esac
EOF

chmod +x /usr/local/bin/artalk-admin

# ============= CREATE MIGRATION TOOL SCRIPT =============
log "Creating migration tool script..."
cat > /usr/local/bin/artalk-migrate << 'EOF'
#!/bin/bash

ARTALK_DIR="/opt/artalk"
MIGRATE_DIR="$ARTALK_DIR/migrations"
mkdir -p $MIGRATE_DIR

case "$1" in
  from-wp|from-wordpress)
    if [ -z "$2" ]; then
      echo "Usage: $0 from-wp <wordpress-xml-file>"
      exit 1
    fi
    echo "Converting WordPress XML to Artalk format..."
    cp "$2" $MIGRATE_DIR/wordpress-import.xml
    
    # Download conversion tool if needed
    if [ ! -f "/tmp/artransfer" ]; then
      echo "Downloading Artransfer conversion tool..."
      wget -q -O /tmp/artransfer.tar.gz https://github.com/ArtalkJS/Artransfer/releases/latest/download/artransfer_linux_amd64.tar.gz
      tar -xzf /tmp/artransfer.tar.gz -C /tmp/
      chmod +x /tmp/artransfer
    fi
    
    # Convert WordPress to Artrans
    /tmp/artransfer wordpress \
      --xml="/tmp/wordpress-import.xml" \
      --output="$MIGRATE_DIR/wordpress-$(date +%Y%m%d).artrans"
    
    echo "Converted to: $MIGRATE_DIR/wordpress-$(date +%Y%m%d).artrans"
    echo ""
    echo "To import into Artalk:"
    echo "  artalk-admin import wordpress-$(date +%Y%m%d).artrans"
    ;;
    
  from-typecho)
    if [ -z "$2" ]; then
      echo "Usage: $0 from-typecho <typecho-database>"
      echo "Example: $0 from-typecho mysql://user:pass@localhost/typecho"
      exit 1
    fi
    
    echo "Converting Typecho to Artalk format..."
    # Download conversion tool
    if [ ! -f "/tmp/artransfer" ]; then
      wget -q -O /tmp/artransfer.tar.gz https://github.com/ArtalkJS/Artransfer/releases/latest/download/artransfer_linux_amd64.tar.gz
      tar -xzf /tmp/artransfer.tar.gz -C /tmp/
      chmod +x /tmp/artransfer
    fi
    
    /tmp/artransfer typecho \
      --dsn="$2" \
      --output="$MIGRATE_DIR/typecho-$(date +%Y%m%d).artrans"
    
    echo "Converted to: $MIGRATE_DIR/typecho-$(date +%Y%m%d).artrans"
    ;;
    
  from-disqus)
    if [ -z "$2" ]; then
      echo "Usage: $0 from-disqus <disqus-xml-file>"
      exit 1
    fi
    echo "Converting Disqus to Artalk format..."
    cp "$2" $MIGRATE_DIR/disqus-import.xml
    
    # Download conversion tool
    if [ ! -f "/tmp/artransfer" ]; then
      wget -q -O /tmp/artransfer.tar.gz https://github.com/ArtalkJS/Artransfer/releases/latest/download/artransfer_linux_amd64.tar.gz
      tar -xzf /tmp/artransfer.tar.gz -C /tmp/
      chmod +x /tmp/artransfer
    fi
    
    /tmp/artransfer disqus \
      --xml="$MIGRATE_DIR/disqus-import.xml" \
      --output="$MIGRATE_DIR/disqus-$(date +%Y%m%d).artrans"
    
    echo "Converted to: $MIGRATE_DIR/disqus-$(date +%Y%m%d).artrans"
    ;;
    
  from-waline)
    if [ -z "$2" ]; then
      echo "Usage: $0 from-waline <waline-database>"
      exit 1
    fi
    echo "Converting Waline to Artalk format..."
    
    if [ ! -f "/tmp/artransfer" ]; then
      wget -q -O /tmp/artransfer.tar.gz https://github.com/ArtalkJS/Artransfer/releases/latest/download/artransfer_linux_amd64.tar.gz
      tar -xzf /tmp/artransfer.tar.gz -C /tmp/
      chmod +x /tmp/artransfer
    fi
    
    /tmp/artransfer waline \
      --db="$2" \
      --output="$MIGRATE_DIR/waline-$(date +%Y%m%d).artrans"
    
    echo "Converted to: $MIGRATE_DIR/waline-$(date +%Y%m%d).artrans"
    ;;
    
  from-valine)
    if [ -z "$2" ]; then
      echo "Usage: $0 from-valine <valine-json-file>"
      exit 1
    fi
    echo "Converting Valine to Artalk format..."
    
    if [ ! -f "/tmp/artransfer" ]; then
      wget -q -O /tmp/artransfer.tar.gz https://github.com/ArtalkJS/Artransfer/releases/latest/download/artransfer_linux_amd64.tar.gz
      tar -xzf /tmp/artransfer.tar.gz -C /tmp/
      chmod +x /tmp/artransfer
    fi
    
    /tmp/artransfer valine \
      --json="$2" \
      --output="$MIGRATE_DIR/valine-$(date +%Y%m%d).artrans"
    
    echo "Converted to: $MIGRATE_DIR/valine-$(date +%Y%m%d).artrans"
    ;;
    
  *)
    echo "Artalk Migration Tool"
    echo "====================="
    echo "Usage: $0 {command}"
    echo ""
    echo "Commands:"
    echo "  from-wp <file>        Import from WordPress XML"
    echo "  from-typecho <dsn>    Import from Typecho"
    echo "  from-disqus <file>     Import from Disqus XML"
    echo "  from-waline <dsn>      Import from Waline"
    echo "  from-valine <file>     Import from Valine JSON"
    echo ""
    echo "After conversion, import using: artalk-admin import <filename>"
    exit 1
    ;;
esac
EOF

chmod +x /usr/local/bin/artalk-migrate

# ============= CREATE CLIENT INTEGRATION GUIDE =============
log "Creating client integration guide..."
cat > $ARTALK_DIR/client-integration.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Artalk Integration Guide</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: #f5f5f5; }
        pre { background: #f0f0f0; padding: 15px; border-radius: 8px; overflow-x: auto; }
        code { background: #f0f0f0; padding: 2px 5px; border-radius: 4px; }
        .example { background: white; padding: 20px; border-radius: 12px; margin: 20px 0; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        h2 { color: #666; margin-top: 30px; }
        .note { background: #fff3cd; border-left: 4px solid #ffc107; padding: 10px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>📝 Artalk Comment System Integration Guide</h1>
    <p>Server: <strong>https://$DOMAIN_NAME</strong></p>
    
    <div class="example">
        <h2>Method 1: Basic HTML Integration</h2>
        <p>Add this to your HTML where you want comments to appear:</p>
        <pre>&lt;!-- CSS --&gt;
&lt;link href="https://$DOMAIN_NAME/dist/Artalk.css" rel="stylesheet" /&gt;

&lt;!-- JS --&gt;
&lt;script src="https://$DOMAIN_NAME/dist/Artalk.js"&gt;&lt;/script&gt;

&lt;!-- Comment Container --&gt;
&lt;div id="Comments"&gt;&lt;/div&gt;

&lt;script&gt;
Artalk.init({
    el: '#Comments',
    pageKey: window.location.pathname,
    pageTitle: document.title,
    server: 'https://$DOMAIN_NAME',
    site: '$SITE_NAME',
    // Optional settings:
    // gravatar: 'mp',
    // vote: true,
    // nestedComments: true,
    // pageView: false
});
&lt;/script&gt;</pre>
    </div>

    <div class="example">
        <h2>Method 2: NPM Installation</h2>
        <p>For modern JavaScript projects:</p>
        <pre>npm install artalk</pre>
        <pre>import 'artalk/Artalk.css';
import Artalk from 'artalk';

const comment = Artalk.init({
    el: '#Comments',
    pageKey: '/post/1',
    pageTitle: 'My Blog Post',
    server: 'https://$DOMAIN_NAME',
    site: '$SITE_NAME'
});</pre>
    </div>

    <div class="example">
        <h2>Method 3: ES Module (CDN)</h2>
        <pre>&lt;link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/artalk/2.9.1/Artalk.css"&gt;

&lt;div id="Comments"&gt;&lt;/div&gt;

&lt;script type="module"&gt;
    import Artalk from 'https://esm.sh/artalk@2.9.1';
    
    Artalk.init({
        el: '#Comments',
        pageKey: window.location.pathname,
        pageTitle: document.title,
        server: 'https://$DOMAIN_NAME',
        site: '$SITE_NAME'
    });
&lt;/script&gt;</pre>
    </div>

    <div class="example">
        <h2>Method 4: WordPress Integration</h2>
        <p>Add to your theme's functions.php or use a custom plugin:</p>
        <pre>&lt;?php
// Add Artalk to single post pages
function add_artalk_comments() {
    if (is_single()) {
        ?>
        &lt;link href="https://$DOMAIN_NAME/dist/Artalk.css" rel="stylesheet" /&gt;
        &lt;script src="https://$DOMAIN_NAME/dist/Artalk.js"&gt;&lt;/script&gt;
        &lt;div id="Comments"&gt;&lt;/div&gt;
        &lt;script&gt;
        Artalk.init({
            el: '#Comments',
            pageKey: '&lt;?php echo get_permalink(); ?&gt;',
            pageTitle: '&lt;?php echo get_the_title(); ?&gt;',
            server: 'https://$DOMAIN_NAME',
            site: '$SITE_NAME'
        });
        &lt;/script&gt;
        &lt;?php
    }
}
add_action('wp_footer', 'add_artalk_comments');
?&gt;</pre>
    </div>

    <div class="example">
        <h2>Method 5: Hexo Integration</h2>
        <p>Add to your theme's layout file (e.g., article.ejs):</p>
        <pre>&lt;!-- Add to &lt;head&gt; --&gt;
&lt;link href="https://$DOMAIN_NAME/dist/Artalk.css" rel="stylesheet" /&gt;
&lt;script src="https://$DOMAIN_NAME/dist/Artalk.js"&gt;&lt;/script&gt;

&lt;!-- Where comments should appear --&gt;
&lt;div id="Comments"&gt;&lt;/div&gt;

&lt;script&gt;
Artalk.init({
    el: '#Comments',
    pageKey: '&lt;%= page.permalink %&gt;',
    pageTitle: '&lt;%= page.title %&gt;',
    server: 'https://$DOMAIN_NAME',
    site: '$SITE_NAME'
});
&lt;/script&gt;</pre>
    </div>

    <div class="example">
        <h2>Method 6: Vue.js Integration</h2>
        <pre>&lt;template&gt;
    &lt;div ref="artalkContainer"&gt;&lt;/div&gt;
&lt;/template&gt;

&lt;script&gt;
import 'artalk/Artalk.css';
import Artalk from 'artalk';

export default {
    name: 'ArtalkComments',
    props: {
        pageKey: String,
        pageTitle: String
    },
    mounted() {
        this.artalk = Artalk.init({
            el: this.\$refs.artalkContainer,
            pageKey: this.pageKey,
            pageTitle: this.pageTitle,
            server: 'https://$DOMAIN_NAME',
            site: '$SITE_NAME'
        });
    },
    beforeDestroy() {
        if (this.artalk) {
            this.artalk.destroy();
        }
    }
};
&lt;/script&gt;</pre>
    </div>

    <div class="note">
        <strong>⚠️ Important Notes:</strong>
        <ul>
            <li>Replace <code>window.location.pathname</code> with a unique identifier for each page</li>
            <li>The <code>pageKey</code> should be unique per page/post</li>
            <li>Make sure your main site URL is added to CORS allow list</li>
            <li>First commenter becomes admin if email matches configured admin email</li>
        </ul>
    </div>

    <h2>🔧 Available Configuration Options</h2>
    <pre>{
    el: '#Comments',              // Container element
    pageKey: '/post/1',           // Unique page identifier
    pageTitle: 'Post Title',      // Page title
    server: 'https://$DOMAIN_NAME', // Artalk server
    site: '$SITE_NAME',           // Site name
    
    // Optional:
    gravatar: 'mp',               // Gravatar type
    vote: true,                   // Enable voting
    nestedComments: true,         // Enable nested comments
    pageView: false,              // Enable page view stats
    markdown: true,               // Enable Markdown
    emoji: true,                  // Enable emojis
    userBadge: true,              // Show user badges
    voteDown: true,               // Allow downvoting
    flatMode: 'auto',             // 'auto' or false
    maxNesting: 3,                // Max nesting level
    adminOnly: false,             // Admin only mode
    noComment: false,             // Disable new comments
    sendBtn: 'Send',              // Send button text
    placeholder: 'Write a comment...' // Input placeholder
}</pre>

    <h2>📊 Dashboard Access</h2>
    <p>Access the admin dashboard at: <a href="https://$DOMAIN_NAME" target="_blank">https://$DOMAIN_NAME</a></p>
    <p>Login with your admin email and password (set via <code>artalk-admin create-admin</code>)</p>

    <hr>
    <p>📚 <a href="https://artalk.js.org/" target="_blank">Official Artalk Documentation</a></p>
</body>
</html>
EOF

# ============= CREATE MONITORING SCRIPT =============
log "Creating monitoring script..."
cat > /usr/local/bin/artalk-monitor << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/artalk-monitor.log"
ARTALK_DIR="/opt/artalk"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check if container is running
if ! docker ps --format "{{.Names}}" | grep -q artalk; then
    log_message "Artalk container not running - restarting"
    cd $ARTALK_DIR && docker-compose up -d
fi

# Check container health
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' artalk 2>/dev/null)
if [ "$HEALTH" != "healthy" ]; then
    log_message "Artalk health check: $HEALTH"
fi

# Check disk usage
DATA_SIZE=$(du -sm $ARTALK_DIR/data 2>/dev/null | cut -f1)
if [ "$DATA_SIZE" -gt 1000 ]; then  # 1GB warning
    log_message "WARNING: Data directory size: ${DATA_SIZE}MB"
fi

# Check if port 8080 is listening
if ! ss -tulpn | grep -q ":8080 "; then
    log_message "Port 8080 not listening - restarting"
    cd $ARTALK_DIR && docker-compose restart
fi

# Log status
log_message "Monitor complete - Data: ${DATA_SIZE:-0}MB"
EOF

chmod +x /usr/local/bin/artalk-monitor

# ============= CONFIGURE FIREWALL =============
log "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw --force disable
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 8080/tcp comment 'Artalk HTTP'
    ufw --force enable
    log "✅ Firewall configured"
else
    apt-get install -y -qq ufw
    ufw --force disable
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    ufw allow 8080/tcp comment 'Artalk HTTP'
    ufw --force enable
fi

# ============= STOP SERVICES USING PORT 80/443 =============
log "Stopping any services using ports 80/443..."
systemctl stop nginx 2>/dev/null || true
pkill -f nginx 2>/dev/null || true
sleep 2
fuser -k 80/tcp 2>/dev/null || true
fuser -k 443/tcp 2>/dev/null || true
sleep 2

# ============= INSTALL NGINX AND SSL =============
log "Installing nginx and SSL tools..."
apt-get install -y -qq nginx certbot python3-certbot-nginx

# Stop nginx
systemctl stop nginx 2>/dev/null || true
sleep 2

# Get SSL certificate
log "Obtaining SSL certificate for $DOMAIN_NAME..."
if certbot certonly --standalone -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "$SSL_EMAIL"; then
    log "✅ SSL certificate obtained successfully"
    SSL_ENABLED=true
else
    warn "SSL certificate failed. Continuing with HTTP only..."
    SSL_ENABLED=false
fi

# ============= CREATE NGINX CONFIGURATION =============
log "Creating nginx reverse proxy configuration..."

if [ "$SSL_ENABLED" = true ]; then
    cat > /etc/nginx/sites-available/$DOMAIN_NAME << EOF
# HTTP redirect to HTTPS
server {
    listen 80;
    server_name $DOMAIN_NAME $DROPLET_IP;
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Artalk static files
    location /dist/ {
        proxy_pass http://127.0.0.1:8080/dist/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Artalk API
    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_buffering off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Artalk Dashboard
    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_buffering off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check
    location = /health {
        proxy_pass http://127.0.0.1:8080/api/health;
        access_log off;
    }
}
EOF
else
    cat > /etc/nginx/sites-available/$DOMAIN_NAME << EOF
# HTTP server
server {
    listen 80;
    server_name $DOMAIN_NAME $DROPLET_IP;
    
    # Artalk static files
    location /dist/ {
        proxy_pass http://127.0.0.1:8080/dist/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Artalk API
    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        proxy_buffering off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Artalk Dashboard
    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        proxy_buffering off;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check
    location = /health {
        proxy_pass http://127.0.0.1:8080/api/health;
        access_log off;
    }
}
EOF
fi

# Enable nginx site
ln -sf /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test nginx configuration
log "Testing nginx configuration..."
if nginx -t; then
    log "✅ Nginx configuration test passed"
else
    error "Nginx configuration test failed"
fi

# Add domain to hosts file
log "Adding $DOMAIN_NAME to /etc/hosts..."
if ! grep -q "$DOMAIN_NAME" /etc/hosts; then
    cp /etc/hosts /etc/hosts.bak
    echo "127.0.0.1 $DOMAIN_NAME" >> /etc/hosts
    log "✅ Added $DOMAIN_NAME to /etc/hosts"
fi

# ============= START ARTALK =============
log "Starting Artalk with Docker Compose..."
cd $ARTALK_DIR
docker-compose up -d

# Wait for Artalk to start
log "Waiting for Artalk to initialize..."
sleep 10

# Check if Artalk is running
if docker ps | grep -q artalk; then
    log "✅ Artalk is running"
else
    error "Artalk failed to start. Check logs with: docker logs artalk"
fi

# ============= START NGINX =============
systemctl start nginx
systemctl enable nginx

# ============= CREATE ADMIN USER =============
log "Creating admin user for Artalk..."
echo ""
info "You will now create an admin user for Artalk:"
docker exec -it artalk artalk admin

# ============= CREATE SYSTEMD SERVICE =============
log "Creating systemd service..."
cat > /etc/systemd/system/artalk.service << 'EOF'
[Unit]
Description=Artalk Comment System
Requires=docker.service
After=docker.service network-online.target nginx.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker-compose -f /opt/artalk/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f /opt/artalk/docker-compose.yml down
ExecReload=/usr/bin/docker-compose -f /opt/artalk/docker-compose.yml restart
User=root
Group=root
Restart=on-failure
RestartSec=10
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable artalk.service

# ============= CREATE CRON JOBS =============
log "Setting up cron jobs..."
crontab -l 2>/dev/null | grep -v "artalk-monitor" | crontab -
crontab -l 2>/dev/null | grep -v "certbot renew" | crontab -

(crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/artalk-monitor") | crontab -

if [ "$SSL_ENABLED" = true ]; then
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
fi

# ============= CREATE LOG ROTATION =============
cat > /etc/logrotate.d/artalk << 'EOF'
/var/log/artalk-monitor.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}

/opt/artalk/data/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF

# ============= CREATE TEST SCRIPT =============
log "Creating test script..."
cat > /opt/test-artalk.sh << EOF
#!/bin/bash

DOMAIN_NAME="$DOMAIN_NAME"
SSL_ENABLED=$SSL_ENABLED

echo "=== Artalk Test Suite ==="
echo "Domain: \$DOMAIN_NAME"
echo "SSL Enabled: \$SSL_ENABLED"
echo ""

# Test 1: Docker container
echo "1. Testing Docker container..."
if docker ps | grep -q artalk; then
    echo "   ✅ Artalk container is running"
else
    echo "   ❌ Artalk container is not running"
fi

# Test 2: Ports
echo "2. Testing ports..."
ss -tulpn | grep -q ":8080 " && echo "   ✅ Port 8080 (Artalk) listening"
ss -tulpn | grep -q ":80 " && echo "   ✅ Port 80 (HTTP) listening"
if [ "$SSL_ENABLED" = true ]; then
    ss -tulpn | grep -q ":443 " && echo "   ✅ Port 443 (HTTPS) listening"
fi

# Test 3: Artalk API
echo "3. Testing Artalk API..."
API_TEST=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/health)
if [ "\$API_TEST" = "200" ]; then
    echo "   ✅ Artalk API is responding"
else
    echo "   ❌ Artalk API returned \$API_TEST"
fi

# Test 4: Static files
echo "4. Testing static files..."
STATIC_TEST=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/dist/Artalk.js)
if [ "\$STATIC_TEST" = "200" ]; then
    echo "   ✅ Artalk static files are accessible"
else
    echo "   ❌ Artalk static files returned \$STATIC_TEST"
fi

# Test 5: Dashboard
echo "5. Testing dashboard access..."
DASHBOARD_TEST=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)
if [ "\$DASHBOARD_TEST" = "200" ]; then
    echo "   ✅ Artalk dashboard is accessible"
else
    echo "   ❌ Artalk dashboard returned \$DASHBOARD_TEST"
fi

# Test 6: Nginx proxy
echo "6. Testing nginx proxy..."
if [ "\$SSL_ENABLED" = true ]; then
    PROTO="https"
else
    PROTO="http"
fi

PROXY_TEST=\$(curl -s -o /dev/null -w "%{http_code}" "\$PROTO://\$DOMAIN_NAME/api/health" -k)
if [ "\$PROXY_TEST" = "200" ]; then
    echo "   ✅ Nginx proxy is working"
else
    echo "   ❌ Nginx proxy returned \$PROXY_TEST"
fi

echo ""
echo "=== Test Complete ==="
EOF

chmod +x /opt/test-artalk.sh

# ============= CREATE QUICK TEST =============
cat > /opt/quick-artalk.sh << EOF
#!/bin/bash

DOMAIN_NAME="$DOMAIN_NAME"

echo "Quick Artalk Test"
echo "================="
echo ""

# Check service status
echo "1. Service Status:"
docker ps --filter "name=artalk" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check API
echo ""
echo "2. API Health:"
curl -s "http://localhost:8080/api/health" | python3 -m json.tool 2>/dev/null || curl -s "http://localhost:8080/api/health"

# Get version
echo ""
echo "3. Artalk Version:"
docker exec artalk artalk version 2>/dev/null || echo "Unable to get version"

echo ""
echo "For dashboard access:"
echo "  http://\$DOMAIN_NAME"
echo ""
echo "Admin commands:"
echo "  artalk-admin create-admin"
echo "  artalk-admin list-users"
EOF

chmod +x /opt/quick-artalk.sh

# ============= CREATE README =============
cat > /opt/README-artalk.md << EOF
# Artalk Comment System Setup

Lightweight, self-hosted commenting system with SSL and Docker.

## Quick Start

\`\`\`bash
# Test the setup
cd /opt
./test-artalk.sh

# Quick status check
./quick-artalk.sh
\`\`\`

## Admin Commands

\`\`\`bash
artalk-admin create-admin    # Create admin user
artalk-admin list-users      # List all users
artalk-admin reset-password <email>  # Reset password
artalk-admin export          # Export comments
artalk-admin import <file>   # Import comments
artalk-admin backup          # Create backup
artalk-admin status          # Show status
artalk-admin logs            # View logs
artalk-admin update          # Update Artalk
\`\`\`

## Migration Tools

\`\`\`bash
artalk-migrate from-wp <file>        # Import from WordPress
artalk-migrate from-typecho <dsn>    # Import from Typecho
artalk-migrate from-disqus <file>    # Import from Disqus
artalk-migrate from-waline <dsn>     # Import from Waline
artalk-migrate from-valine <file>    # Import from Valine
\`\`\`

## Client Integration

Integration guide available at:
\`\`\`
/opt/artalk/client-integration.html
\`\`\`

Or view online at: https://$DOMAIN_NAME

### Basic HTML Integration

\`\`\`html
<!-- CSS -->
<link href="https://$DOMAIN_NAME/dist/Artalk.css" rel="stylesheet" />

<!-- JS -->
<script src="https://$DOMAIN_NAME/dist/Artalk.js"></script>

<!-- Comment Container -->
<div id="Comments"></div>

<script>
Artalk.init({
    el: '#Comments',
    pageKey: window.location.pathname,
    pageTitle: document.title,
    server: 'https://$DOMAIN_NAME',
    site: '$SITE_NAME'
});
</script>
\`\`\`

## Configuration Files

- Docker Compose: \`/opt/artalk/docker-compose.yml\`
- Artalk Config: \`/opt/artalk/artalk.yml\`
- Nginx Config: \`/etc/nginx/sites-available/$DOMAIN_NAME\`

## Data Management

Data directory: \`/opt/artalk/data/\`
- SQLite database: \`artalk.db\`
- Uploaded images: \`/images/\`

Backups: \`/opt/artalk/backups/\`

## Monitoring

\`\`\`bash
# Manual monitoring
/usr/local/bin/artalk-monitor

# Check logs
tail -f /var/log/artalk-monitor.log

# Docker logs
docker logs -f artalk
\`\`\`

## Security Notes

- Firewall: SSH (22), HTTP (80), HTTPS (443), Artalk (8080) allowed
- SSL certificate: Let's Encrypt
- CORS: Only your configured site URL is allowed
- Admin email: $SSL_EMAIL

## Troubleshooting

\`\`\`bash
# Check service status
systemctl status artalk
systemctl status nginx

# View Docker logs
docker logs artalk

# Restart services
artalk-admin restart
systemctl restart nginx

# Check nginx configuration
nginx -t

# Test connectivity
curl -I https://$DOMAIN_NAME/api/health
\`\`\`

## Update Artalk

\`\`\`bash
artalk-admin update
\`\`\`

## SSL Renewal

SSL certificates auto-renew via cron job daily at 3 AM.

## Support

- Official Documentation: https://artalk.js.org/
- GitHub: https://github.com/ArtalkJS/Artalk
EOF

# ============= RUN INITIAL TEST =============
log "Running initial test..."
/opt/quick-artalk.sh

# ============= FINAL OUTPUT =============
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ARTALK SETUP COMPLETE!                           ║${NC}"
echo -e "${GREEN}║      Lightweight Comment System Deployed                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
log "Your Artalk comment system is ready!"
echo ""
info "Dashboard URL:"
if [ "$SSL_ENABLED" = true ]; then
    echo "  🔒 HTTPS: https://$DOMAIN_NAME"
else
    echo "  🌐 HTTP: http://$DOMAIN_NAME"
fi
echo ""
info "Admin Credentials:"
echo "  You just created an admin user - use those credentials to log in"
echo ""
info "Quick Commands:"
echo "  artalk-admin status          # Check service status"
echo "  artalk-admin create-admin    # Create additional admin"
echo "  artalk-admin list-users      # List all users"
echo "  artalk-admin backup          # Create backup"
echo ""
info "Client Integration:"
echo "  View integration guide: cat /opt/artalk/client-integration.html"
echo "  Or open in browser: https://$DOMAIN_NAME"
echo ""
info "Test Commands:"
echo "  /opt/quick-artalk.sh         # Quick status check"
echo "  /opt/test-artalk.sh          # Comprehensive test"
echo ""
info "Example Integration Code:"
echo '  <div id="Comments"></div>'
echo '  <script src="https://'$DOMAIN_NAME'/dist/Artalk.js"></script>'
echo '  <script>'
echo '  Artalk.init({'
echo "    el: '#Comments',"
echo "    pageKey: '/post/1',"
echo "    server: 'https://$DOMAIN_NAME',"
echo "    site: '$SITE_NAME'"
echo '  });'
echo '  </script>'
echo ""
info "Migration Tools:"
echo "  artalk-migrate from-wp <file>     # Import from WordPress"
echo "  artalk-migrate from-disqus <file> # Import from Disqus"
echo ""
log "✨ Setup complete! Your comment system is ready to use."
log "First, create an admin user if you haven't already: artalk-admin create-admin"