# themusicdev/php-apache

Reusable, framework-agnostic **Apache + PHP 8.5 runtime** image for Debian (`php:8.5-apache`), built for apps deployed through [Dokploy](https://dokploy.com) with Traefik in front. Works for **CakePHP 5** (default document root `webroot`) and **Slim** apps (`public`). Runtime only — no framework code inside; add your app with a tiny child Dockerfile or a Dokploy build.

Replaces `angelxmoreno/php7-fpm-alpine`, `angelxmoreno/php7-fpm-alpine-dev`, and `angelxmoreno/php-fpm-alpine` (PHP 7 / FPM / Alpine) with Apache / Debian / PHP 8.5 mod_php. See `DEPRECATION-NOTICE.md`.

## Tags

| Tag | Meaning |
|---|---|
| `8.5.12` | runtime, pinned patch (default for deployments) |
| `8.5` | runtime, minor channel |
| `8.5.12-dev` / `8.5-dev` | dev: Xdebug + Node LTS + mysql client |

No `latest` tag, on purpose. Registries: `themusicdev/php-apache` (Docker Hub) and `ghcr.io/themusicdev/php-apache`. Platforms: `linux/amd64`, `linux/arm64`.

## Env vars

| Var | Default | Notes |
|---|---|---|
| `APACHE_DOCUMENT_ROOT` | `/var/www/html/webroot` | CakePHP default; Slim apps set `/var/www/html/public` (mounted app root, so mount at `/var/www/html`) |

Build-time tunables (pass on a child Dockerfile or Dokploy build args): none for PHP ini — override `docker/php/zz-app.ini` values from a child Dockerfile (`COPY my.ini /usr/local/etc/php/conf.d/zz-my.ini`) or at runtime with `PHP_VALUE`/`PHP_ADMIN_VALUE` env (e.g. `PHP_VALUE="memory_limit=512M"`).

Runtime behavior built in:

- **Traefik awareness**: `mod_remoteip` trusts `X-Forwarded-For` from private ranges (10/8, 172.16/12, 192.168/16); `X-Forwarded-Proto: https` sets `HTTPS=on` for PHP, so CakePHP/Slim see the right scheme without extra middleware.
- Apache: rewrite, headers, expires, deflate, remoteip enabled; `AllowOverride All` on the document root; `ServerTokens Prod`, `ServerSignature Off`.
- php.ini: production base + `zz-app.ini` (memory 256M, uploads 20M, opcache on, UTC timezone).
- Entrypoint makes `tmp/` and `logs/` www-data-writable if the app ships them, then `exec`s Apache in the foreground.

## Included PHP extensions

`intl pdo_mysql mysqli opcache zip gd (jpeg+webp+freetype) bcmath exif imagick soap xsl bz2 ftp pdo_pgsql pgsql gmp`, plus bundled-in-base `mbstring simplexml pdo_sqlite lexbor uri sodium`.

> **Reconciled with serverbyt (2026-11-03):** the runtime carries the *essentials* tier of the serverbyt module list. Deliberately absent from serverbyt parity: `pdo_dblib PDO_ODBC odbc PDO_Firebird sqlsrv snmp imap dba shmop pcntl tidy pspell OAuth xmlrpc gettext ldap calendar`, and the proprietary loaders `ionCube Loader` / `SourceGuardian` (only needed to run encoded/obfuscated third-party PHP; automated CI builds are not a safe home for them). If an app needs one, install it in the child Dockerfile via `install-php-extensions <name>`.

## Child Dockerfile examples

CakePHP 5 app:

```dockerfile
FROM themusicdev/php-apache:8.5.12
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --optimize-autoloader
COPY . .
RUN composer dump-autoload -o
```

Slim app:

```dockerfile
FROM themusicdev/php-apache:8.5.12
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --optimize-autoloader
COPY . .
```

## dev image

`8.5.12-dev` adds on top of runtime:

- **Xdebug**, disabled by default. Enable per app with `XDEBUG_MODE` env (`debug`, `develop`, `coverage`, …). No need to rebuild.
- **Node.js LTS** with npm
- `default-mysql-client`
- `php.ini-development` as the active ini

## Local testing

Requires Docker (OrbStack on macOS works).

```sh
docker compose up -d          # image + MariaDB, app at http://localhost:8080
docker compose down
tests/smoke-test.sh           # builds runtime+dev, runs full assertion suite
```

What the smoke tests verify: both targets build; `php -v` reports 8.5.x; required extensions load; Apache rewrite sends pretty URLs to `index.php`; `APACHE_DOCUMENT_ROOT` switch serves from `public/`; `X-Forwarded-For` rewrites `REMOTE_ADDR` and `X-Forwarded-Proto: https` yields `HTTPS=on`; `tmp/` is www-data-writable; Xdebug absent in runtime, present (and off by default) in dev; HEALTHCHECK defined.

## CI

`.github/workflows/build.yml`: build+smoke test on PRs; on pushes to `main`, tags `v*`, and a weekly scheduled rebuild — multi-arch (amd64+arm64) pushed to Docker Hub and GHCR. Requires repo secrets `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`.

## Deployment (Dokploy)

Point Dokploy at a child repo (or build target `runtime` with `APACHE_DOCUMENT_ROOT` arg), Traefik handles TLS and forwards `X-Forwarded-*`; the image is already configured to trust it.