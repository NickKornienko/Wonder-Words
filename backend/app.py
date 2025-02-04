from flask import Flask, jsonify, request
from db.db import db, init_db, Conversation, Message, SenderType
from llm.llm import handler, new_story_generator, add_to_story

app = Flask(__name__)

# Initialize the SQLAlchemy db instance
init_db(app)


def log_message(conversation_id, sender_type, code, content):
    message = Message(
        conversation_id=conversation_id,
        sender_type=SenderType[sender_type.upper()],
        code=code,
        content=content
    )
    db.session.add(message)
    db.session.commit()


def generate_new_story(query):
    try:
        story = new_story_generator(query)
    except ValueError:
        return jsonify({"message": "Invalid response from new_story_generator"})

    return story


def handle_request(request):
    query = request
    if query:
        try:
            code = int(handler(query))
        except ValueError:
            return jsonify({"message": "Invalid response from handler"})

        conversation = Conversation(user_id="user_id_placeholder")
        db.session.add(conversation)
        db.session.commit()

        log_message(conversation.id, 'user', code, query)

        if code == 0:  # If the user asks for something unrelated to telling a story
            response = "Sorry, I can only tell stories. Please ask me to tell you a story."

        elif code == 1:  # If the user asks for something related to a story but violates safety rules
            response = "Sorry, I can't tell that story. Please ask me to tell you a story."

        elif code == 2:  # If the user asks for a new story
            response = generate_new_story(query)
            log_message(conversation.id, 'model', code, response)

        elif code == 3:  # If the user asks for an addition to an existing story
            response = "Handling code 3"
            log_message(conversation.id, 'model', code, response)

        else:
            response = f"Invalid code: {code}"

        return response
    else:
        return jsonify({"message": "Query required"})


if __name__ == '__main__':
    app.run(debug=True)
