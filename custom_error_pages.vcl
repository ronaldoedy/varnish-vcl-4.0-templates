vcl 4.0;

sub vcl_backend_error {

    # This subroutine is called when something wrong happens in the backend side, eg: 503 Service Unavailable
    # Remember that errors caught in vcl_backend_error can be cached (see details: cache_invalidation.vcl line 60) while the custom errors passed to vcl_synth not.
    # Example customizing 503 error (Service Unavailable)

    if(beresp.status == 503) {
        # For a full custom example: see custom_subroutines.vcl  
        set beresp.status = 200; # a.k.a OK 
        synthetic({"More friendly error page goes here..."});
    }
    return (deliver);
}

sub vcl_synth {
    # You can catch custom errors for multiple purposes,
    # for example you can perform a redirection
    if(resp.status == 610) { 
        # req.http.location can be set in vcl_recv like http://redirection.com + req.url and
        # thrown by return (synth(610, "Permanently moved")); 
        # or by the synth message itself : return(synth(610, "http://redirection.com")) and accessed from resp.reason
        # Note the error code catch it and the error passed as argument to synth
        set resp.http.location = req.http.location;
        set resp.status = 301;
        return (deliver);
    }
}
