import base64
import os

from bitter.db import db
from bitter.model import Model

schema = """
    create table session (
        id text primary key,

        user integer not null references user(id) on delete cascade,
        password_hash text not null,
        csrf_token text unique not null,

        last_address text not null,
        last_use timestamp not null
    );

    create index session_user on session(user, last_use desc);
"""

class Session(Model):
    publicProperties = set((
        "user",
        "csrfToken",
        "lastAddress",
        "lastUse"
    ))
    defaultOrderBy = "last_use desc, rowid desc"

    @classmethod
    def create(cls, properties):
        properties["id"] = base64.b64encode(os.urandom(16), "-_")
        properties["csrf_token"] = base64.b64encode(os.urandom(16), "-_")

        cur = db.cursor()
        cur.execute(
            "insert into session ({0}) values ({1})".format(
                ", ".join(map(cls._toTableName, properties.keys())),
                ", ".join(["?"] * len(properties))
            ),
            properties.values()
        )

        return cls.findOne({"rowid": cur.lastrowid})
