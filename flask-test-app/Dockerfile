FROM python:3-slim

RUN groupadd -g 1000 app && useradd -u 1000 -g app -d /app -m app
WORKDIR /app
USER 1000

RUN python -m pip install pipenv
COPY flask-test-app/Pipfile* /app
RUN pipenv install

COPY flask-test-app /app
