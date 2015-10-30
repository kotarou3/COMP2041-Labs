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
        self.headers = headers
        self.cookies = SimpleCookie(headers.get("Cookie", ""))
        self.body = body

        self.user = None
        if "session" in self.cookies:
            session = Session.findOne({"id": self.cookies["session"].value})
            if session:
                self.user = User.findOne({
                    "id": session.user,
                    "password": session.password
                })

                if self.user:
                    session.lastAddress = self.remoteAddress
                    session.lastUse = datetime.utcnow()
                    session.save()
                else:
                    session.erase()

class Response(object):
    def __init__(self, status = 0, headers = {}, cookies = None, body = ""):
        self.status = status
        self.headers = headers
        self.cookies = cookies or SimpleCookie()
        self.body = body
