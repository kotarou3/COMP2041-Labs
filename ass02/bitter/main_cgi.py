import cgi
import os
import sys
import unicodedata
import urlparse

from bitter.db import db
from bitter.reqres import Request, Response
from bitter.router import Router

def utf8Decode(str):
    return unicodedata.normalize("NFC", str.decode("utf8"))

res = Response(headers = {"Content-Type": "text/plain"})
try:
    # Extract the file extension if any
    pathParts = os.environ.get("PATH_INFO", "/").rsplit(".", 1)
    path = pathParts[0]
    fileext = ""
    if len(pathParts) > 1:
        fileext = pathParts[1]

    # Parse the HTTP headers
    headers = {}
    for key, value in os.environ.iteritems():
        if key.startswith("HTTP_"):
            key = "-".join(map(str.capitalize, key[5:].split("_")))
            headers[key] = value

    # Parse and remove the query string first, since FieldStorage doesn't distinguish it from the body
    params = urlparse.parse_qs(os.environ["QUERY_STRING"], keep_blank_values = True)
    for key, value in params.iteritems():
        if len(value) == 1:
            params[key] = utf8Decode(value[0])
    del os.environ["QUERY_STRING"]

    # Parse the body and converting it to a dict
    body = {}
    if os.environ["REQUEST_METHOD"] in ("POST", "PATCH"):
        fieldStorage = cgi.FieldStorage(keep_blank_values = True)
        for key in fieldStorage.keys():
            if isinstance(fieldStorage[key], list):
                body[key] = map(lambda value: utf8Decode(value.value), fieldStorage[key])
            else:
                body[key] = utf8Decode(fieldStorage[key].value)

    req = Request(
        remoteAddress = os.environ["REMOTE_ADDR"],
        method = os.environ["REQUEST_METHOD"],
        path = path,
        fileext = fileext,
        headers = headers,
        params = params,
        body = body
    )
    res.headers["X-Request"] = repr(vars(req))

    with db:
        Router().route(req, res)
except:
    import cgitb
    res.status = 500
    res.headers["Content-Type"] = "text/html"
    res.body = cgitb.html(sys.exc_info())
finally:
    db.close()

    res.headers["Content-Length"] = len(res.body)

    print "Status: {0}\r".format(res.status)
    for key, value in res.headers.iteritems():
        print "{0}: {1}\r".format(key, value)
    if res.cookies:
        print res.cookies.output() + "\r"
    print "\r"

    sys.stdout.write(res.body)
