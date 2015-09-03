vcl 4.0;

# This VCL explains load balancing, health checks and varnish grace mode;

# VMOD used to add load balancing capabilities, installed by default
import directors;

# VMOD used to add basic functionsi, installed by default
import std;

# VMOD used to extend functionality about cookies manipulation
# https://github.com/lkarsten/libvmod-cookie
import cookie;

# VMOD used to extends functionality about header manipulation
# https://github.com/varnish/libvmod-header/tree/4.0
import header;

# Healthy checks are used for load balancing and for serving graced objects purposes
# Backends starts marked as sick, and the probe defined below test if the server is available
# When varnish has no healthy backend available it attempts to use a graced copy of the cached object

probe www_healthy_probe {
    .url = "/"; # url to send a request and test the backend healthy
    .timeout = 1s; # timing out after 1 second
    .interval = 4s; # time between requests
    .window = 5; # If 3 out of the last 5 polls succeeded the backend is considered healthy, otherwise it will be marked as sick
    .threshold = 3;
}

# Assuming we have 2 backends

backend www1 {
    .host = "192.168.15.1";
    .port = "80";
    .connect_timeout = 1s; # Wait a maximum of 1s for backend connection (Apache, Nginx, etc...)
    .first_byte_timeout = 5s; # Wait a maximum of 5s for the first byte to come from your backend
    .between_bytes_timeout = 2s; # Wait a maximum of 2s between each bytes sent
    .max_connections = 300; # If the backend has not enough resources we can limit the simultaneous connections that can handle
    .probe = www_healthy_probe;

    # Otherwise as probe we can send a HEAD request for the same healthy check purposes

    # .probe = {
    #     .request = 
    #         "HEAD / HTTP/1.1"
    #         "Host: www.example.com"
    #         "Connection: close"; # We don't want a Keep Alive connection wasting memory resources just for health check requests
    # }

}

backend www2 {
    
    .host = "192.168.15.2";
    .port = "80";
    .connect_timeout = 1s
    .first_byte_timeout = 5s;
    .between_bytes_timeout = 2;
    .max_connections = 300;
    .probe = www_healthy_probe;
}

sub vcl_init {
    # Called when VCL is loaded, before any requests pass through it.
    # Typically used to initialize VMODs.

    # Example using load balancing using round-robin
    # round-robin director will skip unhealthy backends

    new round_robin_director = directors.round_robin();
    round_robin_director.add_backend(www1);
    round_robin_director.add_backend(www2);

    # Random director picks a backend randomly
    # Random director will not consider backends which are unhealthy part of the pool of available backends

    # new random_director = directors.random();
    # random_director.add_backend(wwW1, 20); # 2/3 request to www1
    # random_director.add_backend(wwW2, 10); # 1/3 request to www2

    # Hash directors uses as seed a hash key using the request url, client ip, session cookie or whatever we want to redirect to a specific backend
    # since de hash key is the same for a given input, hash directors select always the same backend for a given input
    # Hash directors are useful to load balance in front of other varnish caches, in this way cached objects are not duplicated across different cache servers

    # new hash_director = directors.hash();
    # hash_director.add_backend(www1, 1);
    # hash_director.add_backend(www2, 1);


}


sub vcl_recv {

    # Here we are telling to varnish where the request should go

    set req.backend_hint = round_robin_director.backend();  

    # In case of hash directors we can use as seed the client ip for example.

    # set req.backend_hint = hash_director.backend(client.ip);
    
    # Best way to load balance by session: most people use hash directors and as seed uses the session cookie, this works well except for one issue,
    # the session is created in the backend server, so the first time it does not exists and all the client requests are redirected to the same server.
    # To do this correctly and without the session id we need 2 additional VMODS that not are installed by default, cookie VMOD and header VMOD
    # https://www.varnish-software.com/blog/proper-sticky-session-load-balancing-varnish

    # If the cookie is already persisted (second connection for the same client), parse it
    # cookie.parse(req.http.cookie);

    # Generate a random number to attach to a custom cookie and use them to redirect to the same backend in future requests

    # if(cookie.get("sticky")) 
    # {
    #     set req.http.sticky = cookie.get("sticky");
    # } else 
    # {
    # We are generating a random number between 1 - 100 plus 3 digits following the decimal point
    #     set req.http.sticky = std.random(1, 100);
    # }
    # set req.backend_hint = hash_director.backend(req.http.sticky); # Hash uses the sticky param as seed

}

sub vcl_deliver {

    # We need to persist the cookie and use the header VMOD to append correctly the cookie in the response

    # if(req.http.sticky)
    # {
    #     header.append(resp.http.Set-Cookie,"sticky=trebol" + req.http.sticky + "; Expires=" + cookie.format_rfc1123(now, 60m));
    # }
}

sub vcl_hit {

    # HOW TO HANDLE GRACE MODE

    # The main goal of grace mode is to avoid request to pile up whenever a object has expired, as long as a request is waiting for new content, Varnish delivers graced objects instead of queuing incoming requests. 
    # Varnish reads the obj.grace variable which default value is 10 seconds, but you can change it by three means:
    # 1) Sending the http Cache-Control stale-while-revalidate field from the backend eg: [Cache-Control: s-maxage=60, stale-while-revalidate=30] and handle it properly in our VCL code
    # 2) Setting the beresp.grace in the VCL directly 
    # 3) Changing the default value with varnishadm

    # OPTION 1: Serve stale content only if the server is sick otherwise deliver the object if is not expired else miss & fetch

    # if(obj.ttl >= 0s) 
    # {
    #     return (deliver);
    # }

    # if(!std.healthy(req.backend_hint) && (obj.ttl + obj.grace > 0s)){
    # Here the asynchronous fetch call is performed
    #     return (deliver);
    # } else {
    #     return (fetch);
    # }

    # OPTION 2: Serve slight stale content if the server is healthy (The grace time accepted is harcoded) see example below, otherwise if the server is sick use full grace mode
    # We also need to define the default grace time in vcl_backend_response and if we want to see the debug headers in the response we must be sure to define them in vcl_backend_response too
    # Reference: https://www.varnish-software.com/blog/grace-varnish-4-stale-while-revalidate-semantics-varnish

    # if(std.healthy(req.backend_hint)) {
    # Here we hardcoded the time to serve old content (10s)
    #     if(obj.ttl + 10s > 0s) {
    #        set req.http.grace = "slight (grace)";
    #        return (deliver);
    #     } else {
    #         return (fetch);
    #     }
    # } else {
    # Here we are using full grace mode because the backend is sick
    #     if(obj.ttl + obj.grace > 0s) {
    #         set req.http.grace = "full grace";
    #         return (deliver);
    #     } else {
    #         return (fetch);
    #     }
    # }

}

sub vcl_backend_response {
    
    # Option 3: Use as grace time Cache-Control: stale-while-revalidate header value otherwise define a default value (2h in this example)
    # Also de vcl_hit subroutine is kept as the default defined by varnish

    set bereq.http.stale-while-revalidate = regsub(beresp.http.Cache-Control, ".*stale-while-revalidate\=([0-9]+).*", "\1");

    if(std.real(bereq.http.stale-while-revalidate, 0.0) > 0)
    {
        set beresp.grace = std.duration(bereq.http.stale-while-revalidate + "s", 10s);
    } else {
        set beresp.grace = 2h;
    }
    # If we are using OPTION 1 or OPTION 2 we must ensure to set a default grace time 
    # set beresp.grace 2h
}


