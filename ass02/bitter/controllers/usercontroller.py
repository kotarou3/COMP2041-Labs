import base64
from email.utils import parseaddr
from email.mime.text import MIMEText
import hashlib
import hmac
import smtplib

from bitter.controller import Controller
from bitter.db import Coordinates, File
from bitter.models.user import User, canonicaliseUsername
from bitter.renderer import render
from bitter.router import defaultRoutes

_secret = "<random 128-bit hex string>".decode("hex")
_emailServer = "<email server (must support STARTTLS)>"
_emailAddr = "<email username>"
_emailUsername = _emailAddr
_emailPassword = "<email password>"

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

def validateEmail(email):
    email = parseaddr(email)[1]
    if not "@" in email:
        raise ValueError

    return email

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

        return super(UserController, cls).createOne(req, res)

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

        return user

    @classmethod
    def deleteOne(cls, req, res):
        if not req.user or req.user.id != req.params["id"]:
            res.status = 403
            return

        return super(UserController, cls).deleteOne(req, res)

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

defaultRoutes[("POST", "^/user/reset-password")] = UserController.resetPasswordAndRender
