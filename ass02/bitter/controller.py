from bitter.renderer import render

class Controller(object):
    @classmethod
    def _whitelistParams(cls, params):
        result = {}
        for key, value in params.iteritems():
            if key in cls._whitelistedProperties:
                result[key] = value
        return result

    @classmethod
    def find(cls, req, res):
        return cls._Model.find(cls._whitelistParams(req.params))

    @classmethod
    def findAndRender(cls, req, res):
        models = cls.find(req, res)
        if 200 <= res.status <= 299 and res.status != 204 and not res.body:
            render(req, res, "{0}/find.html.bepy".format(cls._Model.__name__.lower()), models)

    @classmethod
    def findOne(cls, req, res):
        return cls._Model.findOne(cls._whitelistParams(req.params))

    @classmethod
    def findOneAndRender(cls, req, res):
        model = cls.findOne(req, res)
        if not model:
            res.status = 404
        if 200 <= res.status <= 299 and res.status != 204 and not res.body:
            render(req, res, "{0}/findOne.html.bepy".format(cls._Model.__name__.lower()), model)

    @classmethod
    def createOne(cls, req, res):
        if "id" in req.body:
            del req.body["id"]

        model = cls._Model.create(cls._whitelistParams(req.body))

        res.status = 201
        res.headers["Location"] = "/{0}/{1}".format(cls._Model.__name__.lower(), model.id)

        return model

    @classmethod
    def createOneAndRender(cls, req, res):
        model = cls.createOne(req, res)
        if 200 <= res.status <= 299 and res.status != 204 and not res.body:
            render(req, res, "{0}/findOne.html.bepy".format(cls._Model.__name__.lower()), model)

    @classmethod
    def updateOne(cls, req, res):
        if "id" in req.body:
            del req.body["id"]

        model = cls._Model.findOne(cls._whitelistParams(req.params))
        if not model:
            return

        for key, value in cls._whitelistParams(req.body).iteritems():
            setattr(model, key, value)
        model.save()

        return model

    @classmethod
    def updateOneAndRender(cls, req, res):
        model = cls.updateOne(req, res)
        if not model:
            res.status = 404
        if 200 <= res.status <= 299 and res.status != 204 and not res.body:
            render(req, res, "{0}/findOne.html.bepy".format(cls._Model.__name__.lower()), model)

    @classmethod
    def deleteOne(cls, req, res):
        return cls._Model.delete(cls._whitelistParams(req.params))

    @classmethod
    def deleteOneAndRender(cls, req, res):
        model = cls.deleteOne(req, res)
        if not model:
            res.status = 404
        if 200 <= res.status <= 299 and res.status != 204 and not res.body:
            render(req, res, "{0}/deleteOne.html.bepy".format(cls._Model.__name__.lower()))

    _Model = None
    _whitelistedProperties = set(("id",))
