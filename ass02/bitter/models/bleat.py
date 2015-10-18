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
    create index bleat_user_timestamp on bleat(user, timestamp desc);
    create index bleat_in_reply_to_timestamp on bleat(in_reply_to, timestamp desc);
    create index bleat_timestamp on bleat(timestamp desc);
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

"""
WITH RECURSIVE is_in_reply_to(id,in_reply_to,timestamp) AS (
    SELECT id,in_reply_to,timestamp FROM bleat WHERE id=?
    UNION ALL
    SELECT bleat.id,bleat.in_reply_to,bleat.timestamp FROM bleat,is_in_reply_to WHERE bleat.in_reply_to=is_in_reply_to.id  order by bleat.timestamp desc)
SELECT * FROM is_in_reply_to;
"""
