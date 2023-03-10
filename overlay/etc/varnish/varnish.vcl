vcl 4.1;

import dynamic;
import re;

backend something None;

acl ipv4_only { "0.0.0.0"/0; }

sub vcl_init {
    new resolver = dynamic.resolver(
        set_from_os=TRUE,
        parallel=32
    );
    resolver.set_resolution_type(STUB);
    resolver.clear_namespaces();
    resolver.add_namespace(DNS);
    resolver.set_namespaces();
    new http = dynamic.director(
        # Commented out for now, see if things work on v4 only without it
        whitelist = ipv4_only,	# remove if IPv6 is ok
        resolver = resolver.use(),
        ttl_from = dns,
    );
    new proxyurl = re.regex("^http://([^:/]+(?::(\d+))?)(/.*)");
    new hostport = re.regex("^(?:[^:]+)(?::(\d+))?");
}

sub vcl_recv {
    /* If Host is missing, someone's messing around */
    if (!req.http.Host) {
        return (synth(400, "Host header is required"));
    }
    call set_cache_domain;
    /* Since the Varnish config and DNS config are generated from the same
     * source, we would like to error out if there is no domain, but for now
     * stay compatible with the nginx cache */
    #if (!req.http.x-cache-domain) {
    #    return (synth(400, "Unknown cache domain"));
    #}
    if (req.method == "CONNECT") {
        return (synth(400, "CONNECT is not supported"));
    }
    if (proxyurl.match(req.url)) {
        set req.url = proxyurl.backref(3, "");
        set req.http.Host = proxyurl.backref(1, "");
        set req.backend_hint =
            http.backend(port=proxyurl.backref(2, "80"));
    } else if (hostport.match(req.http.Host)) {
        set req.backend_hint =
            http.backend(port=hostport.backref(1, "80"));
    } else {
        return (synth(400, "URL/Host format unknown"));
    }
}

sub vcl_hash {
    /* for added cache-efficiency, we don't hash by hostname, but by cache domain. */
    hash_data(req.url);
    if (req.http.x-cache-domain) {
        hash_data(req.http.x-cache-domain);
    } else {
        hash_data(req.http.host);
    }
    return (lookup);
}

sub vcl_backend_fetch {
    /* In loving memory of Zoey "Crabbey" Lough. May she live on in the code */
    set bereq.http.X-Clacks-Overhead = "GNU Terry Pratchett, GNU Zoey -Crabbey- Lough";
    /* This is just a variable for us, don't send it to the backend */
    unset bereq.http.x-cache-domain;
}

sub vcl_deliver {
    /* In loving memory of Zoey "Crabbey" Lough. May she live on in the code */
    set resp.http.X-Clacks-Overhead = "GNU Terry Pratchett, GNU Zoey -Crabbey- Lough";
    set resp.http.connection = "close";
}
