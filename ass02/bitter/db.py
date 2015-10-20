import sqlite3
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

sqlite3.enable_callback_tracebacks(True)
sqlite3.register_adapter(Coordinates, adapt_coordinates)
sqlite3.register_converter("coordinates", convert_coordinates)

db = sqlite3.connect(
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "db.sqlite"),
    detect_types = sqlite3.PARSE_DECLTYPES
)
db.row_factory = sqlite3.Row

db.execute("pragma foreign_keys = ON")
