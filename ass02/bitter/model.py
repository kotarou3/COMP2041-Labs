import inspect
import re

from bitter.db import db

class Model(object):
    publicProperties = set(("id",))
    defaultOrderBy = "id asc"

    _sentinel = object()

    def __init__(self, row):
        for key in row.keys():
            setattr(self, self._fromTableName(key), row[key])

    def __repr__(self):
        return "<{0} id: {1}>".format(self.__class__.__name__, self.id)

    @staticmethod
    def _toTableName(name):
        # camelCase to snake_case
        return re.sub("((?<=[a-z0-9])[A-Z]|(?!^)[A-Z](?=[a-z]))", r"_\1", name).lower()

    @staticmethod
    def _fromTableName(name):
        # snake_case to camelCase
        parts = name.split("_")
        return parts[0] + "".join(map(str.capitalize, parts[1:]))

    @classmethod
    def _buildWhereClause(cls, where):
        result = {}
        for key, value in where.iteritems():
            result["{0} {1} ?".format(
                cls._toTableName(key),
                value[0] if type(value) is tuple else "="
            )] = value[1] if type(value) is tuple else value

        return result

    @classmethod
    def paginate(cls, where = {}, orderBy = _sentinel, page = 1, perPage = 20):
        if orderBy is cls._sentinel:
            orderBy = cls.defaultOrderBy

        cur = db.cursor()

        query = [
            "select *",
            "from {0}".format(cls._toTableName(cls.__name__))
        ]

        if where:
            where = cls._buildWhereClause(where)
            query.append("where {0}".format(" and ".join(where.keys())))

        if orderBy:
            query.append("order by {0}".format(orderBy))

        if perPage:
            # Get total number of records so we can work out pages
            cur.execute(" ".join(["select count(*)"] + query[1:]), where.values())
            totalRecords = cur.fetchone()[0]

            query.append("limit {0:d}".format(perPage))
            if page > 1:
                query.append("offset {0:d}".format(perPage * (page - 1)))

        cur.execute(" ".join(query), where.values())
        records = map(cls, cur.fetchall())

        if not perPage:
            totalRecords = len(records)
        totalPages = (totalRecords + (perPage - 1)) / perPage if perPage else 1 # Ceiling division

        return {
            "records": records,
            "page": page,
            "totalRecords": totalRecords,
            "totalPages": totalPages
        }

    @classmethod
    def find(cls, where = {}, orderBy = _sentinel, limit = 0):
        return cls.paginate(where, orderBy = orderBy, perPage = limit)["records"]

    @classmethod
    def findOne(cls, where = {}):
        query = "select * from {0}".format(cls._toTableName(cls.__name__))

        if where:
            where = cls._buildWhereClause(where)
            query += " where {0}".format(" and ".join(where.keys()))

        cur = db.cursor()
        cur.execute(query + " limit 1", where.values())

        result = cur.fetchone()
        return cls(result) if result else None

    @classmethod
    def create(cls, properties):
        cur = db.cursor()
        if properties:
            cur.execute(
                "insert into {0} ({1}) values ({2})".format(
                    cls._toTableName(cls.__name__),
                    ", ".join(map(cls._toTableName, properties.keys())),
                    ", ".join(["?"] * len(properties))
                ),
                properties.values()
            )
        else:
            cur.execute("insert into {0} default values".format(cls._toTableName(cls.__name__)))

        return cls.findOne({"id": cur.lastrowid})

    @classmethod
    def update(cls, where, update):
        where = cls._buildWhereClause(where)

        cur = db.cursor()
        cur.execute(
            "update {0} set {1} where {2}".format(
                cls._toTableName(cls.__name__),
                ", ".join(map(lambda key: cls._toTableName(key) + " = ?", update.keys())),
                " and ".join(where.keys()),
            ),
            update.values() + where.values()
        )

        return cur.rowcount

    @classmethod
    def delete(cls, where):
        where = cls._buildWhereClause(where)

        cur = db.cursor()
        cur.execute(
            "delete from {0} where {1}".format(
                cls._toTableName(cls.__name__),
                " and ".join(where.keys()),
            ),
            where.values()
        )

        return cur.rowcount

    def save(self):
        self.update({"id": self.id}, vars(self))

    def erase(self):
        self.delete({"id": self.id})
