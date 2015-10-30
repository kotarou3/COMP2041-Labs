from bitter.db import Coordinates
from bitter.renderer import render

class Controller(object):
    overallSchema = {"id": int}
    findSchema = {"id": int, "page": int}

    @classmethod
    def _validateParam(cls, rules, value):
        if not type(rules) is tuple:
            if rules is unicode:
                rules = (rules, 1024) # Default string length limit
            else:
                rules = (rules,)

        if rules[0] is list:
            if not type(value) is list:
                value = [value]
            return map(lambda elem: cls._validateParam(rules[1:], elem), value)

        if not type(value) is rules[0]:
            if type(value) is unicode:
                value = rules[0](value)
            else:
                raise TypeError

        for validator in rules[1:]:
            if type(validator) is int:
                if len(value) > validator:
                    raise ValueError
            else:
                value = validator(value)

        return value

    @classmethod
    def _validateParams(cls, schema, params):
        result = {}
        for key, rules in schema.iteritems():
            if not type(rules) is tuple:
                rules = (rules,)

            if rules[0] is Coordinates and key + "Lat" in params and key + "Lon" in params:
                params[key] = Coordinates(lat = cls._validateParam(int, params[key + "Lat"]), lon = cls._validateParam(int, params[key + "Lon"]))
            if key in params:
                result[key] = cls._validateParam(rules, params[key])
        return result

    @classmethod
    def find(cls, req, res):
        return cls._Model.paginate(req.params, page = req.params.pop("page", 1))

    @classmethod
    def findAndRender(cls, req, res):
        try:
            req.params = cls._validateParams(getattr(cls, "findSchema", cls.overallSchema), req.params)
        except (TypeError, ValueError):
            res.status = 400
            return

        models = cls.find(req, res)

        if 200 <= res.status <= 299 and res.status != 204 and not res.body:
            render(req, res, "{0}/find.html.bepy".format(cls._Model.__name__.lower()), models)

    @classmethod
    def findOne(cls, req, res):
        return cls._Model.findOne(req.params)

    @classmethod
    def findOneAndRender(cls, req, res):
        try:
            req.params = cls._validateParams(getattr(cls, "findOneSchema", cls.overallSchema), req.params)
        except (TypeError, ValueError):
            res.status = 400
            return

        model = cls.findOne(req, res)

        if 200 <= res.status <= 299 and res.status != 204:
            if not model:
                res.status = 404
            elif not res.body:
                render(req, res, "{0}/findOne.html.bepy".format(cls._Model.__name__.lower()), model)

    @classmethod
    def createOne(cls, req, res):
        model = cls._Model.create(req.body)

        res.status = 201
        res.headers["Location"] = "/{0}/{1}".format(cls._Model.__name__.lower(), model.id)

        return model

    @classmethod
    def createOneAndRender(cls, req, res):
        try:
            req.body = cls._validateParams(getattr(cls, "createOneSchema", cls.overallSchema), req.body)
            if "id" in req.body:
                del req.body["id"]
        except (TypeError, ValueError):
            res.status = 400
            return

        model = cls.createOne(req, res)

        if 200 <= res.status <= 299 and res.status != 204 and not res.body:
            render(req, res, "{0}/findOne.html.bepy".format(cls._Model.__name__.lower()), model)

    @classmethod
    def updateOne(cls, req, res):
        model = cls._Model.findOne(req.params)
        if not model:
            return

        for key, value in req.body.iteritems():
            setattr(model, key, value)
        model.save()

        return model

    @classmethod
    def updateOneAndRender(cls, req, res):
        try:
            req.params = cls._validateParams({"id": getattr(cls, "idType", int)}, req.params)
            req.body = cls._validateParams(getattr(cls, "updateOneSchema", cls.overallSchema), req.body)
            if "id" in req.body:
                del req.body["id"]
        except (TypeError, ValueError):
            res.status = 400
            return

        model = cls.updateOne(req, res)

        if 200 <= res.status <= 299 and res.status != 204:
            if not model:
                res.status = 404
            elif not res.body:
                render(req, res, "{0}/findOne.html.bepy".format(cls._Model.__name__.lower()), model)

    @classmethod
    def deleteOne(cls, req, res):
        return cls._Model.delete(req.params)

    @classmethod
    def deleteOneAndRender(cls, req, res):
        try:
            req.params = cls._validateParams({"id": getattr(cls, "idType", int)}, req.params)
        except (TypeError, ValueError):
            res.status = 400
            return

        isDeleted = cls.deleteOne(req, res)
        if 200 <= res.status <= 299 and res.status != 204:
            if not isDeleted:
                res.status = 404
            elif not res.body:
                render(req, res, "{0}/deleteOne.html.bepy".format(cls._Model.__name__.lower()))

    _Model = None
