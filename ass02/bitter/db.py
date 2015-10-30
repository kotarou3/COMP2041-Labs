import sqlite3
import subprocess
import os

class Coordinates(object):
    def __init__(self, lat, lon):
        self.lat, self.lon = float(lat), float(lon)

    def __repr__(self):
        return "<Coordinates {0:f}, {1:f}>".format(self.lat, self.lon)

def adapt_coordinates(coord):
    return "{0:f},{1:f}".format(coord.lat, coord.lon)

def convert_coordinates(s):
    lat, lon = map(float, s.split(","))
    return Coordinates(lat, lon)

class File(object):
    def __init__(self, hash, name, mime = None):
        if not mime:
            # subprocess.check_output not supported until v2.7
            process = subprocess.Popen(["file", "-b", "--mime-type", "--", os.path.join(os.path.dirname(os.path.realpath(__file__)), "uploads", hash)], stdout = subprocess.PIPE)
            mime = process.communicate()[0].strip()

        self.hash, self.name, self.mime = hash, name, mime

    def __repr__(self):
        return "<File {0} {1}: {2}>".format(self.mime, self.hash, repr(self.name))

def adapt_file(file):
    return u"{0}:{1}:{2}".format(file.hash, file.mime, file.name)

def convert_file(s):
    hash, mime, name = s.split(":", 2)
    return File(hash = hash, name = name, mime = mime)

sqlite3.enable_callback_tracebacks(True)
sqlite3.register_adapter(Coordinates, adapt_coordinates)
sqlite3.register_converter("coordinates", convert_coordinates)
sqlite3.register_adapter(File, adapt_file)
sqlite3.register_converter("file", convert_file)

db = sqlite3.connect(
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "db.sqlite"),
    detect_types = sqlite3.PARSE_DECLTYPES
)
db.row_factory = sqlite3.Row

db.execute("pragma foreign_keys = ON")
