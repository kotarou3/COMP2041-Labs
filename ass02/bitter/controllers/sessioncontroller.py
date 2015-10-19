from datetime import datetime

from bitter.controller import Controller
from bitter.models.session import Session
from bitter.models.user import User
from bitter.renderer import render
from bitter.router import defaultRoutes

class SessionController(Controller):
    @classmethod
    def find(cls, req, res):
        if not req.user:
            res.status = 403
            return

        page = 1
        if "page" in req.params:
            try:
                page = int(req.params["page"])
                del req.params["page"]
            except ValueError:
                res.status = 400
                return

        return Session.paginate({"user": req.user.id}, page = page)

    @classmethod
    def findOne(cls, req, res):
        res.status = 405

    @classmethod
    def createOne(cls, req, res):
        if "id" in req.body:
            del req.body["id"]

        user = User.findOne(cls._whitelistParams(req.body))
        if not user:
            res.status = 400
            render(req, res, "session/new.html.bepy")
            return

        session = Session.create({
            "user": user.id,
            "password": user.password,
            "lastAddress": req.remoteAddress,
            "lastUse": datetime.utcnow()
        })

        res.cookies["session"] = session.id
        res.cookies["session"]["httponly"] = True
        res.cookies["session"]["max-age"] = 365 * 24 * 60 * 60 # 1 year should be permanent enough

        res.status = 201
        res.headers["Location"] = "/session/{0}".format(session.id)

        return session

    @classmethod
    def updateOne(cls, req, res):
        res.status = 405

    @classmethod
    def deleteOne(cls, req, res):
        if "session" in req.cookies and req.cookies["session"].value == req.params["id"]:
            res.cookies["session"] = ""
            res.cookies["session"]["max-age"] = -1

        return Session.delete({"id": req.params["id"]})

    _Model = Session
    _whitelistedProperties = set((
        "email",
        "username",
        "password"
    ))

defaultRoutes[("DELETE", "^/session/(?P<id>[a-zA-Z0-9-_=]+)$")] = SessionController.deleteOneAndRender
