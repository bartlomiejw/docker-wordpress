<?php

/**
 * Adapts a fresh Bedrock project to this stack. Idempotent.
 *
 * - Configuration comes from container environment variables (root .env ->
 *   compose -> PHP-FPM), so Bedrock's own .env is removed to keep a single
 *   source of truth.
 * - Redis object cache constants are added to config/application.php,
 *   because the object-cache drop-in reads constants, not environment
 *   variables, and is loaded before any plugin.
 *
 * Usage: php configure.php /path/to/bedrock
 */

declare(strict_types=1);

$root = rtrim($argv[1] ?? getcwd(), '/');
$config = $root . '/config/application.php';
$marker = '/** docker-wordpress: redis object cache */';
$anchor = 'Config::apply();';

if (!is_file($config)) {
    fwrite(STDERR, "Bedrock config not found: {$config}\n");
    exit(1);
}

$source = file_get_contents($config);

if (strpos($source, $marker) === false) {
    if (substr_count($source, $anchor) !== 1) {
        fwrite(STDERR, "Could not find a single '{$anchor}' in {$config}; patch it manually.\n");
        exit(1);
    }

    $block = <<<PHP
{$marker}
Config::define('WP_REDIS_HOST', env('WP_REDIS_HOST') ?: 'redis');
Config::define('WP_REDIS_PORT', (int) (env('WP_REDIS_PORT') ?: 6379));
Config::define('WP_REDIS_PREFIX', env('WP_REDIS_PREFIX') ?: 'wp:');
Config::define('WP_REDIS_TIMEOUT', 1);
Config::define('WP_REDIS_READ_TIMEOUT', 1);

{$anchor}
PHP;

    file_put_contents($config, str_replace($anchor, $block, $source));
    echo "Patched {$config}\n";
}

$dotenv = $root . '/.env';
if (is_file($dotenv)) {
    unlink($dotenv);
    echo "Removed {$dotenv} (configuration comes from the root .env)\n";
}
