# syntax=docker/dockerfile:1

ARG PHP_VERSION=8.5.12

# ---------- runtime ----------
FROM php:${PHP_VERSION}-apache AS runtime

ARG PHP_VERSION

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# PHP extensions (mlocati installer handles Debian deps, e.g. libgd/jpeg/webp/freetype)
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
        intl \
        pdo_mysql \
        mysqli \
        opcache \
        zip \
        gd \
        bcmath \
        exif \
    && docker-php-source delete

# System tools apps build against
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Apache modules
RUN a2enmod rewrite headers expires deflate remoteip

# Apache config; document root applied at runtime from $APACHE_DOCUMENT_ROOT
# (official-image pattern: sed on 000-default.conf + apache2.conf <Directory>)
COPY docker/apache/zz-remoteip.conf /etc/apache2/conf-available/zz-remoteip.conf
COPY docker/apache/zz-security.conf /etc/apache2/conf-available/zz-security.conf
RUN a2enconf zz-remoteip zz-security

# PHP config: production base + overridable defaults
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/php/zz-app.ini /usr/local/etc/php/conf.d/zz-app.ini

# Entrypoint
COPY docker/entrypoint.sh /usr/local/bin/themusicdev-entrypoint
RUN chmod +x /usr/local/bin/themusicdev-entrypoint

ENV APACHE_DOCUMENT_ROOT=/var/www/html/webroot \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data

WORKDIR /var/www/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -fsS -o /dev/null http://127.0.0.1/ || exit 1

LABEL org.opencontainers.image.title="themusicdev/php-apache" \
      org.opencontainers.image.description="Framework-agnostic Apache + PHP ${PHP_VERSION} runtime for CakePHP and Slim apps" \
      org.opencontainers.image.source="https://github.com/TheMusicDev/php-apache" \
      org.opencontainers.image.url="https://github.com/TheMusicDev/php-apache" \
      org.opencontainers.image.version="${PHP_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.base.name="docker.io/library/php:${PHP_VERSION}-apache"

ENTRYPOINT ["/usr/local/bin/themusicdev-entrypoint"]
CMD ["apache2-foreground"]

# ---------- dev ----------
FROM runtime AS dev

ARG PHP_VERSION

RUN install-php-extensions xdebug \
    && docker-php-source delete \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        default-mysql-client \
        gnupg \
        ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

# Xdebug off by default; enable per-container with XDEBUG_MODE (e.g. debug)
RUN { echo "zend_extension=xdebug.so"; \
      echo "xdebug.mode=off"; \
    } > /usr/local/etc/php/conf.d/zz-xdebug.ini

ENV XDEBUG_MODE=off