import itertools

from bitter.db import db
from bitter.model import Model
from bitter.models.user import User, canonicaliseUsername

schema = """
    create table bleat (
        id integer primary key,

        user integer not null references user(id) on delete cascade,
        in_reply_to integer references bleat(id) on delete set null,

        content text not null,
        timestamp timestamp not null,
        location_coords coordinates
    );
    create unique index bleat_user_timestamp on bleat(user, timestamp desc, id desc);
    create unique index bleat_in_reply_to_timestamp on bleat(in_reply_to, timestamp desc, id desc);
    create unique index bleat_timestamp on bleat(timestamp desc, id desc);

    create virtual table bleat_content using fts4(content="bleat", tokenize=porter, content);

    create trigger bleat_bu before update on bleat begin
        delete from bleat_content where docid = old.id;
    end;
    create trigger bleat_bd before delete on bleat begin
        delete from bleat_content where docid = old.id;
    end;

    create trigger bleat_au after update on bleat begin
        insert into bleat_content(docid, content) values (new.id, new.content);
    end;
    create trigger bleat_ai after insert on bleat begin
        insert into bleat_content(docid, content) values (new.id, new.content);
    end;

    create table bleat_mention (
        bleat integer not null references bleat(id) on delete cascade,
        user integer not null references user(id) on delete cascade
    );
    create unique index bleat_mention_bleat on bleat_mention(bleat, user);
    create index bleat_mention_user on bleat_mention(user);

    create table bleat_attachment (
        bleat integer not null references bleat(id) on delete cascade,
        file file not null
    );
    create unique index bleat_attachment_bleat on bleat_attachment(bleat desc, file asc);
"""

class Bleat(Model):
    publicProperties = set((
        "id",
        "user",
        "inReplyTo",
        "content",
        "mentions",
        "attachments",
        "timestamp",
        "locationCoords"
    ))
    defaultOrderBy = "timestamp desc, id desc"

    @classmethod
    def _buildWhereClause(cls, where):
        home = where.pop("home", "")
        result = super(Bleat, cls)._buildWhereClause(where)

        if home:
            # XXX: Horrible hack to get `or`s where only `and`s were intended
            # (`home` = user id of whose home we're showing)
            result["(user = ? or user in (select to_ from user_listen where by = {0:d}) or id in (select bleat from bleat_mention where user = {0:d}))".format(home)] = home

        return result

    @classmethod
    def paginate(cls, where = {}, orderBy = Model._sentinel, page = 1, perPage = 20):
        cur = db.cursor()
        if not "search" in where:
            bleats = super(Bleat, cls).paginate(where, orderBy, page, perPage)
        else:
            if orderBy is Model._sentinel:
                # By number of matches, then by time and id
                orderBy = "length(offsets(bleat_content)) - length(replace(offsets(bleat_content), \" \", \"\")) desc, timestamp desc, id desc"

            query = [
                "select bleat.*, offsets(bleat_content)",
                "from bleat_content inner join bleat on id = docid"
            ]

            where["bleat_content"] = ("match", where.pop("search"))
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

            bleats = {
                "records": records,
                "page": page,
                "totalRecords": totalRecords,
                "totalPages": totalPages
            }

        # Joins? Nah, too lazy
        for bleat in bleats["records"]:
            cur.execute("select user from bleat_mention where bleat = ?", (bleat.id,))
            setattr(bleat, "mentions", set(map(lambda row: row["user"], cur.fetchall())))
            cur.execute("select file from bleat_attachment where bleat = ?", (bleat.id,))
            setattr(bleat, "attachments", set(map(lambda row: row["file"], cur.fetchall())))

        return bleats

    @classmethod
    def findOne(cls, where = {}):
        bleat = super(Bleat, cls).findOne(where)
        if bleat:
            cur = db.cursor()
            cur.execute("select user from bleat_mention where bleat = ?", (bleat.id,))
            setattr(bleat, "mentions", set(map(lambda row: row["user"], cur.fetchall())))
            cur.execute("select file from bleat_attachment where bleat = ?", (bleat.id,))
            setattr(bleat, "attachments", set(map(lambda row: row["file"], cur.fetchall())))
        return bleat

    @classmethod
    def create(cls, properties):
        attachments = properties.pop("attachments", [])
        bleat = super(Bleat, cls).create(properties)

        # Find all mentioned users
        mentions = set()
        startIndex = 0
        while startIndex < len(bleat.content):
            startIndex = bleat.content.find("@", startIndex)
            if startIndex < 0:
                break
            startIndex += 1

            # Could binary search, but usernames generally aren't very long
            username = ""
            endIndex = startIndex + 1
            try:
                for endIndex in xrange(startIndex + 1, len(bleat.content) + 1):
                    username = canonicaliseUsername(bleat.content[startIndex:endIndex])
            except ValueError:
                pass

            if username:
                user = User.findOne({"canonicalUsername": username})
                if user:
                    mentions.add(user.id)

            startIndex = endIndex

        if mentions:
            db.execute(
                "insert into bleat_mention (bleat, user) values {0}".format(", ".join(["(?, ?)"] * len(mentions))),
                list(itertools.chain.from_iterable(itertools.product((bleat.id,), mentions)))
            )
            setattr(bleat, "mentions", mentions)

        if attachments:
            db.execute(
                "insert into bleat_attachment (bleat, file) values {0}".format(", ".join(["(?, ?)"] * len(attachments))),
                list(itertools.chain.from_iterable(itertools.product((bleat.id,), attachments)))
            )
            setattr(bleat, "attachments", attachments)

        return bleat
