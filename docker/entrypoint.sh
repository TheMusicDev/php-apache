#!/bin/sh
set -e

: "${APACHE_DOCUMENT_ROOT:=/var/www/html/webroot}"
export APACHE_DOCUMENT_ROOT

# Document root: apply official-image sed pattern to vhost + apache2.conf,
# then append an explicit <Directory> block with AllowOverride All so .htaccess
# works even when the docroot lives outside /var/www.
sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" \
        -e "s!DocumentRoot[[:space:]].+!DocumentRoot ${APACHE_DOCUMENT_ROOT}!g" \
    /etc/apache2/sites-available/*.conf /etc/apache2/apache2.conf

cat > /etc/apache2/conf-available/zz-docroot.conf <<EOF
<Directory ${APACHE_DOCUMENT_ROOT}>
    Options FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF
a2enconf zz-docroot >/dev/null

# App housekeeping: if the app dir ships tmp/ or logs/, make them www-data-writable
APP_DIR="$(dirname "${APACHE_DOCUMENT_ROOT}")"
if [ -d "$APP_DIR" ]; then
    for d in tmp logs; do
        [ -e "$APP_DIR/$d" ] && chown -R www-data:www-data "$APP_DIR/$d"
    done
fi

exec docker-php-entrypoint "$@"