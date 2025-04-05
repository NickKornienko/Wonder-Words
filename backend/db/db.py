from flask_sqlalchemy import SQLAlchemy
import os
from sqlalchemy import Enum
import enum

db = SQLAlchemy()


class SenderType(enum.Enum):
    USER = "user"
    MODEL = "model"


class Conversation(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())
    user_id = db.Column(db.String, nullable=False)


class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    conversation_id = db.Column(db.Integer, db.ForeignKey(
        'conversation.id'), nullable=False)
    sender_type = db.Column(Enum(SenderType), nullable=False)
    code = db.Column(db.Integer, nullable=False)
    content = db.Column(db.String, nullable=False)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())

    conversation = db.relationship(
        'Conversation', backref=db.backref('messages', lazy=True))


class ChildAccount(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String, unique=True, nullable=False)
    pin = db.Column(db.String, nullable=False)
    display_name = db.Column(db.String, nullable=False)
    age = db.Column(db.Integer, nullable=False)
    parent_uid = db.Column(db.String, nullable=False)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())


def init_db(app):
    db_user = os.getenv("DB_USER")
    db_password = os.getenv("DB_PASSWORD")
    db_host = os.getenv("DB_HOST")
    db_name = os.getenv("DB_NAME")

    print(f"Connecting to database at {db_host} with user {db_user}")
    print(f"Using database {db_name}")

    app.config['SQLALCHEMY_DATABASE_URI'] = (
        f"mysql+mysqlconnector://{db_user}:{db_password}@{db_host}/{db_name}"
    )
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    db.init_app(app)
    with app.app_context():
        db.create_all()
