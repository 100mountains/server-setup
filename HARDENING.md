🔒 Fail2Ban Jail Configuration

Active Jails: 7

1. sshd
•  Purpose: SSH brute force protection
•  Max Retries: 3 attempts
•  Ban Time: 24 hours (86400s)
•  Find Time: 10 minutes (600s)
•  Ports: SSH
•  Log Source: /var/log/auth.log

2. nginx-wordpress
•  Purpose: WordPress-specific attack protection
•  Max Retries: 5 attempts
•  Ban Time: 24 hours (86400s)
•  Find Time: 10 minutes (600s)
•  Ports: HTTP, HTTPS
•  Protects Against: wp-login.php, wp-admin attacks
•  Log Source: /var/log/nginx/access.log

3. nginx-http-auth
•  Purpose: HTTP authentication brute force protection
•  Max Retries: 3 attempts
•  Ban Time: 1 hour (3600s)
•  Find Time: 10 minutes (600s)
•  Ports: HTTP, HTTPS
•  Log Source: /var/log/nginx/error.log

4. nginx-bad-request
•  Purpose: Malformed HTTP request protection
•  Max Retries: 10 attempts
•  Ban Time: 1 hour (3600s)
•  Find Time: 10 minutes (600s)
•  Ports: HTTP, HTTPS
•  Log Source: /var/log/nginx/access.log

5. nginx-botsearch
•  Purpose: Bot/crawler protection for non-existent URLs
•  Max Retries: 1 attempt (very strict)
•  Ban Time: 24 hours (86400s)
•  Find Time: 10 minutes (600s)
•  Ports: HTTP, HTTPS
•  Log Source: /var/log/nginx/access.log

6. nginx-limit-req
•  Purpose: Rate limiting protection
•  Max Retries: 10 attempts
•  Ban Time: 10 minutes (600s)
•  Find Time: 10 minutes (600s)
•  Ports: HTTP, HTTPS
•  Log Source: /var/log/nginx/error.log

7. recidive
•  Purpose: Long-term bans for repeat offenders across all jails
•  Max Retries: 3 strikes across any jail
•  Ban Time: 7 days (604800s)
•  Find Time: 24 hours (86400s)
•  Ports: All protocols
•  Log Source: /var/log/fail2ban.log

Default Settings
•  Default Ban Time: 24 hours (86400s)
•  Default Find Time: 10 minutes (600s)
•  Default Max Retries: 1 attempt (overridden per jail)
•  Ignored Networks: 127.0.0.1/8, ::1






