from bitter.db import db
import bitter.models.bleat
import bitter.models.session
import bitter.models.user

with db:
    for model in bitter.models.bleat, bitter.models.session, bitter.models.user:
        db.executescript(model.schema)
