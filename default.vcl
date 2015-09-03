
vcl 4.0;

# VMOD_STD contains basic functions which are part and parcel of Varnish, but which for reasons of architecture fit better in a VMOD.
# Reference: https://www.varnish-cache.org/docs/trunk/reference/vmod_std.generated.html
import std;

# VMOD_HEADER contains basic function for header manipulation
# Reference: https://github.com/varnish/libvmod-header/tree/4.0
import header;

# We can include files, subroutines are concatenated if there are more than one of the same type
include "cache_invalidation.vcl";
include "custom_subroutines.vcl";

backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 1s; # Wait a maximum of 1s for backend connection (Apache, Nginx, etc...)
    .first_byte_timeout = 5s; # Wait a maximum of 5s for the first byte to come from your backend
    .between_bytes_timeout = 2s; # Wait a maximum of 2s between each bytes sent
    .max_connections = 300; # Max parallel connections to our backend
}


sub vcl_recv {
 
    # Varnish will ignore any request to this host creating a full duplex pipe forwarding the client request to the backend without looking at the content
    # Backend replies are forwarded back to the client without caching the content

    # if ( req.http.host ~ "(untouched.com)$" ) {
    #      return(pipe);
    # }

    # Remove all the incoming cookies
    # unset req.http.Cookie;

    # Setting custom headers that will catch the backend
    # set req.http.X-Host = req.http.host;
    # set req.http.X-Url = req.url;

    # URL MANIPULATION:

    # Remove www, doing this we remove duplication cache entries for users accesing through wwww
    # if(req.http.host ~ "^www\.")
    # {
    #     set req.http.host = regsub(req.http.host, "^www\.", "");
    # }

    # Rewrite url e.g subdomain.example.com/articles to example.com/subdomain/articles
    # if(req.http.host ~ "^subdomain\.")
    # {
    #     set req.http.host = regsub(req.http.host, "^subdomain\.", "");
    #     set req.url = regsub(req.url, "^", "/subdomain");
    # }

    # Preventing some urls to be cached
    #
    # if(req.url ~ "^/index\.html" || req.url ~ "^/$")
    # {
    #     return (pass);
    # }
    #

    # Normalize the header, remove the port (in case you're testing this on various TCP ports)
    # set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");

    # Normalize the query arguments by sorting 
    # set req.url = std.querysort(req.url);

    # Implementing websocket support (https://www.varnish-cache.org/docs/4.0/users-guide/vcl-example-websockets.html)
    # if (req.http.Upgrade ~ "(?i)websocket") {
    #     return (pipe);

    # Remove the Google Analytics added parameters, useless for our backend
      if (req.url ~ "(\?|&)(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=") {
        set req.url = regsuball(req.url, "&(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "");
        set req.url = regsuball(req.url, "\?(utm_source|utm_medium|utm_campaign|utm_content|gclid|cx|ie|cof|siteurl)=([A-z0-9_\-\.%25]+)", "?");
        set req.url = regsub(req.url, "\?&", "?");
        set req.url = regsub(req.url, "\?$", "");
      }

    # Remove anchor or hash references
      if(req.url ~ "\#"){
        set req.url = regsub(req.url, "\#.*$", "");
      }

    # Remove incomplete query string
      if(req.url ~ "\?$"){
        set req.url = regsub(req.url, "\?$", "");
      }

    # Remove Google Analytics Cookies, our server does not need it
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_ga=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_gat=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");

    # Remove DoubleClick offensive cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__gads=[^;]+(; )?", "");

    # Remove the Quant Capital cookies (added by some plugin, all __qca)
    set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");

    # Remove the AddThis cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__atuv.=[^;]+(; )?", "");

    # Remove a ";" prefix in the cookie if present
    set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");

    # Are there cookies left with only spaces or that are empty?
    if (req.http.cookie ~ "^\s*$") {
        unset req.http.cookie;
    }
 
    # Remove all cookies for static files
    # A valid discussion could be held on this line: do you really need to cache static files that don't cause load? Only if you have memory left.
    # Sure, there's disk I/O, but chances are your OS will already have these files in their buffers (thus memory).
    # Before you blindly enable this, have a read here: https://ma.ttias.be/stop-caching-static-files/

    # if (req.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|pdf|png|rtf|swf|txt|woff|xml)(\?.*)?$") {
    #     unset req.http.Cookie;
    #     return (hash);
    # }

    # Large static files are delivered directly to the end-user without
    # waiting for Varnish to fully read the file first.
    # Varnish 4 fully supports Streaming, so set do_stream in vcl_backend_response()
    if (req.url ~ "^[^?]*\.(mp[34]|rar|tar|tgz|gz|wav|zip|bz2|xz|7z|avi|mov|ogm|mpe?g|mk[av]|webm)(\?.*)?$") {
        unset req.http.Cookie;
        return (hash);
    }

    # Normalize Accept-Encoding client headers cause Apache by default uses Vary: Accept-Encoding, we don't need too much separate versions for every little variation of this header.
    # When a server issues a "Vary: Accept-Encoding" it tells Varnish that its needs to cache a separate version for every different Accept-Encoding that is coming from the clients.
    # eg: If one client sends "Accept-Encoding: gzip,deflate" and another client sends "Accept-Encoding: gzip, deflate" the whitespace in the last header causes varnish to create another copy when the content is still the same!
    # This is a good candidate to encapsulate in a user defined subroutine as device_detection (called below), but for illustration purposes is kept here

    if(req.http.Accept-Encoding) 
    {
       if(req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp[34]|ogg)$")
       {
        # No point compressing these extensions
        unset req.http.Accept-Encoding;
       } elsif(req.http.Accept-Encoding ~ "gzip") 
       {
        set req.http.Accept-Encoding = "gzip";
       } elsif(req.http.Accept-Encoding ~ "deflate") 
       {
        set req.http.Accept-Encoding = "deflate";
       } elsif(req.http.Accept-Encoding ~ "sdch") 
       {
        set req.http.Accept-Encoding = "sdch";
       } else 
       {
        # Unknown Algorithm
        unset req.http.Accept-Encoding;
       }
    }

    # Example calling user defined subroutines
    # Call to device detection custom subroutine, sets req.http.X-Device header = (mobile|desktop) accesible through our backend as HTTP_X_DEVICE
    call device_detection;

    # Enable cache by session using PHPSESSID, take care and use this method in order to isolate user specific content
    # Flow process step by step:
    # 1) Browser sends GET / without cookie, server returns Set-Cookie:PHPSESSID=randomid
    # 2) Varnish by default creates a hit_for_pass object cause the Set-Cookie header
    # 3) Browser sends GET / but now with the cookie identifying the session.
    # 4) We use the cookie session id as part of the varnish hash subroutine
    # 5) Server response is returned and cached because the session has already been created (Set-Cookie header does not exists).
    # 6) Now we are cached an object using as hash the (host + url + sessid)
    
    # Note : ensure to send the correct Cache-Control headers in the user pages

     # if(req.http.Cookie ~ "PHPSESSID=(?:.+)") 
     # {
     #    return (hash);
     # }

}


sub vcl_hash {

    # USE CASE: We want to cache information according to the cookies using 1 page as example (The page content varies according to the cookies values):
    # GOAL: We want to cache the content of the page in a separate way, that is 1 cached object by cookie variation, and we want to invalidate this variations with a single request to this page without complex bans expresions
    # 1) If we are using only [hash_data(req.http.cookie)], We are storing 1 object per cookie variation but when we try to purge the page, nothing is purged cause hash_data(req.http.cookie) is creating a unique identifier by variation.
    # 2) If we use [hash_data(req.http.cookie)] plus sending Vary: Cookie, the problem still the same as in the previous point. hash_data(req.http.cookie) creates a unique identifier by variation.
    # 3) If we only use Vary: Cookie in our backend, We are storing 1 object per cookie variation but this time all works as expected because Varnish stores the objects sharing the same hash value so we can purge as a unit.

    # SESSION LEVEL CACHING
    # If you choose this technique, take care and not set high ttl values, cause the eviction by unique identifiers are really hard to mantain
    # "PHPSESSID" is the default string to identify the session, if you are using another name, just replace it in the RegExp
    # Look at the following link, it is old but the concept is still useful https://www.varnish-cache.org/trac/wiki/VCLExampleCachingLoggedInUsers

    # PHPSESSID EXISTS ?
    # if(req.http.Cookie ~ "PHPSESSID=(?:.+)") 
    # {
         # EXTRACT THE SESSION ID TO BE USED AS PART OF THE HASH PROCESS
    #    set req.http.X-Varnish-SESS-ID = regsub(req.http.Cookie, "^(?:.*)?PHPSESSID\=([^;]+)\;?(?:.*)$", "\1");
    #    hash_data(req.http.X-Varnish-SESS-ID);
    # }
}

# At this point, it is our last chance to make some decision (set|unset|mod) about some header that the backend should see.

sub vcl_backend_fetch {

    # if(bereq.url ~ "^/index\.html" || bereq.url ~ "^/$")
    # {
    #      Or you can perform a hit-for-pass here or in vcl_backend_response
    #      Remember that for ordinary cache misses, Varnish will queue all clients requesting the same cache object and
    #      send a single request to the backend. This is usually quickest, let the backend work on a single request instead of 
    #      swamping it with n requests at the same time, but what about if Varnish sees the fetched object can't be catched by Set-Cookie header
    #      or by s-maxage=0 etc. Each of these clients (queued) are performing the same slow one-at-the-time backend request!!
    #      so to prevent this behaviour in advance you can set a hit-for-pass object and ensure the specified url below is not producing clients request serialization, as any other object you must set ttl

    #      set bereq.ttl = 120s;
    #      set bereq.uncacheable = true;
    #      return (fetch);
    # }

    # SESSION LEVEL CACHING
    # We don't need to send this header to the server, it has been used just for hashing purposes
    unset bereq.http.X-Varnish-SESS-ID;
}


sub vcl_hit {

    # Custom Headers for debug purposes
    set req.http.X-Cache-TTL-Remaining = obj.ttl;
    set req.http.X-Cache-Age = obj.keep - obj.ttl;
    set req.http.X-Cache-Grace = obj.grace;
}

# When we are at this point, we can modify the behaviour sended from the backend, eg. setting a custom cache policy, deleting or setting response headers...
# The default behaviour is create a hit-for-pass object to avoid request serialization when the backend response contains cookies
# or any cache directive indicating that the response should not be stored. eg. [Cache-Control:private|no-cache|no-store] or [Vary: *]

sub vcl_backend_response {

    # Setting custom cache ttl when the backend is not sending s-maxage cache-control directive
    # plus clean outcoming cookies [THIS EXAMPLE IS JUST FOR ILUSTRATION]
    # Important: Any response from the server returning Set-Cookie header is ignored by the cache system as well as private|no-cache|no-store, more information see varnish_default_behaviour.vcl

    # if(beresp.http.cache-control !~ "s-maxage")
    # {
    #     if(bereq.url ~ "\.(jpg|jpeg)(\?|$)")
    #     {
    #         beresp.ttl = 60s;
    #         unset beresp.http.Set-Cookie;
    #     }
    #     if(bereq.url ~ "\.html(\?|$)")
    #     {
    #         beresp.ttl = 30s;
    #         unset beresp.http.Set-Cookie;

    #     }
    # } else {
    #     if(beresp.ttl > 0)
    #     {
    #       unset beresp.http.Set-Cookie;
    #     }
    # }

    # Important Note: It is necessary to be able not only to clean the request, also clean the response!

    # Enable cache for all static files
    # Same argument from above, static files does not produce CPU load in our server, just disk I/O which is usually avoided by disk buffering
    # if (bereq.url ~ "^[^?]*\.(bmp|bz2|css|doc|eot|flv|gif|gz|ico|jpeg|jpg|js|less|mp[34]|pdf|png|rar|rtf|swf|tar|tgz|txt|wav|woff|xml|zip|webm)(\?.*)?$") {
    #     unset beresp.http.set-cookie;
    # }

    # Large static files are delivered directly to the end-user without
    # waiting for Varnish to fully read the file first.
    # Varnish 4 fully supports Streaming, so use streaming here to avoid locking.

    # if (bereq.url ~ "^[^?]*\.(mp[34]|rar|tar|tgz|gz|wav|zip|bz2|xz|7z|avi|mov|ogm|mpe?g|mk[av]|webm)(\?.*)?$") {
    #     unset beresp.http.set-cookie;
    #     set beresp.do_stream = true;  # Check memory usage it'll grow in fetch_chunksize blocks (128k by default) if the backend doesn't send a Content-Length header, so only enable it for big objects
    #     set beresp.do_gzip = false;   # Don't try to compress it for storage
    # }

    # If we are performing a redirection 301 / 302 from the backend and our web server and varnish instances are in the same node, apache mod_rewrite could append it's port
    # typically varnish :80 apache/nginx/lighthttp :8080, so the redirect can then often redirect the end-user to a URL on :8080, where it should be :80.

    if(beresp.status == 301 || beresp.status == 302) {
        set beresp.http.Location = regsub(beresp.http.Location, ":[0-9]+", "");
    }

    # The example below is explained in detail in load_balancing.vcl as part of one of the strategies that we can take to handle Varnish Grace Mode

    set bereq.http.stale-while-revalidate = regsub(beresp.http.Cache-Control, ".*stale-while-revalidate\=([0-9]+).*", "\1");

    if(std.real(bereq.http.stale-while-revalidate, 0.0) > 0)
    {
        set beresp.grace = std.duration(bereq.http.stale-while-revalidate + "s", 10s);
    } else {
        set beresp.grace = 2h;
    }

    # This ensures that all cached pages are stripped of Set-Cookie
    # This is considered a must

    # if(beresp.ttl > 0s)
    # {
    #     unset beresp.http.Set-Cookie;
    # }

    # Default grace period after the object ttl is elapsed only used in combination with OPTION 1 AND OPTION 2 of cache_invalidation.vcl file
    # Allows stale content (6 hours) if the backends goes down
    # set beresp.grace = 6h;
}

sub vcl_deliver {

    # At this point this is our last change to set or unset the response headers before deliver it

    if (obj.hits > 0) 
    {
        set resp.http.X-Cache = "HIT";
    } else 
    {
        set resp.http.X-Cache = "MISS";
    }

    set resp.http.X-Hits = obj.hits;

    # Remove www of our host in the backend response
    set resp.http.X-Host = regsub(req.http.host, "^www\.", "");

    # Remove PHP , Apache and Varnish versions
    unset resp.http.x-powered-by;
    unset resp.http.Server;
    unset resp.http.X-Varnish;
    unset resp.http.Via;

    # Here we are ensuring to add this headers in the response (defined in the hit subroutine) for debug purposes
    set resp.http.X-Cache-TTL-Remaining = req.http.X-Cache-TTL-Remaining;
    set resp.http.X-Cache-Age = req.http.X-Cache-Age;
    set resp.http.X-Cache-Grace = req.http.X-Cache-Grace;


}
