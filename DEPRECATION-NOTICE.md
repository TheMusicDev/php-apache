# DEPRECATION-NOTICE

Ready-to-paste deprecation notice for the three old images. Use the long text for Docker Hub / GitHub READMEs, the short line for the Docker Hub short description and GitHub repo description.

---

## Long version (Docker Hub overview / GitHub README)

> **DEPRECATED: This image is no longer maintained.** It has been replaced by **`themusicdev/php-apache`** — a fresh, Apache + PHP 8.5 runtime image ([Docker Hub](https://hub.docker.com/r/themusicdev/php-apache) · [GitHub](https://github.com/TheMusicDev/php-apache) · GHCR: `ghcr.io/themusicdev/php-apache`).
>
> This old image was PHP 7.x on FPM + Alpine. The replacement runs **PHP 8.5 on Apache (Debian)** with `mod_php`, is multi-arch (amd64/arm64), and ships the extensions needed for CakePHP 5 and Slim apps, with Composer included and Apache document-root configuration via an env var (`APACHE_DOCUMENT_ROOT`).
>
> **Migration notes:**
> - If you used the image behind a reverse proxy exposing FPM on port 9000, the new image serves HTTP directly on port 80 — point your proxy at 80, or keep FPM mode by using an `php:8.5-fpm`-based child image if you truly need FPM.
> - Alpine-to-Debian means glibc instead of musl: rebuild native dependencies (composer packages with platform-specific binaries, Node native modules) against Debian.
> - PHP 7.4 → 8.5 is a large language jump; fix deprecations in your app before switching (see [php.net migration guides](https://www.php.net/manual/en/migration85.php)).
> - Document root is now driven by `APACHE_DOCUMENT_ROOT` (defaults to `/var/www/html/webroot` for CakePHP; set `/var/www/html/public` for Slim).
>
> No further updates — including security updates — will be published to this repository.

## Short line (Docker Hub short description / GitHub description)

`DEPRECATED: use themusicdev/php-apache (Apache + PHP 8.5, Debian)`

## Applies to

- `angelxmoreno/php7-fpm-alpine` — https://hub.docker.com/r/angelxmoreno/php7-fpm-alpine
- `angelxmoreno/php7-fpm-alpine-dev` — https://hub.docker.com/r/angelxmoreno/php7-fpm-alpine-dev
- `angelxmoreno/php-fpm-alpine` — https://hub.docker.com/r/angelxmoreno/php-fpm-alpine