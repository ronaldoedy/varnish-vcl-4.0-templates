
vcl 4.0;

# ESI (Edge side includes) is a small markup language for dynamic web page assembly at the reverse proxy level.
# Varnish analyzes the HTML code, parses ESI specific markup and assembles the final result before flushing it to the client
# Used to establish different ttl and make clear distinction between static and dynamic content

# Varnish supports only 3 ESI tags:

# <esi:include src="/url"/> : Calls the page defined in the src attribute and replaces the esi tag with the content of src, either finding it already in cache or getting it from the server and inserting it to the cache
# <esi:remove>CONTENT</esi:remove> The content inside the remove esi tag is rendered [only] if the resource containing this tag does not have ESI support
# <!--esi CONTENT -->  : The content inside the commented esi tag is rendered [only] if the resource containing this tag has ESI support otherwise remains as commented tag

# Tip: If we are using "purge" as a invalidation cache method, we have to purge each piece individually, another reason to use bans ;)


sub vcl_backend_response {

    # Enabling ESI support is pretty easy, we can do it manually :

    # if(bereq.url ~ "^/articles") 
    # {
    #     set beresp.do_esi = true;
    #     set beresp.ttl = 1h;
    # } 
    # elsif(bereq.url ~ "^/top10articles") 
    # {
    #     set beresp.ttl = 10m;    
    # }

    # Or we can send a special header from the page containing the esi tags like Cache-Control but ESI-oriented (http://www.w3.org/TR/edge-arch)
    # from our backend -> Surrogate-Control: max-age=3600, content="ESI/1.0" and for each esi piece we can send another ttl using Cache-Control(s-maxage)
    # take care setting max-age on the child pieces cause the parent's max age can't be ovewritten so it is useless

    # if(beresp.http.Surrogate-Control ~ "ESI/1.0")
    # {
          # The client does not need to know about this header and our cache policy
    #     unset beresp.http.Surrogate-Control
    #     set beresp.do_esi = true;
    # }

}


