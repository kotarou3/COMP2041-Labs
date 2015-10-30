from datetime import datetime

from bitter.controller import Controller
from bitter.models.session import Session
from bitter.models.user import User
from bitter.renderer import render
from bitter.router import defaultRoutes

class SessionController(Controller):
    idType = unicode
    overallSchema = {}

    findSchema = {"page": int}

    createOneSchema = {
        "email": unicode,
        "username": unicode,
        "password": unicode
    }

    @classmethod
    def find(cls, req, res):
        if not req.user:
            res.status = 403
            return

        return Session.paginate({"user": req.user.id}, page = req.params.pop("page", 1))

    @classmethod
    def findOne(cls, req, res):
        res.status = 405

    @classmethod
    def createOne(cls, req, res):
        user = User.findOne(req.body)
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

    _Model = Session

defaultRoutes[("DELETE", "^/session/(?P<id>[a-zA-Z0-9-_=]+)$")] = SessionController.deleteOneAndRender
