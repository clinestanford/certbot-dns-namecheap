#!/bin/bash

# Default values
DEFAULT_EMAIL="scline@jobxcel.ai"
EMAIL="$DEFAULT_EMAIL"
SUBDOMAIN=""
DB=""

# Help message
function show_help {
  echo "Usage: $0 -s <subdomain> [-d <database>] [-e <email>]"
  echo
  echo "Options:"
  echo "  -s, --subdomain   The subdomain for which to create the Nginx configuration and SSL certificate."
  echo "  -d, --db          The database name associated with the subdomain (default: same as subdomain)."
  echo "  -e, --email       The email address to use for SSL certificate registration (default: $DEFAULT_EMAIL)."
  echo
  echo "Example:"
  echo "  $0 -s example -d example_db -e admin@example.com"
}

# Parse flags
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -s|--subdomain) SUBDOMAIN="$2"; shift ;;
    -d|--db) DB="$2"; shift ;;
    -e|--email) EMAIL="$2"; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown parameter: $1"; show_help; exit 1 ;;
  esac
  shift
done

# Check if required parameters are provided
if [[ -z "$SUBDOMAIN" ]]; then
  echo "Error: Subdomain is required."
  show_help
  exit 1
fi

# Set default database name if not provided
DB=${DB:-$SUBDOMAIN}

# Path for configuration files
NGINX_CONF_PATH="/etc/nginx/sites-enabled"
TEMPLATE_DIR="/opt/odoo/certbot-dnc-namecheap/config_files"
NGINX_TEMPLATE="$(TEMPLATE_DIR)/nginx_template.conf"
NGINX_REDIRECT_TEMPLATE="$(TEMPLATE_DIR)/nginx_redirect_template.conf"
LOG_DIR="/var/cert_logging"

# Create logging directory if it doesn't exist
sudo mkdir -p $LOG_DIR
sudo chown $USER:$USER $LOG_DIR

# Generate or renew SSL certificates
echo "Generating SSL certificate for $SUBDOMAIN"
sudo docker run --rm \
  -v $(pwd)/certs:/etc/letsencrypt \
  -v $(pwd)/logs:/var/log/letsencrypt \
  -v $(pwd)/namecheap.ini:/namecheap.ini \
  certbot-dns-namecheap certonly \
  -a dns-namecheap \
  --dns-namecheap-credentials /namecheap.ini \
  --email "$EMAIL" \
  -d $SUBDOMAIN \
  -d www.$SUBDOMAIN \
  --agree-tos \
  --non-interactive \
  --quiet \
  --renew-hook "sudo systemctl reload nginx" \
  >> $LOG_DIR/${SUBDOMAIN}_cert.log 2>&1

echo "SSL certificate generation completed. Logs can be found in $LOG_DIR/${SUBDOMAIN}_cert.log"

# Check if the necessary templates exist
if [[ ! -f $NGINX_TEMPLATE || ! -f $NGINX_REDIRECT_TEMPLATE ]]; then
  echo "Error: Required Nginx template files are missing in ./config_files."
  exit 1
fi

# Create the Nginx config for the subdomain
echo "Creating Nginx config for $SUBDOMAIN"
sed "s/<SUBDOMAIN>/$SUBDOMAIN/g" $NGINX_TEMPLATE | sed "s/<DB>/$DB/g" | sudo tee $NGINX_CONF_PATH/${SUBDOMAIN}.conf >/dev/null

# Create the Nginx redirect config for www subdomain
echo "Creating Nginx config for www.$SUBDOMAIN"
sed "s/<SUBDOMAIN>/$SUBDOMAIN/g" $NGINX_REDIRECT_TEMPLATE | sudo tee $NGINX_CONF_PATH/www.${SUBDOMAIN}.conf >/dev/null

# Reload Nginx to apply changes
sudo systemctl restart nginx
echo "Nginx configuration updated and server restarted."
