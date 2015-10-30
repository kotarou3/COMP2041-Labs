from Cookie import SimpleCookie
from datetime import datetime

from bitter.models.session import Session
from bitter.models.user import User

class Request(object):
    def __init__(self, remoteAddress, method, baseUri, path, fileext, params, headers, body):
        self.remoteAddress = remoteAddress
        self.method = method
        self.baseUri = baseUri
        self.path = path
        self.fileext = fileext
        self.params = params
        self.origParams = params.copy()
        self.headers = headers
        self.cookies = SimpleCookie(headers.get("Cookie", ""))
        self.body = body

        self.user = None
        if "session" in self.cookies:
            self.session = Session.findOne({"id": self.cookies["session"].value})
            if self.session:
                self.user = User.findOne({
                    "id": self.session.user,
                    "passwordHash": self.session.passwordHash
                })

                if self.user:
                    self.session.lastAddress = self.remoteAddress
                    self.session.lastUse = datetime.utcnow()
                    self.session.save()
                    self.user.isDisabled = False
                    self.user.save()
                else:
                    self.session.erase()

class Response(object):
    def __init__(self, status = 0, headers = {}, cookies = None, body = ""):
        self.status = status
        self.headers = headers
        self.cookies = cookies or SimpleCookie()
        self.body = body
