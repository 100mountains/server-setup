# 🔒 Security Hardening Configuration

The `harden.sh` script applies comprehensive security hardening using templates from the `configs/` directory.

## 🛡️ SSH Security Configuration

### SSH Hardening Applied
| Setting | Value | Purpose |
|---------|-------|---------|
| PasswordAuthentication | **no** | SSH keys only, no password brute force |
| PermitRootLogin | **no** | Disable direct root access |
| PermitEmptyPasswords | **no** | Prevent empty password logins |

**Configuration:** Applied directly to `/etc/ssh/sshd_config` with automatic backup and validation.

## 🔥 UFW Firewall Configuration

### Firewall Rules
| Rule | Protocol | Port | Purpose |
|------|----------|------|---------|
| **Default Deny** | All | Incoming | Block all unwanted traffic |
| **Default Allow** | All | Outgoing | Allow server responses |
| **OpenSSH** | TCP | 22 | SSH access |
| **HTTP** | TCP | 80 | Web traffic |
| **HTTPS** | TCP | 443 | Secure web traffic |
| **Loopback** | All | lo | Local system communication |

**Status:** UFW enabled with verbose logging.

## 🚫 Fail2Ban Intrusion Prevention

**Template:** `configs/fail2ban/jail.local`

### Active Jails (7 Total)

#### 🔐 SSH Protection
| Jail | Purpose | Max Retries | Ban Time | Find Time |
|------|---------|-------------|----------|-----------|
| **sshd** | SSH brute force protection | 3 attempts | 24 hours | 10 minutes |

**Logs Monitored:** `/var/log/auth.log`  
**Ports Protected:** SSH

#### 🌐 Web Server Protection
| Jail | Purpose | Max Retries | Ban Time | Find Time |
|------|---------|-------------|----------|-----------|
| **nginx-wordpress** | WordPress attack protection | 5 attempts | 24 hours | 10 minutes |
| **nginx-http-auth** | HTTP auth brute force | 3 attempts | 1 hour | 10 minutes |
| **nginx-bad-request** | Malformed HTTP requests | 10 attempts | 1 hour | 10 minutes |
| **nginx-botsearch** | Bot/crawler protection | 1 attempt | 24 hours | 10 minutes |
| **nginx-limit-req** | Rate limiting protection | 10 attempts | 10 minutes | 10 minutes |

**Custom Filters:**
- `configs/fail2ban/nginx-wordpress.conf` - WordPress-specific attack patterns
- `configs/fail2ban/nginx-botsearch.conf` - Bot detection patterns

**Logs Monitored:** `/var/log/nginx/access.log`, `/var/log/nginx/error.log`  
**Ports Protected:** HTTP (80), HTTPS (443)

#### 🔄 Repeat Offender Protection
| Jail | Purpose | Max Retries | Ban Time | Find Time |
|------|---------|-------------|----------|-----------|
| **recidive** | Long-term bans for repeat offenders | 3 strikes | 7 days | 24 hours |

**Cross-Jail Detection:** Monitors all jails for repeat violations  
**Log Source:** `/var/log/fail2ban.log`

### Default Jail Settings
| Setting | Value | Purpose |
|---------|-------|---------|
| Default Ban Time | 24 hours | Standard punishment duration |
| Default Find Time | 10 minutes | Attack detection window |
| Default Max Retries | 1 attempt | Conservative threshold |
| Ignored Networks | 127.0.0.1/8, ::1 | Localhost protection |

## 📋 Log Rotation Configuration

**Template:** `configs/logrotate/security-hardening`

### Managed Log Files
| Log Type | Rotation | Retention | Compression |
|----------|----------|-----------|-------------|
| Fail2Ban logs | Daily | 30 days | gzip |
| UFW logs | Weekly | 4 weeks | gzip |
| Auth logs | Daily | 30 days | gzip |
| Security scan logs | Monthly | 12 months | gzip |

**Features:**
- Automatic compression after rotation
- Email notifications on errors
- Missing log file handling
- Proper permissions preservation

## 🔍 Security Monitoring Tools

### Installed Security Utilities
| Tool | Purpose | Usage |
|------|---------|-------|
| **chkrootkit** | Rootkit detection | Manual scans: `sudo chkrootkit` |
| **rkhunter** | System integrity checking | Manual scans: `sudo rkhunter --check` |

## 🎯 Security Monitoring Commands

### Fail2Ban Management
```bash
# Check overall status
sudo fail2ban-client status

# Check specific jail
sudo fail2ban-client status sshd
sudo fail2ban-client status nginx-wordpress

# View live logs
sudo tail -f /var/log/fail2ban.log

# Unban IP address
sudo fail2ban-client unban <ip_address>

# Reload configuration
sudo fail2ban-client reload
```

### UFW Firewall Management
```bash
# Check firewall status
sudo ufw status verbose

# View numbered rules
sudo ufw status numbered

# Add temporary rule
sudo ufw allow from <ip_address>

# Remove rule
sudo ufw delete <rule_number>
```

### System Security Checks
```bash
# Check SSH configuration
sudo sshd -t

# View authentication logs
sudo tail -f /var/log/auth.log

# Check firewall logs
sudo tail -f /var/log/ufw.log

# Run rootkit scan
sudo chkrootkit

# Run system integrity check
sudo rkhunter --check --skip-keypress
```

## 🚨 Attack Protection Summary

### WordPress-Specific Protection
- **wp-login.php** brute force attacks (5 attempts → 24h ban)
- **wp-admin** unauthorized access attempts
- **XML-RPC** abuse prevention
- **Plugin vulnerability** exploitation attempts

### General Web Protection
- **HTTP authentication** brute force (3 attempts → 1h ban)
- **Rate limiting** violations (10 attempts → 10min ban)
- **Malformed requests** (10 attempts → 1h ban)
- **Bot scanning** attempts (1 attempt → 24h ban)

### Progressive Punishment System
1. **First offense:** Standard jail-specific ban time
2. **Repeat offense (same jail):** Escalated ban duration
3. **Cross-jail violations:** 7-day recidive ban
4. **Persistent attacks:** Manual intervention required

## 🔐 Backup & Recovery

### Automatic Backups Created
| Component | Backup Location | Purpose |
|-----------|----------------|---------|
| SSH Configuration | `/root/security_backups_*/sshd_config.backup` | Emergency SSH restoration |
| Fail2Ban Configuration | `/root/security_backups_*/fail2ban_backup/` | Configuration rollback |
| Original System Files | `/root/security_backups_*/*` | System recovery |

### Emergency Recovery
```bash
# Restore SSH configuration if locked out
sudo cp /root/security_backups_*/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd

# Restore fail2ban configuration
sudo cp -r /root/security_backups_*/fail2ban_backup/* /etc/fail2ban/
sudo systemctl restart fail2ban
```

**Security hardening provides multi-layered protection optimized for WordPress/WooCommerce hosting with automated threat response and comprehensive logging.**

