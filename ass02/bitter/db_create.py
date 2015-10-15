import importlib

from bitter.db import db

with db:
    for name in "user", "bleat":
        model = importlib.import_module("bitter.models.{0}".format(name))
        db.executescript(model.schema)
