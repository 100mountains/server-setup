# CONFIG DESCRIPTIONS

## MariaDB Configuration Settings

Current MariaDB configuration from `configs/mariadb/conf.d/60-optimizations.cnf`:

| Setting | Value |
|---------|-------|
| innodb_buffer_pool_size | 20G |
| innodb_file_per_table | ON |
| innodb_flush_method | O_DIRECT |
| innodb_flush_log_at_trx_commit | 2 |
| innodb_log_buffer_size | 64M |
| innodb_log_file_size | 512M |
| max_connections | 500 |
| thread_cache_size | 200 |
| thread_stack | 256K |
| query_cache_type | OFF |
| table_open_cache | 4000 |
| table_definition_cache | 2048 |
| max_allowed_packet | 256M |
| tmp_table_size | 256M |
| max_heap_table_size | 256M |
| sort_buffer_size | 4M |
| read_buffer_size | 3M |
| read_rnd_buffer_size | 4M |
| join_buffer_size | 4M |
| performance_schema | ON |

Configuration File Location: `configs/mariadb/conf.d/60-optimizations.cnf`






Wordpress Child Theme Installation

installs https://github.com/100mountains/bandfront


Wordpress Plugin Installation

install_plugin "WooCommerce" "woocommerce"
install_plugin "WooCommerce PayPal Payments" "woocommerce-paypal-payments"  
install_plugin "Theme My Login" "theme-my-login"
install_plugin "WP Armour - Honeypot Anti Spam" "wp-armour-extended"
install_plugin "WooCommerce Tax" "woocommerce-tax"
## WordPress Install Script Configuration Summary

The `install-wordpress.sh` script applies optimized configurations using templates from the `configs/` directory.

### WordPress Configuration
**Template:** `configs/wordpress/wp-config.template.php`

| Setting | Value | Purpose |
|---------|-------|---------|
| WP_MEMORY_LIMIT | 512M | Regular operation memory limit |
| WP_MAX_MEMORY_LIMIT | 8G | Admin/upload operations limit |
| WP_CACHE | true | Enable WordPress caching |
| WP_CRON_LOCK_TIMEOUT | 300 | Prevent cron conflicts |

### PHP Configuration  
**Template:** `configs/php/8.3/fpm/php.ini.template`

#### Core Settings
| Setting | Value | Purpose |
|---------|-------|---------|
| memory_limit | 8G | Maximum memory per script |
| max_execution_time | 3600 | 1 hour script timeout |
| max_input_time | 3600 | 1 hour input processing |
| max_input_vars | 10000 | Handle complex forms |
| upload_max_filesize | 2G | Large file uploads |
| post_max_size | 2G | Large POST data |
| max_file_uploads | 20 | Multiple file uploads |

#### Security Settings
| Setting | Value | Purpose |
|---------|-------|---------|
| expose_php | Off | Hide PHP version |
| allow_url_include | Off | Prevent remote code inclusion |
| display_errors | Off | Hide errors from users |
| short_open_tag | Off | Require full PHP tags |

#### Performance Settings
| Setting | Value | Purpose |
|---------|-------|---------|
| output_buffering | 4096 | Buffer output for efficiency |
| opcache.enable | 1 | Enable opcode caching |
| opcache.memory_consumption | 256 | 256MB for compiled code |
| opcache.max_accelerated_files | 10000 | Cache up to 10k files |
| opcache.validate_timestamps | 1 | Check for file changes |
| opcache.revalidate_freq | 2 | Check every 2 seconds |

#### Session Security
| Setting | Value | Purpose |
|---------|-------|---------|
| session.cookie_httponly | 1 | Prevent JS access to cookies |
| session.cookie_samesite | "Lax" | CSRF protection |
| session.use_strict_mode | 0 | Compatibility mode |

### PHP-FPM Pool Configuration
**Template:** `configs/php/8.3/fpm/pool.d/www.conf.template`

| Setting | Value | Purpose |
|---------|-------|---------|
| pm.max_children | 200 | Maximum concurrent processes |
| pm.start_servers | 40 | Processes at startup |
| pm.min_spare_servers | 20 | Minimum idle processes |
| pm.max_spare_servers | 80 | Maximum idle processes |
| pm.max_requests | 1000 | Requests before process restart |
| request_terminate_timeout | 3600 | 1 hour process timeout |
| rlimit_files | 65535 | File descriptor limit |

### Nginx Configuration
**Templates:** `configs/nginx/nginx.conf.template` & `configs/nginx/nginx-wordpress.template`

#### Main Configuration (nginx.conf)
| Setting | Value | Purpose |
|---------|-------|---------|
| worker_processes | auto | Use all CPU cores |
| worker_rlimit_nofile | 65535 | File descriptor limit |
| worker_connections | 4096 | Connections per worker |
| use | epoll | Efficient connection handling |
| multi_accept | on | Accept multiple connections |
| client_max_body_size | 2G | Large file uploads |
| proxy_read_timeout | 3600 | 1 hour proxy timeout |
| proxy_connect_timeout | 3600 | 1 hour proxy connect |
| proxy_send_timeout | 3600 | 1 hour proxy send |

#### WordPress Site Configuration
| Feature | Purpose |
|---------|---------|
| SSL/TLS | HTTPS with Let's Encrypt |
| PHP-FPM | FastCGI processing |
| Gzip compression | Faster page loads |
| Browser caching | Static file optimization |
| Security headers | XSS and clickjacking protection |

### Systemd Service Dependencies
**Templates:** `configs/systemd/overrides/`

| Service | Dependency | Purpose |
|---------|------------|---------|
| nginx | mariadb.service | Wait for database before web server |
| php8.3-fpm | mariadb.service | Wait for database before PHP |

**Benefits:**
- Prevents startup race conditions
- Ensures proper service order during boot
- Eliminates failed service starts requiring retries

### Database Optimization
**Template:** `configs/mariadb/conf.d/60-optimizations.cnf`
*(See MariaDB Configuration Settings above)*

## WordPress Plugin Installation

The `install-music-store-plugins.sh` script installs and configures essential plugins:

### E-commerce Platform
| Plugin | Slug | Purpose |
|--------|------|---------|
| WooCommerce | woocommerce | Main e-commerce platform |
| WooCommerce PayPal Payments | woocommerce-paypal-payments | PayPal payment processing |
| WooCommerce Tax | woocommerce-tax | Automated tax calculation |

### User Experience
| Plugin | Slug | Purpose |
|--------|------|---------|
| Theme My Login | theme-my-login | Custom login/registration pages |
| WP Armour - Honeypot Anti Spam | wp-armour-extended | Spam protection |

### WordPress Theme
| Component | Source | Purpose |
|-----------|--------|---------|
| Storefront | WordPress.org | Parent theme (via WP-CLI) |
| Bandfront | github.com/100mountains/bandfront | Custom child theme (Git submodule) |

**Configuration Applied:**
- WooCommerce optimized for digital downloads
- Guest checkout enabled
- Download permissions configured
- Secure upload directories created
- Tax calculation enabled
- PayPal payments ready for configuration


## Performance Optimizations Summary

### Memory Allocation (32GB Server)
| Component | Allocation | Purpose |
|-----------|------------|---------|
| MariaDB InnoDB Buffer | 20GB | Database caching |
| PHP Memory Limit | 8GB | Script execution |
| PHP OPcache | 256MB | Compiled code cache |
| System/OS | ~3GB | Operating system overhead |

### Concurrent Capacity
| Service | Capacity | Purpose |
|---------|----------|---------|
| MariaDB Connections | 500 | Simultaneous database connections |
| PHP-FPM Processes | 200 | Concurrent PHP requests |
| Nginx Worker Connections | 4096 | HTTP connections per worker |

### File Handling Optimization
| Setting | Value | Purpose |
|---------|-------|---------|
| Upload Size Limit | 2GB | Large audio file uploads |
| Execution Timeout | 1 hour | Long-running operations |
| File Descriptors | 65535 | High concurrent file access |
| Open File Cache | 4000 | Faster file access |

### Caching Strategy
| Type | Implementation | Benefit |
|------|----------------|---------|
| Opcode Cache | PHP OPcache | 2-5x faster PHP execution |
| Database Cache | InnoDB Buffer Pool | Faster query execution |
| Static Files | Nginx + Browser Cache | Faster asset delivery |
| Query Cache | Disabled | Better performance with InnoDB |

**Expected Performance:**
- **Page Load Speed:** 2-5x improvement from OPcache
- **Concurrent Users:** 200+ simultaneous users
- **File Uploads:** Up to 2GB audio files
- **Database Performance:** Optimized for read-heavy WordPress workloads
- **Boot Time:** ~6 seconds for web stack services

