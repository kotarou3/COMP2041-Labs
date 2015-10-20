from bitter.db import db
from bitter.model import Model

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
"""

class Bleat(Model):
    publicProperties = set((
        "id",
        "user",
        "inReplyTo",
        "content",
        "timestamp",
        "locationCoords"
    ))
    defaultOrderBy = "timestamp desc, id desc"

    @classmethod
    def paginate(cls, where = {}, orderBy = Model._sentinel, page = 1, perPage = 20):
        if not "search" in where:
            return super(Bleat, cls).paginate(where, orderBy, page, perPage)

        if orderBy is Model._sentinel:
            # By number of matches, then by time and id
            orderBy = "length(offsets(bleat_content)) - length(replace(offsets(bleat_content), \" \", \"\")) desc, timestamp desc, id desc"

        cur = db.cursor()

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

        return {
            "records": records,
            "page": page,
            "totalRecords": totalRecords,
            "totalPages": totalPages
        }

"""
WITH RECURSIVE is_in_reply_to(id,in_reply_to,timestamp) AS (
    SELECT id,in_reply_to,timestamp FROM bleat WHERE id=?
    UNION ALL
    SELECT bleat.id,bleat.in_reply_to,bleat.timestamp FROM bleat,is_in_reply_to WHERE bleat.in_reply_to=is_in_reply_to.id  order by bleat.timestamp desc)
SELECT * FROM is_in_reply_to;
"""
