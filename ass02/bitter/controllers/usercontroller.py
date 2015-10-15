from bitter.controller import Controller
from bitter.models.user import User
from bitter.renderer import render

class UserController(Controller):
    @classmethod
    def find(cls, req, res):
        users = super(UserController, cls).find(req, res)

        for user in users:
            del user.email
            del user.password

        return users

    @classmethod
    def findOne(cls, req, res):
        user = super(UserController, cls).findOne(req, res)

        if user:
            user.populate("bleats")
            user.populate("listeningTo")
            user.populate("listenedBy")
            del user.email
            del user.password

        return user

    @classmethod
    def updateOne(cls, req, res):
        user = super(UserController, cls).updateOne(req, res)

        if user:
            user.populate("bleats")
            user.populate("listeningTo")
            user.populate("listenedBy")
            del user.email
            del user.password

        return user

    _Model = User
    _whitelistedProperties = set((
        "id",
        "email",
        "username",
        "password",
        "listeningTo",
        "listenedBy"
    ))
