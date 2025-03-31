from db.db import db
import enum


class StoryTheme(enum.Enum):
    DRAGONS = "dragons"
    SPACE = "space"
    ANIMALS = "animals"
    MAGIC = "magic"
    PIRATES = "pirates"
    DINOSAURS = "dinosaurs"
    FAIRY_TALE = "fairy_tale"
    ADVENTURE = "adventure"


class StoryAssignment(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    conversation_id = db.Column(db.Integer, db.ForeignKey('conversation.id'), nullable=False)
    child_username = db.Column(db.String, db.ForeignKey('child_account.username'), nullable=False)
    title = db.Column(db.String, nullable=False)
    assigned_at = db.Column(db.DateTime, default=db.func.current_timestamp())

    # Relationships
    conversation = db.relationship('Conversation', backref=db.backref('assignments', lazy=True))
    child_account = db.relationship('ChildAccount', backref=db.backref('assigned_stories', lazy=True))


def init_story_assignment_db(app):
    with app.app_context():
        db.create_all()
