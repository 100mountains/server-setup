# Security Hardening Script Updates

## fail2ban Optimizations Added

### Previous Configuration
- Basic SSH protection only
- 1-hour ban time
- 5 max retries
- No web server protection

### New Optimized Configuration

#### 1. Enhanced SSH Protection
```
[sshd]
enabled = true
bantime = 86400    # 24 hours (was 1 hour)
maxretry = 3       # 3 attempts (was 5)
findtime = 600     # 10 minutes detection window
```

#### 2. NEW: Web Server Protection
```
[nginx-http-auth]     # HTTP authentication failures
[nginx-bad-request]   # Malformed HTTP requests  
[nginx-botsearch]     # Bot/scanner detection
[nginx-limit-req]     # Rate limit violations
```

#### 3. NEW: Repeat Offender Protection
```
[recidive]
bantime = 604800      # 7 days for repeat offenders
findtime = 86400      # 24-hour detection window
maxretry = 3          # 3 strikes across any jail
```

### Configuration Files Modified
- `/etc/fail2ban/jail.local` - Main configuration
- `/etc/fail2ban/jail.d/sshd.local` - SSH-specific overrides
- `/etc/logrotate.d/security-hardening` - Added fail2ban log rotation

### Key Improvements
1. **6 active jails** instead of 1
2. **Comprehensive protection** for SSH and web services
3. **Longer ban times** for persistent attackers
4. **Better detection** of malicious behavior
5. **Automatic log management** for fail2ban logs

### Monitoring Commands Added to Script Output
- `sudo fail2ban-client status`
- `sudo fail2ban-client status <jail_name>`
- `sudo tail -f /var/log/fail2ban.log`
- `sudo fail2ban-client unban <ip_address>`

## Script Fixes
- Fixed incomplete fail2ban configuration block
- Added proper error handling for fail2ban startup
- Added comprehensive status reporting
- Improved backup procedures for fail2ban configs
- Added fail2ban log rotation

## Backup Enhancements
- All original fail2ban configs backed up to timestamped directory
- Easy restoration process documented in script output

## Usage
Run the updated script with:
```bash
sudo ./harden.sh
```

The script will now provide much more comprehensive security protection out of the box.
