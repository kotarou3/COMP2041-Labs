import os

from bitter.db import File
from bitter.router import defaultRoutes

class UploadController(object):
    @classmethod
    def outputFile(cls, req, res):
        try:
            res.body = open(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "uploads", req.params["id"].encode("utf8")), "rb")
        except IOError:
            res.status = 404
            return

        file = File(hash = req.params["id"], name = req.params["name"])
        res.headers["Content-Type"] = file.mime

defaultRoutes[("GET", "^/upload/(?P<id>[a-zA-Z0-9]{64})(?:/(?P<name>[^/\x00]*))?$")] = UploadController.outputFile
