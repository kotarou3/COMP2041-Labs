from datetime import datetime
import json
import os
import re

from bitter.db import Coordinates, File
from bitter.model import Model

# Make datetime and normal classes JSON serialisable
def _jsonEncoderDefault(self, obj):
    try:
        return _jsonEncoderDefault.orig(obj)
    except TypeError as e:
        if isinstance(obj, datetime):
            # .total_seconds() only available with v2.7
            td = obj - datetime.utcfromtimestamp(0)
            return (td.microseconds + (td.seconds + td.days * 86400) * 10**6) / 10.0**6
        elif isinstance(obj, set):
            return list(obj)
        elif isinstance(obj, Model):
            properties = vars(obj)
            return dict(((key, properties[key]) for key in obj.publicProperties.intersection(properties)))
        elif isinstance(obj, Coordinates) or isinstance(obj, File):
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
        res.headers["Content-Type"] = "application/xhtml+xml"
        res.body = renderView(view, {
            "req": req,
            "res": res,
            "model": model
        })

def renderView(view, params = {}):
    try:
        viewHandle = open(os.path.join(os.path.dirname(os.path.realpath(__file__)), "views", view), "r")
    except IOError:
        viewHandle = open(os.path.join(os.path.dirname(os.path.realpath(__file__)), view), "r")

    with viewHandle:
        if view.rsplit(".", 1)[-1] == "bepy":
            return runBepy(viewHandle.read(), params)
        else:
            return viewHandle.read()

def escape(s):
    from xml.sax.saxutils import escape
    return escape(s, {"'": "&apos;", '"': "&quot;"})

def runBepy(bepy, params):
    # bepy = Bitter-flavoured Embedded Python = poor man's embedded python because not allowed to use libraries

    translatedBepy = []
    indentLevel = 0
    for part in re.split("(<%.*?%>)", bepy):
        if len(part) >= 4 and part.startswith("<%") and part.endswith("%>"):
            part = part[2:-2].strip()

            if part.startswith("#"):
                # Comment
                pass
            elif part.startswith("="):
                # Output shorthand
                translatedBepy.append("    " * indentLevel + "output(eval(" + repr(part[1:]) + "))")
            elif part.startswith("for ") or part.startswith("if "):
                # Block start
                translatedBepy.append("    " * indentLevel + part)
                indentLevel += 1
            elif part.startswith("elif ") or part.startswith("else:"):
                # Block continuation
                translatedBepy.append("    " * (indentLevel - 1) + part)
            elif not part:
                # Block end
                indentLevel -= 1
            else:
                translatedBepy.append("    " * indentLevel + part)
        elif part.find("<%") >= 0 or part.find("%>") >= 0:
            raise SyntaxError("Mismatched <% or %> in bepy")
        else:
            translatedBepy.append("    " * indentLevel + "outputRaw(" + repr(part) + ")")

    import sys
    sys.stderr.write("\n".join(translatedBepy) + "\n")

    result = {"s": u""} # Hack to allow output functions to modify it
    def outputRaw(s):
        result["s"] += s if isinstance(s, basestring) else unicode(s)
    def output(s):
        outputRaw(escape(s if isinstance(s, basestring) else unicode(s)))

    def include(view, params2 = {}):
        if "req" in params:
            params2["req"] = params["req"]
        if "res" in params:
            params2["res"] = params["res"]

        outputRaw(renderView(view, params2))

    functions = {
        "include": include,
        "escape": escape,
        "outputRaw": outputRaw,
        "output": output
    }

    exec "\n".join(translatedBepy) in functions, params

    return result["s"]
