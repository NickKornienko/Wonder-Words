from flask_sqlalchemy import SQLAlchemy
import os

db = SQLAlchemy()


class Conversation(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    request = db.Column(db.String, nullable=False)
    response = db.Column(db.String, nullable=False)


def init_db(app):
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///conversations.db'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    db.init_app(app)
    with app.app_context():
        if not os.path.exists('conversations.db'):
            db.create_all()
