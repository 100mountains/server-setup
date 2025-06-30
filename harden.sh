#!/bin/bash
# General Security Hardening Script for Ubuntu - Enhanced Version with Optimized fail2ban
# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
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
cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup" || echo "Warning: Failed to backup SSH config, continuing..."

# Disable Password Authentication (SSH Keys only)
echo "Disabling password-based authentication for SSH..."
# Handle both commented and uncommented lines in one go
sed -i.bak 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config || echo "Warning: Failed to modify PasswordAuthentication, continuing..."

# Disable root login via SSH
echo "Disabling root login via SSH..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || echo "Warning: Failed to modify PermitRootLogin, continuing..."

# Disable empty passwords
echo "Disabling empty passwords in SSH..."
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config || echo "Warning: Failed to modify PermitEmptyPasswords, continuing..."

# Test SSH config before restarting
echo "Testing SSH configuration..."
if sshd -t; then
    echo "SSH config is valid, restarting service..."
    systemctl restart sshd || echo "Warning: Failed to restart SSH service, continuing..."
    if systemctl is-active --quiet sshd; then
        echo "SSH service restarted successfully"
    else
        echo "WARNING: SSH service failed to restart! Check logs and restore from backup if needed."
        echo "Backup location: $BACKUP_DIR/sshd_config.backup"
        echo "Continuing with security hardening..."
    fi
else
    echo "WARNING: SSH config test failed! Restoring backup..."
    cp "$BACKUP_DIR/sshd_config.backup" /etc/ssh/sshd_config || echo "Failed to restore SSH backup"
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
ufw --force default deny incoming || echo "Warning: Failed to set UFW default deny incoming, continuing..."
ufw --force default allow outgoing || echo "Warning: Failed to set UFW default allow outgoing, continuing..."
ufw --force allow OpenSSH || echo "Warning: Failed to allow OpenSSH, continuing..."   # Allow SSH traffic
ufw --force allow in on lo || echo "Warning: Failed to allow loopback traffic, continuing..."  # Allow local traffic
ufw --force allow 80/tcp || echo "Warning: Failed to allow HTTP, continuing..."    # Allow HTTP traffic
ufw --force allow 443/tcp || echo "Warning: Failed to allow HTTPS, continuing..."   # Allow HTTPS traffic

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

# Create comprehensive jail.local configuration
cat > /etc/fail2ban/jail.local << 'FAIL2BAN_EOF'
[DEFAULT]
# Default ban time for all jails (24 hours)
bantime = 86400

# Default find time (10 minutes)
findtime = 600

# Default max retry (5 attempts)
maxretry = 5

# Ignore local networks (adjust as needed)
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
# Enhanced SSH protection - stricter than defaults
bantime = 86400
maxretry = 3
findtime = 600

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-bad-request]
enabled = true
port = http,https
filter = nginx-bad-request
logpath = /var/log/nginx/access.log
maxretry = 10
bantime = 3600

[nginx-botsearch]
enabled = true
port = http,https
filter = nginx-botsearch
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 86400

[nginx-limit-req]
enabled = true
port = http,https
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
bantime = 600

[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
action = %(action_mwl)s
protocol = all
bantime = 604800
findtime = 86400
maxretry = 3
FAIL2BAN_EOF

# Update the sshd.local file to ensure SSH settings take precedence
cat > /etc/fail2ban/jail.d/sshd.local << 'SSHD_EOF'
[sshd]
enabled = true
bantime = 86400
maxretry = 3
findtime = 600
SSHD_EOF

echo "fail2ban configuration files created successfully"

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

# Configure log rotation (check if entries already exist)
echo "Configuring log rotation..."
LOGROTATE_FILE="/etc/logrotate.d/security-hardening"

# Create a separate logrotate file to avoid conflicts
cat > "$LOGROTATE_FILE" << 'LOGROTATE_EOF' || echo "Warning: Failed to create logrotate config, continuing..."
# Custom log rotation for security hardening
/var/log/auth.log {
    rotate 7
    daily
    compress
    missingok
    notifempty
    create 640 root adm
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/syslog {
    rotate 7
    daily
    compress
    missingok
    notifempty
    create 640 root adm
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/kern.log {
    rotate 7
    weekly
    compress
    missingok
    notifempty
    create 640 root adm
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/fail2ban.log {
    rotate 7
    daily
    compress
    missingok
    notifempty
    create 640 root adm
    postrotate
        systemctl reload fail2ban > /dev/null 2>&1 || true
    endscript
}
LOGROTATE_EOF

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
echo "If you get locked out, restore SSH config from: $BACKUP_DIR/sshd_config.backup"
echo ""
echo "fail2ban monitoring commands:"
echo "  - Check status: sudo fail2ban-client status"
echo "  - Check specific jail: sudo fail2ban-client status <jail_name>"
echo "  - View logs: sudo tail -f /var/log/fail2ban.log"
echo "  - Unban IP: sudo fail2ban-client unban <ip_address>"
