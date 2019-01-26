FROM python:3-slim

RUN groupadd -g 1000 app && \
    useradd -u 1000 -g app -m app && \
    mkdir /app && \
    chown app:app /app
WORKDIR /app
RUN python -m pip install pipenv

USER 1000

COPY Pipfile* /app/
RUN pipenv install

COPY . /app/

EXPOSE 8080
ENTRYPOINT ["pipenv", "run"]
CMD ["python3", "app.py"]