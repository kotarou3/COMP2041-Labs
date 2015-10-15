class Request(object):
    def __init__(self, method, path, fileext, params, headers, body):
        self.method = method
        self.path = path
        self.fileext = fileext
        self.params = params
        self.headers = headers
        self.body = body

class Response(object):
    def __init__(self, status = 0, headers = {}, body = ""):
        self.status = status
        self.headers = headers
        self.body = body
