from flask import Flask, jsonify, request
from db.db import db, init_db, Conversation, Message, SenderType
from llm.llm import handler, new_story_generator, add_to_story

app = Flask(__name__)

# Initialize the SQLAlchemy db instance
init_db(app)


def log_message(conversation_id, sender_type, code, content):
    message = Message(
        conversation_id=conversation_id,
        sender_type=sender_type,
        code=code,
        content=content
    )
    db.session.add(message)
    db.session.commit()


def fetch_conversations_by_user(user_id):
    conversations = Conversation.query.filter_by(user_id=user_id).all()
    return conversations


def fetch_messages_by_user_and_conversation(user_id, conversation_id):
    messages = Message.query.join(Conversation).filter(
        Conversation.user_id == user_id,
        Message.conversation_id == conversation_id
    ).order_by(Message.created_at).all()
    return messages


def generate_new_story(query):
    try:
        story = new_story_generator(query)
    except ValueError:
        return jsonify({"message": "Invalid response from new_story_generator"})
    return story


def add_to_existing_story(conversation_id, query):
    try:
        extended_story = add_to_story(conversation_id, query)
    except ValueError:
        return jsonify({"message": "Invalid response from add_to_story"})
    return extended_story


@app.route('/handle_request', methods=['POST'])
def handle_request():
    data = request.get_json()
    query = data.get('query')
    user_id = data.get('user_id', 'user_id_placeholder')
    conversation_id = data.get('conversation_id')

    if query:
        try:
            code = int(handler(query))
        except ValueError:
            return jsonify({"message": "Invalid response from handler"})

        if conversation_id:
            conversation = Conversation.query.get(conversation_id)
            if not conversation:
                return jsonify({"message": "Invalid conversation ID"})
        else:
            conversation = Conversation(user_id=user_id)
            db.session.add(conversation)
            db.session.commit()
            conversation_id = conversation.id

        if code == 2 and conversation_id:  # If the user asks for a new story and there is an existing conversation
            return jsonify({"confirmation": "Are you sure you want to start a new story? Please confirm by clicking Yes or No.", "conversation_id": conversation_id})

        log_message(conversation.id, SenderType.USER, code, query)

        if code == 0:  # If the user asks for something unrelated to telling a story
            response = "Sorry, I can only tell stories. Please ask me to tell you a story."
        elif code == 1:  # If the user asks for something related to a story but violates safety rules
            response = "Sorry, I can't tell that story. Please ask me to tell you a story."
        elif code == 3:  # If the user asks for an addition to an existing story
            response = add_to_existing_story(conversation.id, query)
            log_message(conversation.id, SenderType.MODEL, code, response)
        else:
            response = f"Invalid code: {code}"

        return jsonify({"response": response, "conversation_id": conversation_id})
    else:
        return jsonify({"message": "Query required"})


@app.route('/confirm_new_story', methods=['POST'])
def confirm_new_story_route():
    data = request.get_json()
    query = data.get('query')
    user_id = data.get('user_id', 'user_id_placeholder')
    confirmation = data.get('confirmation')
    conversation_id = data.get('conversation_id')

    if query and confirmation:
        if confirmation.lower() == 'y':
            conversation = Conversation(user_id=user_id)
            db.session.add(conversation)
            db.session.commit()

            response = generate_new_story(query)
            log_message(conversation.id, SenderType.MODEL, 2, response)

            return jsonify({"message": "New story initiated.", "response": response, "conversation_id": conversation.id})
        elif confirmation.lower() == 'n':
            return jsonify({"message": "New story request canceled."})
        else:
            return jsonify({"message": "Invalid confirmation. Please confirm by sending 'y' or 'n'."})
    else:
        return jsonify({"message": "Query and confirmation required"})


if __name__ == '__main__':
    app.run(debug=True)
