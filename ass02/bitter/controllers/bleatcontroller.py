from datetime import datetime

from bitter.controller import Controller
from bitter.db import Coordinates, File
from bitter.models.bleat import Bleat

def validateAttachment(file):
    if not file.mime.startswith("image/"): # Only images for now...
        raise ValueError
    return file

class BleatController(Controller):
    overallSchema = {
        "id": int,
        "user": int,
        "inReplyTo": int,
        "content": (unicode, 142),
        "attachments": (list, File, validateAttachment),
        "timestamp": unicode,
        "locationCoords": Coordinates
    }

    findSchema = overallSchema.copy()
    findSchema["page"] = int
    findSchema["search"] = unicode

    createOneSchema = overallSchema.copy()
    del createOneSchema["user"]
    del createOneSchema["timestamp"]

    @classmethod
    def createOne(cls, req, res):
        if not req.user:
            res.status = 403
            return

        if not "content" in req.body or len(req.body["content"]) < 1:
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

        bleat = Bleat.findOne(req.params)
        if not bleat:
            return

        if req.user.id != bleat.user:
            res.status = 403
            return

        bleat.erase()
        return True

    _Model = Bleat
