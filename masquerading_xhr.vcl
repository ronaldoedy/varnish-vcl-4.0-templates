
vcl 4.0;

    # Varnish can be used for masquerading other HTTP sites behind your own [or not :)] and thereby working around XHR cross-domain limitations without JSONP Implementations.

    # First of all add a backend where you need to establish XHR communication.

    # backend wwwXHR {
    #     .host = "www.example.com";
    #     .port = "80";
    # }

    # Then in sub vcl_recv subroutine map your custom url to the external backend

    # sub vcl_recv {
    #     if(req.url ~ "^/masquerade")
    #     {
              # Now we set the real host header to the external backend host and forward the request to the correct backend
    #         set req.backend_hint = wwwXHR;
    #         set req.http.host = "www.example.com";
    #         set req.url = regsub(req.url, "^/masquerade", "");
    #         return (hash);
    #     } else {
              # If the req.url does not contains our url wildcard, forward the traffic to our normal backend or cluster of backend
    #         # set req.backend_hint = www;
              # If we are using a round-robin fashion... (See details in load_balancing.vcl)
              # set req.backend_hint = round_robin_director.backend();
    #     }
    # }
