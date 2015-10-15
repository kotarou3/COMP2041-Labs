from datetime import datetime

from bitter.controller import Controller
from bitter.models.bleat import Bleat

class BleatController(Controller):
    @classmethod
    def create(cls, req, res):
        req.body["timestamp"] = datetime.utcnow()
        return super(BleatController, cls).create(req, res)

    _Model = Bleat
    _whitelistedProperties = set((
        "id",
        "user",
        "inReplyTo",
        "content",
        "timestamp"
    ))
