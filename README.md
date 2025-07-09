# 🚀 Server Setup Scripts

Automated server setup for a WordPress music store with WooCommerce, optimized for high-performance servers (32GB RAM) running Ubuntu 24.04.

## Quick Installation

```bash
# Clone and run with automatic setup
git clone https://github.com/100mountains/server-setup.git && \
cd server-setup && \
sudo ./install.sh
```

**Or with pre-configured environment:**

```bash
git clone https://github.com/100mountains/server-setup.git
cd server-setup
echo 'DOMAIN_NAME="your.domain.com"' > .env
echo 'EMAIL="admin@your.domain.com"' >> .env
sudo ./install.sh
```

## 📋 Prerequisites

- Fresh Ubuntu 24.04 server
- SSH key access configured (password authentication will be disabled)
- Root or sudo access
- Domain name pointing to your server

## 🎯 What Gets Installed

### Core Stack
- **Nginx** - Web server with audio streaming optimizations
- **MariaDB** - Database optimized for 32GB RAM
- **PHP 8.3** - With FPM and all required extensions
- **WordPress** - Latest version with WP-CLI
- **SSL/TLS** - Let's Encrypt certificates via Certbot

### WordPress Plugins
| Plugin | Purpose | Configuration |
|--------|---------|---------------|
| **WooCommerce** | E-commerce platform | Optimized for digital downloads |
| **WooCommerce PayPal Payments** | Payment processing | Ready for configuration |
| **Theme My Login** | Custom login/registration | Enhanced user experience |
| **WP Armour - Honeypot Anti Spam** | Spam protection | Honeypot enabled |
| **MailPoet** | Email marketing | Analytics disabled |
| **List Category Posts** | Content organization | Category listings |
| **Bandfront Player** | Music player | Audio playback |

### Theme
- **Storefront** - Parent theme (auto-installed)
- **Bandfront** - Custom child theme for music stores ([GitHub](https://github.com/100mountains/bandfront))

## 📁 Project Structure

```
server-setup/
├── install.sh                      # Main installation orchestrator
├── install-wordpress.sh            # LEMP stack and WordPress setup
├── install-music-store-plugins.sh  # Plugin installation
├── harden.sh                       # Security hardening
├── .env                           # Environment configuration
├── configs/                       # Configuration templates
│   ├── nginx/                     # Nginx configurations
│   ├── php/                       # PHP-FPM settings
│   ├── mariadb/                   # Database optimizations
│   ├── wordpress/                 # WordPress config
│   ├── fail2ban/                  # Security rules
│   ├── systemd/                   # Service dependencies
│   └── logrotate/                 # Log management
├── themes/                        # WordPress themes
│   └── bandfront/                 # Music store theme (submodule)
└── tests/
    └── compare_installation.sh    # System validation script
```

## 🔧 Configuration Details

### Performance Optimizations (32GB RAM Server)

#### Memory Allocation
| Component | Allocation | Purpose |
|-----------|------------|---------|
| MariaDB InnoDB Buffer | 20GB | Database caching |
| PHP Memory Limit | 8GB | Script execution |
| PHP OPcache | 256MB | Compiled code cache |
| System/OS | ~3GB | Operating system |

#### Concurrent Capacity
| Service | Capacity | Purpose |
|---------|----------|---------|
| MariaDB Connections | 500 | Database connections |
| PHP-FPM Processes | 200 | Concurrent PHP requests |
| Nginx Workers | 4096/worker | HTTP connections |

#### File Handling
| Setting | Value | Purpose |
|---------|-------|---------|
| Upload Size | 2GB | Large audio files |
| Execution Time | 1 hour | Long operations |
| File Descriptors | 65535 | Concurrent access |

### 🔒 Security Configuration

#### SSH Hardening
- Password authentication disabled (SSH keys only)
- Root login disabled
- Empty passwords disabled

#### Firewall (UFW)
- Default deny incoming
- Allowed: SSH (22), HTTP (80), HTTPS (443)
- Loopback connections allowed

#### Fail2Ban Protection
| Jail | Protection | Threshold | Ban Duration |
|------|------------|-----------|--------------|
| **sshd** | SSH brute force | 3 attempts | 24 hours |
| **nginx-wordpress** | WordPress attacks | 5 attempts | 24 hours |
| **nginx-http-auth** | HTTP auth brute force | 3 attempts | 1 hour |
| **nginx-bad-request** | Malformed requests | 10 attempts | 1 hour |
| **nginx-botsearch** | Bot scanning | 1 attempt | 24 hours |
| **nginx-limit-req** | Rate limiting | 10 attempts | 10 minutes |
| **recidive** | Repeat offenders | 3 strikes | 7 days |

#### Additional Security
- chkrootkit and rkhunter installed
- Automatic security updates configured
- Log rotation configured
- Backup of original configs in `/root/security_backups_*`

## 🛠️ Usage

### Initial Setup

1. **Set up DNS**: Point your domain to the server IP
2. **Configure SSH keys**: Ensure you have SSH key access
3. **Run installation**: Use the quick install commands above
4. **Save credentials**: Check `/root/wordpress-credentials.txt`

### Post-Installation

1. Access WordPress admin at `https://your.domain.com/wp-admin`
2. Complete WooCommerce setup wizard
3. Configure payment methods
4. Add your music products
5. Customize the Bandfront theme

### Testing & Monitoring

Run the comprehensive system test:
```bash
sudo ./tests/compare_installation.sh
```

This validates:
- Service health (Nginx, MariaDB, PHP-FPM, Fail2ban)
- Configuration files
- SSL certificates
- WordPress functionality
- Security status
- System resources

### Security Management

```bash
# Check fail2ban status
sudo fail2ban-client status

# View security logs
sudo tail -f /var/log/fail2ban.log

# Check firewall status
sudo ufw status verbose

# Unban an IP
sudo fail2ban-client unban <ip_address>
```

## 📝 Important Notes

1. **SSH Keys Required**: The security script disables password authentication. Ensure you have SSH keys configured before running.

2. **Idempotent Scripts**: All scripts can be run multiple times safely.

3. **Credentials Storage**: WordPress and database credentials are saved to `/root/wordpress-credentials.txt`

4. **Theme Submodule**: The Bandfront theme is included as a Git submodule. The installer will initialize it automatically.

5. **Production Ready**: Includes comprehensive security hardening suitable for production use.

## 🚨 Troubleshooting

### Locked Out of SSH
```bash
# Restore SSH config from backup
sudo cp /root/security_backups_*/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Service Issues
```bash
# Check service status
systemctl status nginx php8.3-fpm mariadb fail2ban

# View error logs
journalctl -u nginx -n 50
journalctl -u php8.3-fpm -n 50
```

### WordPress Issues
- Check `/var/www/html/wp-content/debug.log`
- Verify file permissions: `chown -R www-data:www-data /var/www/html`
- Test database connection in wp-config.php

## 📄 License

There is no licence. GO! 

---

Built for musicians and labels who want a professional, secure, and performant online music store.