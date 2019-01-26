import os
from flask import Flask

app = Flask(__name__)

@app.route("/")
def default():
    return "Hello world"


if __name__ == "__main__":
    from gevent.pywsgi import WSGIServer
    http_server = WSGIServer(('', int(os.getenv("FLASK_PORT", default="8080"))), app)
    http_server.serve_forever()