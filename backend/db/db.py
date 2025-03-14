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
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///conversations.db'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    db.init_app(app)
    with app.app_context():
        if os.path.exists('conversations.db'):
            os.remove('conversations.db')
        db.create_all()
