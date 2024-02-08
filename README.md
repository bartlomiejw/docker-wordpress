<a href="https://www.docker.com/">
<img alt="Docker" src="https://www.docker.com/wp-content/uploads/2023/08/logo-guide-logos-1.svg" height="100">
</a>
<a href="https://pl.wordpress.org/">
<img alt="Wordpress" src="https://s.w.org/style/images/about/standard.png" height="100" style="border-radius: 5px;">
</a>

# DOCKER for Wordpress

[![License](https://img.shields.io/badge/License-MIT-blue)](#license)

## Introduction

This project simplifies the deployment and management of WordPress instances using Docker containers, integrating the
Bedrock boilerplate for WordPress development. It combines technologies such as NGINX, Varnish, PHP-FPM, MySQL, and
others to create an adaptable and efficient hosting environment for WordPress sites. Additionally, it includes MailHog
for email testing and debugging purposes, enhancing the development and testing capabilities of WordPress applications.

## Services Used

- [NGINX](https://www.nginx.com/): Web server and reverse proxy.
- [VARNISH](https://varnish-cache.org/): Web application accelerator and caching HTTP reverse proxy.
- [PHP-FPM](https://www.php.net/manual/en/install.fpm.php): PHP FastCGI Process Manager for executing PHP code.
- [MYSQL](https://www.mysql.com/): Relational database management system.
- [BEDROCK](https://roots.io/bedrock/): Modern WordPress stack with better folder structure and Composer-based
  dependency management.
- [PHPMYADMIN](https://www.phpmyadmin.net/): Web-based MySQL administration tool.
- [MAILHOG](https://github.com/mailhog/MailHog): Email testing tool for developers.

## Getting Started

1. Set up the environment variables in the `.env` file to configure your project.
2. Run `make generte-certs` to create SSL certificate.
3. Run `make install-bedrock` to install Bedrock boilerplate in `/src`
4. Run `make generate-bedrock-env` to set up the environment variables in the `.env` file in `/src` to configure your
   project.
5. Use `DOMAIN=example.com make up` to start the containers.
6. Execute `DOMAIN=example.com make restart` to restart the containers.
7. Use `DOMAIN=example.com make destroy` with caution as it will remove all containers and volumes associated with
   the project.

## Build and Configuration

1. Run `DOMAIN=example.com make up` to start the containers.
2. Use `DOMAIN=example.com make down` to stop the containers.
3. Execute `DOMAIN=example.com make restart` to restart the containers.
4. Use `DOMAIN=example.com make destroy` with caution as it will remove all containers and volumes associated with
   the project.

## Shell Access

Gain shell access to specific containers:

- `DOMAIN=example.com make docker-exec-nginx`
- `DOMAIN=example.com make docker-exec-php`
- `DOMAIN=example.com make docker-exec-mysql`
- `DOMAIN=example.com make docker-exec-varnish`

## Nginx-Proxy

The project supports multiple WordPress instances with different domain names using `nginx-proxy` as an HTTP proxy and
DNS server.

Commands (Linux only):

- `make nginx-proxy-start`
- `make nginx-proxy-stop`
- `make nginx-proxy-restart`

## SSL Configuration

`nginx-proxy` handles SSL termination in front of Varnish. Place your `.crt` and `.key` files in `./certs/{DOMAIN}.crt`
and `./certs/{DOMAIN}.key`, respectively. Remember to restart `nginx-proxy` after any cert modifications.

## Varnish Setup

Varnish caches HTTP responses and improves server performance. It's placed in front of NGINX and caches HTTP responses.

Ensure WordPress permalinks are enabled and configure the W3 Total Cache plugin to enable reverse proxy caching via
Varnish.

## Backups

Commands for creating and recovering backups:

- `DOMAIN=example.com make backup`
- `DOMAIN=example.com make backup-code`
- `DOMAIN=example.com make backup-mysql`
- `DOMAIN=example.com make recover`
- `DOMAIN=example.com make recover-code`
- `DOMAIN=example.com make recover-mysql`
