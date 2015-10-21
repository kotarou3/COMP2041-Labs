from datetime import datetime

from bitter.controller import Controller
from bitter.db import Coordinates, File
from bitter.models.bleat import Bleat

class BleatController(Controller):
    @classmethod
    def _whitelistParams(cls, params, extraWhitelist = set()):
        if "locationCoordsLat" in params and "locationCoordsLon" in params:
            params["locationCoords"] = Coordinates(lat = params.pop("locationCoordsLat"), lon = params.pop("locationCoordsLon"))
        elif "locationCoords" in params:
            del params["locationCoords"]

        if "attachments" in params:
            if not type(params["attachments"]) is list:
                params["attachments"] = [params["attachments"]]
            if not all([isinstance(attachment, File) for attachment in params["attachments"]]):
                del params["attachments"]

        return super(BleatController, cls)._whitelistParams(params, extraWhitelist)

    @classmethod
    def find(cls, req, res):
        try:
            page = int(req.params.pop("page", 1))
        except ValueError:
            res.status = 400
            return

        return cls._Model.paginate(cls._whitelistParams(req.params, set(("search",))), page = page)

    @classmethod
    def createOne(cls, req, res):
        if not req.user:
            res.status = 403
            return

        if not "content" in req.body or not 1 <= len(req.body["content"]) <= 142:
            res.status = 400
            return

        req.body["user"] = req.user.id
        req.body["timestamp"] = datetime.utcnow()

        return super(BleatController, cls).createOne(req, res)

    @classmethod
    def updateOne(cls, req, res):
        res.status = 403

    @classmethod
    def deleteOne(cls, req, res):
        if not req.user:
            res.status = 403
            return

        bleat = Bleat.findOne(cls._whitelistParams(req.params))
        if not bleat:
            res.status = 404
            return

        if req.user.id != bleat.user:
            res.status = 403
            return

        bleat.erase()
        return True

    _Model = Bleat
    _whitelistedProperties = set((
        "id",
        "user",
        "inReplyTo",
        "content",
        "attachments",
        "timestamp",
        "locationCoords"
    ))
