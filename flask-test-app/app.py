import os
from flask import Flask, request, jsonify

app = Flask(__name__)


@app.route("/")
def default():
    return "Hello world"


@app.route("/headers")
def dump_headers():
    return jsonify({k: v for k, v in request.headers.items()})


@app.route("/env")
def dump_environment():
    return jsonify({k: v for k, v in os.environ.items()})


if __name__ == "__main__":
    from gevent.pywsgi import WSGIServer
    http_server = WSGIServer(('', int(os.getenv("FLASK_PORT", default="8080"))), app)
    http_server.serve_forever()