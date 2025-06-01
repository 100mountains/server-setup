#!/bin/bash
# General Security Hardening Script for Ubuntu

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

echo "Hardening system security..."

# Fetch server's public IP (using hostname -I)
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Server IP detected: $SERVER_IP"

# Disable Password Authentication (SSH Keys only)
echo "Disabling password-based authentication for SSH..."
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable root login via SSH
echo "Disabling root login via SSH..."
sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable empty passwords (important security measure)
echo "Disabling empty passwords in SSH..."
sed -i 's/^#PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/^PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
echo "Restarting SSH service..."
systemctl restart sshd

# Configure firewall with UFW (Uncomplicated Firewall)
echo "Setting up UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow in on lo  # Allow local traffic
ufw allow OpenSSH   # Allow SSH traffic
ufw allow 80/tcp    # Allow HTTP traffic
ufw allow 443/tcp   # Allow HTTPS traffic

# Enable UFW firewall
echo "Enabling UFW firewall..."
ufw enable
ufw status

# Install Fail2Ban to protect against SSH brute force attacks
echo "Installing Fail2Ban..."
apt update
apt install -y fail2ban

# Configure Fail2Ban for SSH protection
cat <<EOF > /etc/fail2ban/jail.d/ssh.conf
[ssh]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

# Restart Fail2Ban to apply the SSH configuration
systemctl restart fail2ban

# Install necessary security utilities
echo "Installing security utilities (chkrootkit, rkhunter)..."
apt install -y chkrootkit rkhunter

# Configure log rotation for logs (optional, tweak as needed)
echo "Configuring log rotation..."
cat <<EOF >> /etc/logrotate.d/ubuntu
/var/log/auth.log {
    rotate 7
    daily
    compress
    missingok
    notifempty
    create 640 root adm
}

/var/log/syslog {
    rotate 7
    daily
    compress
    missingok
    notifempty
    create 640 root adm
}

/var/log/kern.log {
    rotate 7
    weekly
    compress
    missingok
    notifempty
    create 640 root adm
}
EOF

# Ensure that logrotate is set up correctly
logrotate --debug /etc/logrotate.conf

# Display completion message
echo "=========================="
echo "Security Hardening Complete!"
echo "=========================="
echo "SSH Password Authentication: Disabled"
echo "SSH Root Login: Disabled"
echo "Empty Passwords: Disabled"
echo "Fail2Ban: Installed and configured for SSH"
echo "=========================="

