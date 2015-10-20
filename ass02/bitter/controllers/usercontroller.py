from bitter.controller import Controller
from bitter.db import Coordinates, File
from bitter.models.user import User

class UserController(Controller):
    @classmethod
    def _whitelistParams(cls, params, extraWhitelist = set()):
        if "homeCoordsLat" in params and "homeCoordsLon" in params:
            params["homeCoords"] = Coordinates(lat = params.pop("homeCoordsLat"), lon = params.pop("homeCoordsLon"))
        elif "homeCoords" in params:
            del params["homeCoords"]

        if "profileImage" in params and not isinstance(params["profileImage"], File):
            del params["profileImage"]

        return super(UserController, cls)._whitelistParams(params, extraWhitelist)

    @classmethod
    def find(cls, req, res):
        try:
            page = int(req.params.pop("page", 1))
        except ValueError:
            res.status = 400
            return

        return cls._Model.paginate(cls._whitelistParams(req.params, set(("search",))), page = page)

    @classmethod
    def findOne(cls, req, res):
        user = super(UserController, cls).findOne(req, res)

        if user:
            user.populate("bleats")
            user.populate("listeningTo")
            user.populate("listenedBy")

        return user

    @classmethod
    def createOne(cls, req, res):
        if "listeningTo" in req.body:
            del req.body["listeningTo"]
        if "listenedBy" in req.body:
            del req.body["listenedBy"]

        return super(UserController, cls).createOne(req, res)

    @classmethod
    def updateOne(cls, req, res):
        if not req.user or str(req.user.id) != req.params["id"]:
            res.status = 403
            return

        if "listenedBy" in req.body:
            del req.body["listenedBy"]

        user = super(UserController, cls).updateOne(req, res)

        if user:
            user.populate("bleats")
            user.populate("listeningTo")
            user.populate("listenedBy")

        return user

    @classmethod
    def deleteOne(cls, req, res):
        if not req.user or str(req.user.id) != req.params["id"]:
            res.status = 403
            return

        return super(UserController, cls).deleteOne(req, res)

    _Model = User
    _whitelistedProperties = set((
        "id",
        "email",
        "username",
        "password",
        "name",
        "profileImage",
        "description",
        "homeCoords",
        "homeSuburb",
        "listeningTo",
        "listenedBy"
    ))
