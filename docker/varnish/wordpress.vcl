# WordPress caching policy.
#
# Request flow: Traefik (TLS) -> Varnish -> nginx -> PHP-FPM.
#
# - Anonymous traffic is cached; cookies that do not affect the response are
#   dropped so pages become cacheable.
# - Logged-in users, admin, login, previews, carts and checkouts bypass the cache.
# - Static assets are cached for a week regardless of cookies.
# - PURGE/BAN are accepted only from the internal network and never from
#   requests that came in through Traefik (which always sets X-Real-Ip).
#
# The tracking-parameter and cookie clean-up rules are adapted from
# https://gist.github.com/fevangelou/84d2ce05896cab5f730a

import std;

acl purge {
    "localhost";
    "10.0.0.0"/8;
    "172.16.0.0"/12;
    "192.168.0.0"/16;
}

sub vcl_recv {
    # Internal headers must never be supplied by clients.
    unset req.http.X-Cache;

    # httpoxy
    unset req.http.Proxy;

    if (req.url == "/varnish-health") {
        return (synth(200, "OK"));
    }

    # --- Invalidation -----------------------------------------------------
    if (req.method == "PURGE" || req.method == "BAN") {
        if (!client.ip ~ purge || req.http.X-Real-Ip) {
            return (synth(405, "Not allowed"));
        }
        # BAN, or PURGE with "X-Purge-Method: regex" (Proxy Cache Purge
        # plugin), invalidates every URL matching a regex on this host.
        if (req.method == "BAN" || req.http.X-Purge-Method ~ "(?i)regex") {
            ban("obj.http.x-host == " + req.http.host + " && obj.http.x-url ~ " + req.url);
            return (synth(200, "Banned"));
        }
        return (purge);
    }

    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # --- URL normalisation ------------------------------------------------
    # Drop analytics/marketing parameters that never change the response.
    if (req.url ~ "(\?|&)(utm_[a-z]+|gclid|fbclid|msclkid|mc_[a-z]+|_ga|_gl)=") {
        set req.url = regsuball(req.url, "(utm_[a-z]+|gclid|fbclid|msclkid|mc_[a-z]+|_ga|_gl)=[^&]*&?", "");
        set req.url = regsub(req.url, "[?&]+$", "");
    }
    set req.url = regsub(req.url, "#.*$", "");
    set req.url = std.querysort(req.url);

    # --- Static assets: always cacheable ----------------------------------
    if (req.url ~ "^[^?]*\.(avif|bmp|css|eot|gif|ico|jpe?g|js|map|mjs|mp3|mp4|otf|pdf|png|svg|ttf|webm|webp|woff2?|zip)(\?.*)?$") {
        unset req.http.Cookie;
        return (hash);
    }

    # --- Never cache ------------------------------------------------------
    if (req.http.Authorization) {
        return (pass);
    }

    if (req.url ~ "^/(wp/)?(wp-admin|wp-login\.php|wp-cron\.php|xmlrpc\.php)" ||
        req.url ~ "(\?|&)(preview|add-to-cart|wc-api|wc-ajax)=" ||
        req.url ~ "^/(cart|checkout|my-account)(/|$)") {
        return (pass);
    }

    # Cookies that mark a personalised session.
    if (req.http.Cookie ~ "(wordpress_logged_in_|wordpress_sec_|wp-postpass_|comment_author_|woocommerce_items_in_cart|woocommerce_cart_hash|wp_woocommerce_session_)") {
        return (pass);
    }

    # Everything else is anonymous: cookies (analytics, consent, test cookie)
    # do not change the response.
    unset req.http.Cookie;
    return (hash);
}

sub vcl_hash {
    # Keep HTTP and HTTPS variants apart.
    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }
}

sub vcl_backend_response {
    # Stored on the object for lurker-friendly bans; stripped in vcl_deliver.
    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;

    # Do not cache server errors; keep serving stale content during grace.
    if (beresp.status >= 500) {
        if (bereq.is_bgfetch) {
            return (abandon);
        }
        set beresp.ttl = 10s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    if (bereq.url ~ "^[^?]*\.(avif|bmp|css|eot|gif|ico|jpe?g|js|map|mjs|mp3|mp4|otf|pdf|png|svg|ttf|webm|webp|woff2?|zip)(\?.*)?$") {
        unset beresp.http.Set-Cookie;
        set beresp.ttl = 7d;
    } else if (!beresp.http.Cache-Control && !beresp.http.Expires) {
        # WordPress sends no caching headers for public pages.
        set beresp.ttl = 10m;
    }

    # Serve stale objects for up to 6h while revalidating or if nginx is down.
    set beresp.grace = 6h;

    # Fall through to the built-in logic, which marks responses with
    # Set-Cookie, "private"/"no-cache" or "Vary: *" as uncacheable.
}

sub vcl_deliver {
    if (obj.uncacheable) {
        set resp.http.X-Cache = "PASS";
    } else if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    unset resp.http.x-url;
    unset resp.http.x-host;
    unset resp.http.X-Powered-By;
    unset resp.http.Via;
}
