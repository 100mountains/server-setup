# Server Setup Scripts

This repository contains a server setup script for a media serving WordPress instance, optimized for high-performance servers with 32GB RAM.

## WordPress Installation

- `install-wordpress.sh`: Automates the process of installing and configuring WordPress on a server.
- `nginx-wordpress.template`: Nginx configuration template with optimized settings for media serving and WooCommerce.
- `wp-config.template.php`: WordPress configuration template with optimized memory and performance settings.

## Important: Environment Variables

**You must create a `.env` file before running the installation script, or it will not work properly!**

Create a `.env` file in the same directory as the installation script with the following variables:

```
DOMAIN_NAME=yourdomain.com
EMAIL=your-email@example.com
```

Replace:
- `yourdomain.com` with your actual domain name for the WordPress site
- `your-email@example.com` with a valid email address (used for SSL certificate registration)

## Directory Structure

```
.
├── install-wordpress.sh
├── nginx-wordpress.template
├── wp-config.template.php
├── mariadb/
│   └── conf.d/
│       └── 60-optimizations.cnf    # MariaDB optimizations for 32GB RAM
└── php/
    └── 8.3/
        └── fpm/
            ├── php.ini.template    # PHP core settings
            └── pool.d/
                └── www.conf.template  # PHP-FPM process management
```

## Usage

1. Create the `.env` file as described above
2. Navigate to the appropriate directory 
3. Run the script with appropriate permissions:

```bash
sudo ./install-wordpress.sh
```

## Features

### WordPress Optimizations
- PHP Memory: 8GB
- WP Memory: 512MB (regular), 8GB (admin/upload operations)
- Max upload size: 2GB
- Extended execution time: 1 hour
- Post revisions limited to 20
- System cron instead of WP-Cron
- UTF8MB4 character set support

### MariaDB Optimizations (32GB RAM)
- InnoDB Buffer Pool: 20GB
- Query cache disabled for better performance
- Optimized InnoDB settings
- Enhanced connection handling
- Improved table caching
- Performance schema enabled

### PHP-FPM Optimizations
- Dynamic process manager
- 200 max child processes
- 8GB memory limit per process
- Extended resource limits
- Optimized opcache settings
- Enhanced error logging

### Nginx Configuration Features
- Protected audio file serving in wp-content/uploads
- Secure WooCommerce file delivery using X-Accel-Redirect
- Optimized audio streaming with proper headers and range requests
- Extended timeouts for large file uploads
- Static file caching
- Basic security measures

### WooCommerce Integration
- Protected download mechanism for digital products
- Secured upload directory access
- Internal redirect system for protected files
- Attachment handling for downloads
- 2MB chunk size for improved download handling

## Performance Notes
- Optimized for servers with 32GB RAM
- MariaDB uses 60% of available RAM for buffer pool
- PHP-FPM configured for high-concurrency
- Disabled WordPress cron in favor of system cron
- Query cache disabled for better performance
- OpCache enabled and optimized

## License

whadeva
