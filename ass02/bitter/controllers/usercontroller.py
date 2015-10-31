import base64
from datetime import datetime
import hashlib
import hmac

from bitter.controller import Controller
from bitter.emailer import sendEmail, validateEmail
from bitter.db import Coordinates, File
from bitter.models.session import Session
from bitter.models.user import User, canonicaliseUsername
from bitter.renderer import render
from bitter.router import defaultRoutes

_secret = "<random 128-bit hex string>".decode("hex")

def validateUsername(username):
    canonicaliseUsername(username)
    return username

def validateImage(file):
    if not file.mime.startswith("image/"):
        raise ValueError
    return file

class UserController(Controller):
    overallSchema = {
        "id": int,
        "email": (unicode, validateEmail),
        "username": (unicode, validateUsername),
        "password": unicode,
        "name": unicode,
        "profileImage": (File, validateImage),
        "backgroundImage": (File, validateImage),
        "description": (unicode, 16384),
        "homeCoords": Coordinates,
        "homeSuburb": unicode,
        "listeningTo": (list, int),
        "listenedBy": (list, int)
    }

    findSchema = overallSchema.copy()
    findSchema["page"] = int
    findSchema["search"] = unicode

    createOneSchema = overallSchema.copy()
    createOneSchema["token"] = unicode
    del createOneSchema["listeningTo"]
    del createOneSchema["listenedBy"]

    updateOneSchema = overallSchema.copy()
    del updateOneSchema["listenedBy"]
    updateOneSchema["notifyOnMention"] = bool
    updateOneSchema["notifyOnReply"] = bool
    updateOneSchema["notifyOnListen"] = bool

    @classmethod
    def find(cls, req, res):
        req.params["isDisabled"] = False
        return super(UserController, cls).find(req, res)

    @classmethod
    def findOne(cls, req, res):
        user = super(UserController, cls).findOne(req, res)

        if user:
            user.populate("bleats")
            user.populate("listeningTo")
            user.populate("listenedBy")

            if req.user and req.user.id == user.id:
                user.publicProperties = user.publicProperties.copy()
                user.publicProperties.add("notifyOnMention")
                user.publicProperties.add("notifyOnReply")
                user.publicProperties.add("notifyOnListen")

        return user

    @classmethod
    def createOne(cls, req, res):
        if not "email" in req.body:
            res.status = 400
            return

        token = base64.b64encode(hmac.new(_secret, req.body["email"], hashlib.sha256).digest(), "-_")
        if not "token" in req.body:
            sendEmail(req.body["email"], "Bitter Registration Token", token)
            res.status = 204
            return
        elif req.body["token"] != token: # hmac.compare_digest() not available until v2.7.7
            res.status = 400
            return
        else:
            del req.body["token"]

        user = super(UserController, cls).createOne(req, res)

        # Automatically log the user in
        if not req.user:
            session = Session.create({
                "user": user.id,
                "passwordHash": user.passwordHash,
                "lastAddress": req.remoteAddress,
                "lastUse": datetime.utcnow()
            })

            res.cookies["session"] = session.id
            res.cookies["session"]["httponly"] = True
            res.cookies["session"]["max-age"] = 365 * 24 * 60 * 60 # 1 year should be permanent enough

            req.user = user
            req.session = session

        render(req, res, "redirect-home.html.bepy")

    @classmethod
    def updateOne(cls, req, res):
        if not req.user or req.user.id != req.params["id"]:
            res.status = 403
            return

        user = super(UserController, cls).updateOne(req, res)

        if user:
            user.populate("bleats")
            user.populate("listeningTo")
            user.populate("listenedBy")

            user.publicProperties = user.publicProperties.copy()
            user.publicProperties.add("notifyOnMention")
            user.publicProperties.add("notifyOnReply")
            user.publicProperties.add("notifyOnListen")

        return user

    @classmethod
    def updateOneAndRenderViaWeb(cls, req, res):
        # Remove blank params (except the boolean ones)
        for key, value in req.body.items():
            if not value and not key.startswith("notify"):
                del req.body[key]

        return super(UserController, cls).updateOneAndRender(req, res)

    @classmethod
    def deleteOne(cls, req, res):
        if not req.user or req.user.id != req.params["id"]:
            res.status = 403
            return

        return super(UserController, cls).deleteOne(req, res)

    @classmethod
    def renderEdit(cls, req, res):
        try:
            req.params = cls._validateParams({"id": int}, req.params)
        except (TypeError, ValueError):
            res.status = 400
            return

        if not req.user or req.user.id != req.params["id"]:
            res.status = 403
            return

        render(req, res, "user/edit.html.bepy", User.findOne(req.params))

    @classmethod
    def resetPasswordAndRender(cls, req, res):
        try:
            req.body = cls._validateParams({
                "email": (unicode, validateEmail),
                "token": unicode,
                "password": unicode
            }, req.body)
        except (TypeError, ValueError):
            res.status = 400
            return

        if not req.body["email"]:
            res.status = 400
            return

        user = User.findOne({"email": req.body["email"]})
        if not user:
            res.status = 400
            return

        token = base64.b64encode(hmac.new(_secret, req.body["email"] + user.passwordHash, hashlib.sha256).digest(), "-_")
        if not "token" in req.body:
            sendEmail(req.body["email"], "Bitter Password Reset Token", token)
            return
        elif req.body["token"] != token: # hmac.compare_digest() not available until v2.7.7
            res.status = 400
            return

        if not "password" in req.body:
            res.status = 400
            return

        user.password = req.body["password"]
        user.save()

        render(req, res, "redirect-home.html.bepy")

    @classmethod
    def disableAndRender(cls, req, res):
        try:
            req.params = cls._validateParams({"id": int}, req.params)
        except (TypeError, ValueError):
            res.status = 400
            return

        if not req.user or req.user.id != req.params["id"]:
            res.status = 403
            return

        req.user.isDisabled = True
        req.user.save()

        Session.delete({"user": req.user.id})

        render(req, res, "user/disable.html.bepy")

    @classmethod
    def listenAndRender(cls, req, res):
        req.params = cls._validateParams({"id": int, "unlisten": bool}, req.params)

        if not req.user:
            res.status = 403
            return

        targetUser = User.findOne({"id": req.params["id"]})
        if not targetUser:
            res.status = 404
            return

        req.user.populate("listeningTo")
        if req.params["unlisten"]:
            if targetUser.id in req.user.listeningTo:
                req.user.listeningTo.discard(targetUser.id)
            else:
                res.status = 400
                return
        else:
            if targetUser.id in req.user.listeningTo:
                res.status = 400
                return
            else:
                req.user.listeningTo.add(targetUser.id)
        req.user.save()

        if not req.params["unlisten"] and targetUser.notifyOnListen and not targetUser.isDisabled:
            sendEmail(
                targetUser.email,
                "Bitter Listen Notification",
                u"{0} is now listening to your bleats.\n\n{1}".format(
                    req.user.name or req.user.username,
                    u"{0}/user/{1}".format(req.baseUri, req.user.id)
                )
            )

        targetUser.populate("bleats")
        targetUser.populate("listeningTo")
        targetUser.populate("listenedBy")
        render(req, res, "user/findOne.html.bepy", targetUser)

    _Model = User

defaultRoutes[("GET", "^/user/:id/edit$")] = UserController.renderEdit
defaultRoutes[("POST", "^/user/:id/edit$")] = UserController.updateOneAndRenderViaWeb
defaultRoutes[("POST", "^/user/reset-password$")] = UserController.resetPasswordAndRender
defaultRoutes[("POST", "^/user/:id/disable$")] = UserController.disableAndRender
defaultRoutes[("POST", "^/user/:id/(?P<unlisten>un|)listen$")] = UserController.listenAndRender
