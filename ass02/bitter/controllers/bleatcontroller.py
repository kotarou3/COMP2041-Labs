from datetime import datetime

from bitter.controller import Controller
from bitter.emailer import sendEmail
from bitter.db import Coordinates, File
from bitter.models.bleat import Bleat
from bitter.models.user import User, canonicaliseUsername

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

        bleat = super(BleatController, cls).createOne(req, res)

        # Find all mentioned users
        mentionedUsernames = set()
        startIndex = 0
        while startIndex < len(bleat.content):
            startIndex = bleat.content.find("@", startIndex)
            if startIndex < 0:
                break
            startIndex += 1

            endIndex = len(bleat.content)
            while endIndex > startIndex:
                try:
                    mentionedUsernames.add(canonicaliseUsername(bleat.content[startIndex:endIndex]))
                    break
                except ValueError:
                    endIndex -= 1

            startIndex = endIndex

        usersToNotify = {}
        for username in mentionedUsernames:
            user = User.findOne({"canonicalUsername": username})
            if user and user.notifyOnMention and not user.isDisabled:
                usersToNotify[user.id] = user

        # Find out who we're replying to and send a notification email if needed
        if bleat.inReplyTo:
            inReplyTo = Bleat.findOne({"id": bleat.inReplyTo})
            inReplyToUser = User.findOne({"id": inReplyTo.user})

            if inReplyToUser.notifyOnReply and not inReplyToUser.isDisabled:
                if inReplyToUser.id in usersToNotify:
                    del usersToNotify[inReplyToUser.id] # Don't send two emails to a single person

                sendEmail(
                    inReplyToUser.email,
                    "Bitter Bleat Reply Notification",
                    u"{0} has responded to you in their bleat:\n{1}\n\n{2}".format(
                        req.user.name or req.user.username,
                        bleat.content,
                        u"{0}/bleat/{1}".format(req.baseUri, bleat.id)
                    )
                )

        # Notify the mentioned users if needed
        for user in usersToNotify.values():
            sendEmail(
                user.email,
                "Bitter Mention Notification",
                u"{0} has mentioned you in their bleat:\n{1}\n\n{2}".format(
                    req.user.name or req.user.username,
                    bleat.content,
                    u"{0}/bleat/{1}".format(req.baseUri, bleat.id)
                )
            )

        return bleat

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
