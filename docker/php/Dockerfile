# syntax=docker/dockerfile:1

# PHP-FPM runtime for a Bedrock-based WordPress site.
# The same image is used by the `php` service (FPM) and the `wp-cli` service.

FROM mlocati/php-extension-installer:2.12 AS ext-installer

FROM php:8.3-fpm-trixie

# Run FPM workers with the host UID/GID so bind-mounted files stay writable
# (uploads, object-cache drop-in) without chmod 777. Defaults match www-data.
ARG HOST_UID=33
ARG HOST_GID=33

# wp-cli release pinned for reproducible builds.
ARG WP_CLI_VERSION=2.12.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=ext-installer /usr/bin/install-php-extensions /usr/local/bin/

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        less \
        libfcgi-bin \
        mariadb-client \
        msmtp \
    && rm -rf /var/lib/apt/lists/* \
    && install-php-extensions \
        bcmath \
        exif \
        gd \
        intl \
        mysqli \
        opcache \
        pdo_mysql \
        redis \
        zip \
    && curl -fsSL -o /usr/local/bin/wp \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    && chmod +x /usr/local/bin/wp \
    && groupmod -o -g "${HOST_GID}" www-data \
    && usermod -o -u "${HOST_UID}" -g "${HOST_GID}" www-data \
    && mkdir -p /var/www/html \
    && chown www-data:www-data /var/www/html

COPY conf.d/ /usr/local/etc/php/conf.d/
COPY php-fpm.d/zz-pool.conf /usr/local/etc/php-fpm.d/zz-pool.conf

# Runtime defaults, all overridable from compose.
ENV PHP_MEMORY_LIMIT=256M \
    PHP_UPLOAD_MAX_FILESIZE=64M \
    PHP_OPCACHE_REVALIDATE_FREQ=0 \
    SMTP_HOST=mailpit \
    SMTP_PORT=1025 \
    MAIL_FROM=wordpress@localhost \
    WP_CLI_CACHE_DIR=/tmp/wp-cli-cache

WORKDIR /var/www/html

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
    CMD ["sh", "-c", "SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 | grep -q pong"]
