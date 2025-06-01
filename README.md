# Server Setup Scripts

This repository contains a server setup script for a media serving WordPress instance.

## WordPress Installation

- `install-wordpress.sh`: Automates the process of installing and configuring WordPress on a server.

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

## Usage

1. Create the `.env` file as described above
2. Navigate to the appropriate directory 
3. Run the script with appropriate permissions:

```bash
sudo ./install-wordpress.sh
```

## Features

The WordPress installation is optimized for audio/media sites with:
- PHP Memory: 4GB
- WP Memory: 2GB (max 4GB)
- MariaDB Buffer: 8GB
- Max upload size: 2GB
- Extended execution time: 1 hour

## License

whadeva
