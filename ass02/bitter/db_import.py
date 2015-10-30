from datetime import datetime
import hashlib
import os
import sys

from bitter.db import Coordinates, File, db
from bitter.models.user import User
from bitter.models.bleat import Bleat

if len(sys.argv) < 2:
    print "Usage: python -m bitter.db_import <source directory>"
    sys.exit(1)

bleatMapping = {
    "username": "username",
    "in_reply_to": "inReplyTo",

    "bleat": "content",
    "time": "timestamp",
    "latitude": "locationLat",
    "longitude": "locationLon"
}

userMapping = {
    "email": "email",
    "username": "username",
    "password": "password",

    "full_name": "name",
    "home_latitude": "homeLat",
    "home_longitude": "homeLon",
    "home_suburb": "homeSuburb",

    "listens": "listeningTo"
}

with db:
    # Read all the bleats
    bleats = {}
    for bleatId in os.listdir(os.path.join(sys.argv[1], "bleats")):
        bleatId = bleatId.decode("utf8")
        bleat = {}

        with open(os.path.join(sys.argv[1], "bleats", bleatId.encode("utf8")), "r") as handle:
            for line in handle:
                line = line.decode("utf8").strip()
                if not line:
                    continue

                parts = line.split(": ", 1)
                if len(parts) != 2:
                    print "Bleat {0} has invalid property: {1}".format(bleatId, line)
                    continue

                if not parts[0] in bleatMapping:
                    print "Bleat {0} has unknown property: {1}".format(bleatId, line)
                    continue

                bleat[bleatMapping[parts[0]]] = parts[1]

        # Conver the timestamp to a datetime.timestamp
        bleat["timestamp"] = datetime.utcfromtimestamp(int(bleat["timestamp"]))

        # Convert the location coordinates into a Coordinates object
        if ("locationLat" in bleat) ^ ("locationLon" in bleat):
            print "Bleat {0} has location coordinates inconsistency".format(bleatId)
            if "locationLat" in bleat:
                del bleat["locationLat"]
            if "locationLon" in bleat:
                del bleat["locationLon"]
        if "locationLat" in bleat:
            bleat["locationCoords"] = Coordinates(float(bleat.pop("locationLat")), float(bleat.pop("locationLon")))

        bleats[bleatId] = bleat

    # Read and import all the users
    users = {}
    for username in os.listdir(os.path.join(sys.argv[1], "users")):
        username = username.decode("utf8")
        user = {}

        with open(os.path.join(sys.argv[1], "users", username.encode("utf8"), "details.txt"), "r") as handle:
            for line in handle:
                line = line.decode("utf8").strip()
                if not line:
                    continue

                parts = line.split(": ", 1)
                if len(parts) != 2:
                    print "User {0} has invalid property: {1}".format(username, line)
                    continue

                if not parts[0] in userMapping:
                    print "User {0} has unknown property: {1}".format(username, line)
                    continue

                user[userMapping[parts[0]]] = parts[1]

        if username != user["username"]:
            print "User {0} has username inconsistency: {1}".format(username, user["username"])

        # Convert the home coordinates into the Coordinates object
        if ("homeLat" in user) ^ ("homeLon" in user):
            print "User {0} has home coordinates inconsistency".format(username)
            if "homeLat" in user:
                del user["homeLat"]
            if "homeLon" in user:
                del user["homeLon"]
        if "homeLat" in user:
            user["homeCoords"] = Coordinates(float(user.pop("homeLat")), float(user.pop("homeLon")))

        # Don't add listens just yet, since not all users have been created yet
        listeningTo = user.pop("listeningTo", [])

        try:
            # SHA-256 hash the profile image and save it to the uploads directory
            # XXX: Assumes it's small enough to fit in memory
            with open(os.path.join(sys.argv[1], "users", username.encode("utf8"), "profile.jpg"), "rb") as handle:
                profileImage = handle.read()
            hash = hashlib.sha256(profileImage).hexdigest()

            with open(os.path.join(os.path.dirname(os.path.realpath(__file__)), "uploads", hash), "wb") as handle:
                handle.write(profileImage)

            user["profileImage"] = File(hash = hash, name = u"profile.jpg")
        except IOError:
            pass

        users[username] = user = User.create(user)

        if listeningTo:
            setattr(user, "listeningTo", listeningTo)

        # Put the user id in the bleats
        with open(os.path.join(sys.argv[1], "users", username.encode("utf8"), "bleats.txt"), "r") as handle:
            for bleatId in handle:
                bleatId = bleatId.decode("utf8").strip()
                if not bleatId:
                    continue

                if not bleatId in bleats:
                    print "User {0} has unknown bleat: {1}".format(username, bleatId)
                    continue

                if bleats[bleatId]["username"] != username:
                    print "Bleat {0} has inconsistent username: {1} != {2}".format(bleatId, bleats[bleatId]["username"], username)

                bleats[bleatId]["user"] = user.id
                del bleats[bleatId]["username"]

    # Now all users have been created, the listens can be added
    for user in users.values():
        if getattr(user, "listeningTo", ""):
            user.listeningTo = map(lambda username: users[username].id, user.listeningTo.split())
            user.save()

    # Import all the bleats in chronological order
    for bleatId in sorted(bleats.keys(), key = lambda bleat: bleats[bleat]["timestamp"]):
        if not "user" in bleats[bleatId]:
            print "Bleat {0} is orphaned".format(bleatId)
            continue

        if "inReplyTo" in bleats[bleatId]:
            bleats[bleatId]["inReplyTo"] = bleats[bleats[bleatId]["inReplyTo"]].id

        bleats[bleatId] = Bleat.create(bleats[bleatId])
