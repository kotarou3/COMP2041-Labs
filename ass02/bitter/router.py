import re

from bitter.renderer import render

defaultRoutes = {}

from bitter.controllers.bleatcontroller import BleatController
from bitter.controllers.sessioncontroller import SessionController
from bitter.controllers.uploadcontroller import UploadController
from bitter.controllers.usercontroller import UserController
for controller in BleatController, SessionController, UploadController, UserController:
    name = re.match("([a-zA-Z]+)Controller", controller.__name__).group(1).lower()
    if (hasattr(controller, "findAndRender")):
        defaultRoutes[("GET", "^/{0}/?$".format(name))] = controller.findAndRender
    if (hasattr(controller, "findOneAndRender")):
        defaultRoutes[("GET", "^/{0}/:id$".format(name))] = controller.findOneAndRender
    if (hasattr(controller, "createOneAndRender")):
        defaultRoutes[("POST", "^/{0}/?$".format(name))] = controller.createOneAndRender
    if (hasattr(controller, "updateOneAndRender")):
        defaultRoutes[("PATCH", "^/{0}/:id$".format(name))] = controller.updateOneAndRender
    if (hasattr(controller, "deleteOneAndRender")):
        defaultRoutes[("DELETE", "^/{0}/:id$".format(name))] = controller.deleteOneAndRender

idRegex = "(?P<id>[0-9]+)"

# Simple O(N) regex router
class Router(object):
    def __init__(self, routes = {}):
        self.routes = {}

        # Add default routes
        for route, handler in defaultRoutes.iteritems():
            self.addRoute(route[0], route[1], handler)

        # Add custom routes
        for route, handler in routes.iteritems():
            self.addRoute(route[0], route[1], handler)

    def addRoute(self, method, path, handler):
        path = re.compile(re.sub(":id\\b", idRegex, path))

        if not path in self.routes:
            self.routes[path] = {}
        self.routes[path][method] = handler

    def route(self, req, res):
        if (req.user and not req.method in ("GET", "HEAD", "OPTIONS", "TRACE") and
            req.params.pop("csrfToken", "") != req.session.csrfToken and
            req.body.pop("csrfToken", "") != req.session.csrfToken):
            res.status = 400
            return

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
