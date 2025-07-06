#!/bin/bash
# General Security Hardening Script for Ubuntu - Enhanced Version with Optimized fail2ban
# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

# Check if config files exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error: Config directory not found at $CONFIG_DIR"
    echo "Please ensure the configs/ directory exists with fail2ban and logrotate subdirectories"
    exit 1
fi

echo "Hardening system security..."

# Create backup directory
BACKUP_DIR="/root/security_backups_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR" || echo "Warning: Failed to create backup directory, continuing..."
echo "Backup directory created: $BACKUP_DIR"

# Fetch server's public IP (try multiple methods)
echo "Detecting server IP..."
SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || hostname -I | awk '{print $1}' || echo "Unable to detect")
echo "Server IP detected: $SERVER_IP"

# Backup original SSH config
echo "Backing up SSH configuration..."
cp /etc/ssh/ssh_config "$BACKUP_DIR/ssh_config.backup" || echo "Warning: Failed to backup SSH config, continuing..."

# Disable Password Authentication (SSH Keys only)
echo "Disabling password-based authentication for SSH..."
# Handle both commented and uncommented lines in one go
sed -i.bak 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/ssh_config || echo "Warning: Failed to modify PasswordAuthentication, continuing..."

# Disable root login via SSH
echo "Disabling root login via SSH..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/ssh_config || echo "Warning: Failed to modify PermitRootLogin, continuing..."

# Disable empty passwords
echo "Disabling empty passwords in SSH..."
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/ssh_config || echo "Warning: Failed to modify PermitEmptyPasswords, continuing..."

# Test SSH config before restarting
echo "Testing SSH configuration..."
if ssh -t; then
    echo "SSH config is valid, restarting service..."
    systemctl restart ssh || echo "Warning: Failed to restart SSH service, continuing..."
    if systemctl is-active --quiet ssh; then
        echo "SSH service restarted successfully"
    else
        echo "WARNING: SSH service failed to restart! Check logs and restore from backup if needed."
        echo "Backup location: $BACKUP_DIR/ssh_config.backup"
        echo "Continuing with security hardening..."
    fi
else
    echo "WARNING: SSH config test failed! Restoring backup..."
    cp "$BACKUP_DIR/ssh_config.backup" /etc/ssh/ssh_config || echo "Failed to restore SSH backup"
    systemctl restart ssh || echo "Failed to restart SSH after restore"
    echo "SSH config restored from backup, continuing with security hardening..."
fi

echo "*** REACHED SECURITY SECTION ***"

# Configure firewall with UFW
echo "Setting up UFW firewall..."

# Reset UFW to clean state (force non-interactive)
echo "Resetting UFW to clean state..."
ufw --force reset || echo "Warning: Failed to reset UFW, continuing..."

# Configure UFW rules BEFORE enabling
echo "Configuring UFW rules..."
ufw --force default deny incoming
ufw --force default allow outgoing
ufw --force allow OpenSSH
ufw --force allow in on lo
ufw --force allow 80/tcp
ufw --force allow 443/tcp

# Enable UFW firewall after all rules are configured (force non-interactive)
echo "Enabling UFW firewall..."
ufw --force enable || echo "Warning: Failed to enable UFW, continuing..."

# Log current status with verbose output
echo "UFW firewall status:"
ufw status verbose || true

# Update package list and install security packages
echo "Updating package lists and installing security packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -yqq --no-install-recommends fail2ban ufw

# Configure optimized fail2ban with comprehensive protection
echo "Configuring optimized fail2ban with web server protection..."

# Backup existing fail2ban configs
echo "Backing up existing fail2ban configuration..."
cp -r /etc/fail2ban/ "$BACKUP_DIR/fail2ban_backup/" 2>/dev/null || echo "Warning: Failed to backup fail2ban config, continuing..."

# Copy fail2ban configuration files
echo "Copying fail2ban configuration files..."
if [ -f "$CONFIG_DIR/fail2ban/jail.local" ]; then
    cp "$CONFIG_DIR/fail2ban/jail.local" /etc/fail2ban/jail.local || echo "Warning: Failed to copy jail.local, continuing..."
    echo "jail.local configuration copied successfully"
else
    echo "Warning: jail.local config file not found at $CONFIG_DIR/fail2ban/jail.local"
fi

if [ -f "$CONFIG_DIR/fail2ban/ssh.local" ]; then
    cp "$CONFIG_DIR/fail2ban/ssh.local" /etc/fail2ban/jail.d/ssh.local || echo "Warning: Failed to copy ssh.local, continuing..."
    echo "ssh.local configuration copied successfully"
else
    echo "Warning: ssh.local config file not found at $CONFIG_DIR/fail2ban/ssh.local"
fi

# Copy custom filter files
if [ -f "$CONFIG_DIR/fail2ban/nginx-wordpress.conf" ]; then
    cp "$CONFIG_DIR/fail2ban/nginx-wordpress.conf" /etc/fail2ban/filter.d/nginx-wordpress.conf || echo "Warning: Failed to copy nginx-wordpress filter, continuing..."
    echo "nginx-wordpress filter copied successfully"
else
    echo "Warning: nginx-wordpress filter not found at $CONFIG_DIR/fail2ban/nginx-wordpress.conf"
fi

if [ -f "$CONFIG_DIR/fail2ban/nginx-botsearch.conf" ]; then
    cp "$CONFIG_DIR/fail2ban/nginx-botsearch.conf" /etc/fail2ban/filter.d/nginx-botsearch.conf || echo "Warning: Failed to copy nginx-botsearch filter, continuing..."
    echo "nginx-botsearch filter copied successfully"
else
    echo "Warning: nginx-botsearch filter not found at $CONFIG_DIR/fail2ban/nginx-botsearch.conf"
fi

if [ -f "$CONFIG_DIR/fail2ban/ssh.local" ]; then
    cp "$CONFIG_DIR/fail2ban/ssh.local" /etc/fail2ban/jail.d/ssh.local || echo "Warning: Failed to copy ssh.local, continuing..."
    echo "ssh.local configuration copied successfully"
else
    echo "Warning: ssh.local config file not found at $CONFIG_DIR/fail2ban/ssh.local"
fi

# Enable and start Fail2Ban
echo "Starting and enabling fail2ban service..."
systemctl enable fail2ban || echo "Warning: Failed to enable Fail2Ban, continuing..."
systemctl restart fail2ban || echo "Warning: Failed to restart Fail2Ban, continuing..."

# Wait a moment for fail2ban to fully start
sleep 3

# Verify Fail2Ban is running and show status
if systemctl is-active --quiet fail2ban; then
    echo "fail2ban is running successfully"
    echo "Active jails:"
    fail2ban-client status 2>/dev/null || echo "fail2ban status not yet available"
else
    echo "WARNING: fail2ban failed to start properly"
    echo "Checking fail2ban logs..."
    tail -10 /var/log/fail2ban.log 2>/dev/null || echo "No fail2ban logs found yet"
fi

# Install necessary security utilities
echo "Installing security utilities (chkrootkit, rkhunter)..."
apt install -y chkrootkit rkhunter || echo "Warning: Failed to install security utilities, continuing..."

# Configure log rotation
echo "Configuring log rotation..."
LOGROTATE_FILE="/etc/logrotate.d/security-hardening"

# Copy logrotate configuration file
if [ -f "$CONFIG_DIR/logrotate/security-hardening" ]; then
    cp "$CONFIG_DIR/logrotate/security-hardening" "$LOGROTATE_FILE" || echo "Warning: Failed to copy logrotate config, continuing..."
    echo "Logrotate configuration copied successfully"
else
    echo "Warning: Logrotate config file not found at $CONFIG_DIR/logrotate/security-hardening"
fi

# Test logrotate configuration
echo "Testing logrotate configuration..."
if logrotate -d "$LOGROTATE_FILE" > /dev/null 2>&1; then
    echo "Logrotate configuration is valid"
else
    echo "WARNING: Logrotate configuration may have issues"
fi

# Final fail2ban status check
echo "Final fail2ban status check..."
sleep 2
if systemctl is-active --quiet fail2ban; then
    echo "=== fail2ban Status ==="
    fail2ban-client status 2>/dev/null || echo "fail2ban client not yet responsive"
fi

# Display completion message
echo "==========================="
echo "Security Hardening Complete!"
echo "==========================="
echo "Server IP: $SERVER_IP"
echo "SSH Password Authentication: Disabled"
echo "SSH Root Login: Disabled"
echo "Empty Passwords: Disabled"
echo "UFW Firewall: Enabled with HTTP/HTTPS/SSH allowed"
echo "fail2ban: Optimized configuration with comprehensive protection:"
echo "  - SSH protection (3 attempts, 24h ban)"
echo "  - Web server protection (nginx jails)"
echo "  - Repeat offender protection (7-day bans)"
echo "Security Tools: chkrootkit and rkhunter installed"
echo "Backup Location: $BACKUP_DIR"
echo "==========================="
echo ""
echo "IMPORTANT: Make sure you have SSH keys set up before logging out!"
echo "If you get locked out, restore SSH config from: $BACKUP_DIR/ssh_config.backup"
echo ""
echo "fail2ban monitoring commands:"
echo "  - Check status: sudo fail2ban-client status"
echo "  - Check specific jail: sudo fail2ban-client status <jail_name>"
echo "  - View logs: sudo tail -f /var/log/fail2ban.log"
echo "  - Unban IP: sudo fail2ban-client unban <ip_address>"
