from bitter.controller import Controller
from bitter.models.user import User

class UserController(Controller):
    @classmethod
    def findOne(cls, req, res):
        user = super(UserController, cls).findOne(req, res)

        if user:
            user.populate("bleats")
            user.populate("listeningTo")
            user.populate("listenedBy")

        return user

    @classmethod
    def updateOne(cls, req, res):
        if not req.user or str(req.user.id) != req.params["id"]:
            res.status = 403
            return

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
        "listeningTo",
        "listenedBy"
    ))
