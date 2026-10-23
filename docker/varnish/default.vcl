# Entry point loaded by varnishd. Backend definition lives here; all caching
# logic lives in wordpress.vcl so it can be unit tested with varnishtest
# against a mock backend (see tests/).
vcl 4.1;

backend default {
    .host = "nginx";
    .port = "8080";
    .connect_timeout = 5s;
    .first_byte_timeout = 120s;
    .between_bytes_timeout = 30s;
    .probe = {
        .request =
            "GET /healthz HTTP/1.1"
            "Host: localhost"
            "Connection: close";
        .interval = 5s;
        .timeout = 2s;
        .window = 5;
        .threshold = 3;
    }
}

include "wordpress.vcl";
