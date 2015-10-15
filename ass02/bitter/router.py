import importlib
import re

from bitter.renderer import render

defaultControllers = {}
for name in "user", "bleat":
    defaultControllers[name] = getattr(importlib.import_module("bitter.controllers.{0}controller".format(name)), name.capitalize() + "Controller")()

idRegex = "(?P<id>[0-9]+)"

# Simple O(N) regex router
class Router(object):
    def __init__(self, routes = {}):
        self.routes = {}

        # Add default routes
        for name, controller in defaultControllers.iteritems():
            if (hasattr(controller, "findAndRender")):
                self.addRoute("GET", "^/{0}/?$".format(name), controller.findAndRender)
            if (hasattr(controller, "findOneAndRender")):
                self.addRoute("GET", "^/{0}/:id$".format(name), controller.findOneAndRender)
            if (hasattr(controller, "createOneAndRender")):
                self.addRoute("POST", "^/{0}/?$".format(name), controller.createOneAndRender)
            if (hasattr(controller, "updateOneAndRender")):
                self.addRoute("PATCH", "^/{0}/:id$".format(name), controller.updateOneAndRender)
            if (hasattr(controller, "deleteOneAndRender")):
                self.addRoute("DELETE", "^/{0}/:id$".format(name), controller.deleteOneAndRender)

        # Add custom routes
        for route, handler in routes.iteritems():
            self.addRoute(route[0], route[1], handler)

    def addRoute(self, method, path, handler):
        path = re.compile(re.sub(":id\\b", idRegex, path))

        if not path in self.routes:
            self.routes[path] = {}
        self.routes[path][method] = handler

    def route(self, req, res):
        for possibleRoute, handlers in self.routes.iteritems():
            match = possibleRoute.match(req.path)
            if match:
                if req.method in handlers:
                    res.status = 200
                    req.params.update(match.groupdict())
                    handlers[req.method](req, res)
                else:
                    res.status = 405
                break
        else:
            res.status = 404

        if not res.body:
            if 200 <= res.status <= 299:
                res.status = 204
            else:
                render(req, res, "static/{0}.html".format(res.status))
