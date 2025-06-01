#!/bin/bash
# General Security Hardening Script for Ubuntu - Enhanced Version
# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

echo "Hardening system security..."

# Create backup directory
BACKUP_DIR="/root/security_backups_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup directory created: $BACKUP_DIR"

# Fetch server's public IP (try multiple methods)
echo "Detecting server IP..."
SERVER_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' || hostname -I | awk '{print $1}' || echo "Unable to detect")
echo "Server IP detected: $SERVER_IP"

# Backup original SSH config
echo "Backing up SSH configuration..."
cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup"

# Disable Password Authentication (SSH Keys only)
echo "Disabling password-based authentication for SSH..."
# Handle both commented and uncommented lines in one go
sed -i.bak 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable root login via SSH
echo "Disabling root login via SSH..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable empty passwords
echo "Disabling empty passwords in SSH..."
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Test SSH config before restarting
echo "Testing SSH configuration..."
if sshd -t; then
    echo "SSH config is valid, restarting service..."
    systemctl restart sshd
    if systemctl is-active --quiet sshd; then
        echo "SSH service restarted successfully"
    else
        echo "ERROR: SSH service failed to restart! Check logs and restore from backup if needed."
        echo "Backup location: $BACKUP_DIR/sshd_config.backup"
        exit 1
    fi
else
    echo "ERROR: SSH config test failed! Restoring backup..."
    cp "$BACKUP_DIR/sshd_config.backup" /etc/ssh/sshd_config
    systemctl restart ssh
    echo "SSH config restored from backup"
    exit 1
fi

# Configure firewall with UFW
echo "Setting up UFW firewall..."
# Check if UFW is already enabled
if ufw status | grep -q "Status: active"; then
    echo "UFW is already active, updating rules..."
else
    echo "UFW is inactive, configuring and enabling..."
fi

ufw --force default deny incoming
ufw --force default allow outgoing
ufw --force allow in on lo  # Allow local traffic
ufw --force allow OpenSSH   # Allow SSH traffic
ufw --force allow 80/tcp    # Allow HTTP traffic
ufw --force allow 443/tcp   # Allow HTTPS traffic

# Enable UFW firewall (--force to avoid interactive prompt)
echo "Enabling UFW firewall..."
ufw --force enable
ufw status

# Update package list
echo "Updating package lists..."
apt update

# Install Fail2Ban to protect against SSH brute force attacks
echo "Installing Fail2Ban..."
apt install -y fail2ban

# Configure Fail2Ban for SSH protection
echo "Configuring Fail2Ban for SSH protection..."
cat <<EOF > /etc/fail2ban/jail.d/ssh.conf
[ssh]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

# Enable and start Fail2Ban
systemctl enable fail2ban
systemctl restart fail2ban

# Verify Fail2Ban is running
if systemctl is-active --quiet fail2ban; then
    echo "Fail2Ban is running successfully"
else
    echo "WARNING: Fail2Ban failed to start properly"
fi

# Install necessary security utilities
echo "Installing security utilities (chkrootkit, rkhunter)..."
apt install -y chkrootkit rkhunter

# Configure log rotation (check if entries already exist)
echo "Configuring log rotation..."
LOGROTATE_FILE="/etc/logrotate.d/security-hardening"

# Create a separate logrotate file to avoid conflicts
cat <<EOF > "$LOGROTATE_FILE"
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
EOF

# Test logrotate configuration
echo "Testing logrotate configuration..."
if logrotate -d "$LOGROTATE_FILE" > /dev/null 2>&1; then
    echo "Logrotate configuration is valid"
else
    echo "WARNING: Logrotate configuration may have issues"
fi

# Display completion message
echo "=========================="
echo "Security Hardening Complete!"
echo "=========================="
echo "Server IP: $SERVER_IP"
echo "SSH Password Authentication: Disabled"
echo "SSH Root Login: Disabled"
echo "Empty Passwords: Disabled"
echo "UFW Firewall: Enabled with HTTP/HTTPS/SSH allowed"
echo "Fail2Ban: Installed and configured for SSH protection"
echo "Security Tools: chkrootkit and rkhunter installed"
echo "Backup Location: $BACKUP_DIR"
echo "=========================="
echo ""
echo "IMPORTANT: Make sure you have SSH keys set up before logging out!"
echo "If you get locked out, restore SSH config from: $BACKUP_DIR/sshd_config.backup"
