import base64
from email.utils import parseaddr
from email.mime.text import MIMEText
import hashlib
import hmac
import smtplib

from bitter.controller import Controller
from bitter.db import Coordinates, File
from bitter.models.user import User
from bitter.renderer import render
from bitter.router import defaultRoutes

_secret = "<random 128-bit hex string>".decode("hex")
_emailServer = "<email server (must support STARTTLS)>"
_emailAddr = "<email username>"
_emailUsername = _emailAddr
_emailPassword = "<email password>"

def getEmail(email):
    email = parseaddr(email)[1]
    return email if "@" in email else None

def sendEmail(to, subject, message):
    msg = MIMEText(message)
    msg["Subject"] = subject
    msg["From"] = _emailAddr
    msg["To"] = to

    smtp = smtplib.SMTP(_emailServer, 587)
    smtp.ehlo()
    smtp.starttls()
    smtp.login(_emailUsername, _emailPassword)
    smtp.sendmail(_emailAddr, [to], msg.as_string())
    smtp.close()

class UserController(Controller):
    @classmethod
    def _whitelistParams(cls, params, extraWhitelist = set()):
        if "homeCoordsLat" in params and "homeCoordsLon" in params:
            params["homeCoords"] = Coordinates(lat = params.pop("homeCoordsLat"), lon = params.pop("homeCoordsLon"))
        elif "homeCoords" in params:
            del params["homeCoords"]

        if "profileImage" in params and not isinstance(params["profileImage"], File):
            del params["profileImage"]
        if "backgroundImage" in params and not isinstance(params["backgroundImage"], File):
            del params["backgroundImage"]

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

        req.body["email"] = getEmail(req.body.get("email", ""))
        if not req.body["email"]:
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

    @classmethod
    def resetPasswordAndRender(cls, req, res):
        req.body["email"] = getEmail(req.body.get("email", ""))
        if not req.body["email"]:
            res.status = 400
            return

        token = base64.b64encode(hmac.new(_secret, req.body["email"], hashlib.sha256).digest(), "-_")
        if not "token" in req.body:
            sendEmail(req.body["email"], "Bitter Password Reset Token", token)
            return
        elif req.body["token"] != token: # hmac.compare_digest() not available until v2.7.7
            res.status = 400
            return

        if not "password" in req.body:
            res.status = 400
            return

        if not User.update({"email": req.body["email"]}, {"password": req.body["password"]}):
            res.status = 400
            return

        render(req, res, "user/reset-password.html.bepy")

    _Model = User
    _whitelistedProperties = set((
        "id",
        "email",
        "username",
        "password",
        "name",
        "profileImage",
        "backgroundImage",
        "description",
        "homeCoords",
        "homeSuburb",
        "listeningTo",
        "listenedBy"
    ))

defaultRoutes[("POST", "^/user/reset-password")] = UserController.resetPasswordAndRender
