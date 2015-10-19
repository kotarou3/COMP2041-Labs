import itertools

from bitter.db import db
from bitter.model import Model

schema = """
    create table user (
        id integer primary key,

        email text unique not null,
        username text unique not null,
        password text not null,

        name text,
        profile_image text,
        home_coords coordinates,
        home_suburb text
    );

    create table user_listen (
        by integer not null references user(id) on delete cascade,
        to_ integer not null references user(id) on delete cascade
    );
    create unique index user_listen_by on user_listen(by, to_);
    create index user_listen_to on user_listen(to_);
"""

class User(Model):
    publicProperties = set((
        "id",
        "username",
        "name",
        "profileImage",
        "homeCoords",
        "homeSuburb",
        "bleats",
        "listeningTo",
        "listenedBy"
    ))

    def populate(self, attribute):
        cur = db.cursor()
        if attribute == "bleats":
            cur.execute("select id from bleat where user = ?", (self.id,))
            setattr(self, "bleats", map(lambda row: row["id"], cur.fetchall()))
        elif attribute == "listeningTo":
            cur.execute("select to_ from user_listen where by = ?", (self.id,))
            setattr(self, "listeningTo", map(lambda row: row["to_"], cur.fetchall()))
        elif attribute == "listenedBy":
            cur.execute("select by from user_listen where to_ = ?", (self.id,))
            setattr(self, "listenedBy", map(lambda row: row["by"], cur.fetchall()))
        else:
            raise LookupError("User models do not contain {0} relations".format(attribute))

    @classmethod
    def _buildWhereClause(cls, where):
        search = where.pop("search", None)

        result = super(User, cls)._buildWhereClause(where)

        if search:
            search = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            search = "%" + search.replace(" ", "%") + "%"
            result["(username || \" \" || name) like ? escape \"\\\""] = search

        return result

    @classmethod
    def update(cls, where, update):
        where = cls._buildWhereClause(where)

        cur = db.cursor()
        cur.execute(
            "select id from user where {0}".format(" and ".join(where.keys())),
            where.values()
        )
        ids = map(lambda row: row["id"], cur.fetchall())

        if len(ids) == 0:
            return

        if "listeningTo" in update:
            cur.execute("delete from user_listen where by in ({0})".format(", ".join(["?"] * len(ids))), ids)
            if type(update["listeningTo"]) is str:
                update["listeningTo"] = [update["listeningTo"]]
            if update["listeningTo"]:
                cur.execute(
                    "insert into user_listen (by, to_) values {0}".format(", ".join(["(?, ?)"] * len(update["listeningTo"]))),
                    list(itertools.chain.from_iterable(itertools.product(ids, update["listeningTo"])))
                )
            del update["listeningTo"]

        if "listenedBy" in update:
            cur.execute("delete from user_listen where to_ in ({0})".format(", ".join(["?"] * len(ids))), ids)
            if type(update["listenedBy"]) is str:
                update["listenedBy"] = [update["listenedBy"]]
            if update["listenedBy"]:
                cur.execute(
                    "insert into user_listen (by, to_) values {0}".format(", ".join(["(?, ?)"] * len(update["listenedBy"]))),
                    list(itertools.chain.from_iterable(itertools.product(update["listenedBy"], ids)))
                )
            del update["listenedBy"]

        cur.execute(
            "update user set {0} where id in ({1})".format(
                ", ".join(map(lambda key: cls._toTableName(key) + " = ?", update.keys())),
                ", ".join(["?"] * len(ids)),
            ),
            update.values() + ids
        )

        return cur.rowcount
