vcl 4.0;

# Varnish allows you create user defined subroutines that can be used inside varnish subroutines
# This custom subroutine is called with the call keyword [call device_detection;]
# Note: User defined subroutines access the variables in the context in which they have been called, eg: if the subroutine has been called from vcl_recv, 
# you can only access to req.* while if you are calling it from vcl_backend_response the variables that can be accessed are bereq.* & beresp.*

# This subroutine sets a request header named X-Device with "desktop" or "mobile" value in order to normalize it depending of the User-Agent sending the request.

sub device_detection { 
          set req.http.X-Device = "desktop";

              if (req.http.User-Agent ~ "iP(hone|od)" || 
                  req.http.User-Agent ~ "Android" || 
                  req.http.User-Agent ~ "Symbian" || 
                  req.http.User-Agent ~ "^BlackBerry" || 
                  req.http.User-Agent ~ "^SonyEricsson" || 
                  req.http.User-Agent ~ "^Nokia" || 
                  req.http.User-Agent ~ "^SAMSUNG" || 
                  req.http.User-Agent ~ "^LG" || 
                  req.http.User-Agent ~ "webOS") { 

                        set req.http.X-Device = "mobile"; 
                } 
                if (req.http.User-Agent ~ "^PalmSource") {
                        set req.http.X-Device = "mobile";
                }
                if (req.http.User-Agent ~ "Build/FROYO" || req.http.User-Agent ~ "XOOM" ) {
                        set req.http.X-Device = "desktop";
                }

                # If the device detection header a.k.a X-Device header is setted as mobile
                # we can throw for example a custom error and perform some action in the catching vcl_synth subroutine

                # if (req.http.X-Device == "mobile") {
                # Here we are delegating the next step to the vcl_synth defined below (Note the status code passed as first argument to synth, and how we can catch the code in the vcl_synth)
                #         return (synth(750, "http://m.mywebsite.cctld"));
                # }

                # Or just leave this code without throwing a synth call for Vary: User-agent capabilities in our backend
}


sub vcl_synth {

    if(resp.status == 750) {

    # Redirection
        # set resp.http.location = resp.reason;
        # set resp.status = 301;
        # return (deliver);

        # Otherwise we can create a custom html page with a confirmation prompt...

        set resp.http.Content-Type = "text/html; charset=utf-8";
        set resp.status = 200;

        # Remember that synthetic is a function not a subroutine

        synthetic({"
        <html>
            <head>
                <script type="text/javascript">
                    function device_redirection()
                    {
                        var answer = confirm("Do you want to be redirected to our mobile web page?");
                        answer ? window.location = "} + resp.reason + {" : window.location = "http://mywebsite.cctld";
                    }
                </script>
            </head>
            <body onload="device_redirection()"></body>
        </html>"});
        return (deliver);

    }    
}
