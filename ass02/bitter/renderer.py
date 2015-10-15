from datetime import datetime
import json
import os
import sys

# Make datetime and normal classes JSON serialisable
def _jsonEncoderDefault(self, obj):
    try:
        return _jsonEncoderDefault.orig(obj)
    except TypeError as e:
        if isinstance(obj, datetime):
            return (obj - datetime.utcfromtimestamp(0)).total_seconds()
        elif hasattr(obj, "__dict__"):
            return vars(obj)
        else:
            raise e
_jsonEncoderDefault.orig = json.JSONEncoder().default
json.JSONEncoder.default = _jsonEncoderDefault

def render(req, res, view, model = None):
    if req.fileext == "json":
        if model:
            res.headers["Content-Type"] = "application/json"
            res.body = json.dumps(model)
        elif 200 <= res.status <= 299:
            res.status = 204
    else:
        try:
            viewHandle = open(os.path.join(os.path.dirname(os.path.realpath(__file__)), "views", view), "r")
        except IOError:
            viewHandle = open(os.path.join(os.path.dirname(os.path.realpath(__file__)), view), "r")

        res.headers["Content-Type"] = "application/xhtml+xml"
        with viewHandle:
            if view.rsplit(".", 1)[-1] == "bepy":
                res.body = runBepy(viewHandle.read())
            else:
                res.body = viewHandle.read()

def runBepy(bepy):
    res.body = bepy # TODO
