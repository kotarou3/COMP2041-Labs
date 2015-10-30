import cgi
from cStringIO import StringIO
import hashlib
import os
import shutil
import sys
import tempfile
import unicodedata
import urlparse

from bitter.db import File, db
from bitter.reqres import Request, Response
from bitter.router import Router

class BitterFieldStorage(cgi.FieldStorage):
    def make_file(self, binary = True):
        file = tempfile.NamedTemporaryFile(dir = os.path.join(os.path.dirname(os.path.realpath(__file__)), "uploads"))

        # Build a SHA-256 hash of the file
        setattr(file, "hash", hashlib.sha256())
        def write(str):
            file.hash.update(str)
            return write.orig(str)
        write.orig = file.write
        file.write = write

        return file

    # XXX: Hack to have the data always write to a file when a filename is included
    def read_lines(self):
        if self.filename:
            self.file = self.make_file()
            self._FieldStorage__file = None
        else:
            self.file = self._FieldStorage__file = StringIO()

        if self.outerboundary:
            self.read_lines_to_outerboundary()
        else:
            self.read_lines_to_eof()

def utf8Decode(str):
    return unicodedata.normalize("NFC", str.decode("utf8"))

def getValueOrFile(field):
    if field.file:
        if field.done == -1:
            field.file.close()
            return None

        if hasattr(field.file, "hash"):
            hash = field.file.hash.hexdigest()
            newPath = os.path.join(os.path.dirname(os.path.realpath(field.file.name)), hash)
            if not os.path.exists(newPath):
                shutil.move(field.file.name, newPath)
                field.file.delete = False
            field.file.close()

            return File(hash = hash, name = utf8Decode(field.filename or hash))

    return utf8Decode(field.value)

# CSE pipes stderr to the client as well, which we don't want, so we pipe it to a log instead
logfile = open(os.path.join(os.path.dirname(os.path.realpath(__file__)), "stderr.log"), "w")
os.dup2(logfile.fileno(), sys.stderr.fileno())

res = Response(headers = {"Content-Type": "text/plain"})
try:
    # Extract the file extension if any
    pathParts = utf8Decode(os.environ.get("PATH_INFO", "/")).rsplit(".", 1)
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
        fieldStorage = BitterFieldStorage(keep_blank_values = True)
        for key in fieldStorage.keys():
            if isinstance(fieldStorage[key], list):
                body[key] = map(lambda value: getValueOrFile(value), fieldStorage[key])
            else:
                body[key] = getValueOrFile(fieldStorage[key])

    req = Request(
        remoteAddress = os.environ["REMOTE_ADDR"],
        method = os.environ["REQUEST_METHOD"],
        baseUri = os.environ.get("SCRIPT_URI", "").decode("utf8")[0:-len(os.environ.get("PATH_INFO", "").decode("utf8"))],
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

    if isinstance(res.body, file):
        res.headers["Content-Length"] = os.fstat(res.body.fileno()).st_size - res.body.tell()
    else:
        res.body = res.body.encode("utf8")
        res.headers["Content-Length"] = len(res.body)

    if res.headers.get("Location", "").startswith("/"):
        res.headers["Location"] = req.baseUri + res.headers["Location"]

    print "Status: {0}\r".format(res.status)
    for key, value in res.headers.iteritems():
        print "{0}: {1}\r".format(key, value)
    if res.cookies:
        print res.cookies.output() + "\r"
    print "\r"

    if isinstance(res.body, file):
        shutil.copyfileobj(res.body, sys.stdout)
    else:
        sys.stdout.write(res.body)
