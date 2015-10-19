from datetime import datetime

from bitter.controller import Controller
from bitter.models.bleat import Bleat

class BleatController(Controller):
    @classmethod
    def createOne(cls, req, res):
        if not req.user:
            res.status = 403
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
        "timestamp"
    ))
