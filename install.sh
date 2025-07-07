#!/bin/bash

# Main installation script for a music store server
# Runs all setup scripts in the correct order

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Source environment variables from .env if it exists
# Load environment variables from .env file
if [ -f .env ]; then
  set -a  # automatically export all variables
  source .env
  set +a  # disable automatic export
fi

# Get domain and email (from .env, environment, or prompt)
if [[ -z "${DOMAIN_NAME:-}" ]]; then
    echo "Domain name not found in .env file or environment."
    read -p "Enter your domain name: " DOMAIN_NAME
fi

if [[ -z "${EMAIL:-}" ]]; then
    echo "Email not found in .env file or environment."
    read -p "Enter your admin email: " EMAIL

# Create .env file with the values for child scripts
echo "DOMAIN_NAME="$DOMAIN_NAME"" > .env
echo "EMAIL="$EMAIL"" >> .env
log "Created .env file with domain and email configuration"
source .env
fi

# If no domain provided, prompt for it
if [[ -z "$DOMAIN_NAME" ]]; then
    read -p "Enter your domain name: " DOMAIN_NAME
fi

if [[ -z "$EMAIL" ]]; then
    read -p "Enter your admin email: " EMAIL

# Create .env file with the values for child scripts
echo "DOMAIN_NAME="$DOMAIN_NAME"" > .env
echo "EMAIL="$EMAIL"" >> .env
log "Created .env file with domain and email configuration"
source .env
fi

log "Starting server setup for domain: $DOMAIN_NAME"
log "Admin email: $EMAIL"

# Function to run script with error handling
run_script() {
    local script_name=$1
    local description=$2
    
    log "Starting: $description"
    
    if [[ ! -f "$script_name" ]]; then
        error "Script $script_name not found!"
        exit 1
    fi
    
    # Missing: actual script execution and error handling
    if ! bash "$script_name"; then
        error "Script $script_name failed!"
        exit 1
    fi
    
    log "Completed: $description"
}

# Pre-flight checks
log "Running pre-flight checks..."

# Check if we have internet connectivity
if ! ping -c 1 google.com &> /dev/null; then
    error "No internet connectivity detected"
    exit 1
fi

# Check if SSH key authentication is working (since we're hardening SSH)
# Check for SSH keys in authorized_keys
ssh_keys_exist=false
if [[ -f ~/.ssh/authorized_keys && -s ~/.ssh/authorized_keys ]]; then
    ssh_keys_exist=true
fi

# Check if running over SSH (may not work with sudo)
ssh_connection_detected=false
if [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]]; then
    ssh_connection_detected=true
fi

# Warn if no SSH keys found
if [[ "$ssh_keys_exist" == false ]]; then
    error "No SSH keys found in ~/.ssh/authorized_keys"
    echo "SSH keys are required because this script disables password authentication"
    echo "Please add your SSH public key before running this script"
    exit 1
fi

# Warn if not detected as SSH connection (but continue if keys exist)
if [[ "$ssh_connection_detected" == false ]]; then
    warning "SSH connection not detected (this may be normal with sudo)"
    warning "Continuing because SSH keys were found in ~/.ssh/authorized_keys"
fi

log "Pre-flight checks passed"

# Run scripts in order
log "=== Starting server installation ==="

# Step 1: LEMP stack and WordPress installation
run_script "install-wordpress.sh" "LEMP stack and WordPress installation"

# Step 2: Security hardening (must be first)
run_script "harden.sh" "Security hardening (SSH, firewall, fail2ban)"

# Step 3: Music store plugins (depends on WordPress)
run_script "install-music-store-plugins.sh" "Music store plugins installation"

log "=== Installation completed successfully! ==="
log "Your music store server is now ready at: https://$DOMAIN_NAME"
log "WordPress admin: https://$DOMAIN_NAME/wp-admin"
log ""
log "Next steps:"
log "1. Configure your DNS to point $DOMAIN_NAME to this server"
log "2. Access WordPress admin to complete setup"
log "3. Install and configure your Bandfront theme"
log "4. Test audio file uploads and playback"
log ""
log "Server services status:"
systemctl status nginx --no-pager -l
systemctl status php8.3-fpm --no-pager -l
systemctl status mariadb --no-pager -l
systemctl status fail2ban --no-pager -l

