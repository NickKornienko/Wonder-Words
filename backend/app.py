from flask import Flask, jsonify, request
from flask_cors import CORS
from db.db import db, init_db, Conversation, Message, SenderType, ChildAccount
from llm.llm import handler, new_story_generator, add_to_story
from firebase_auth import firebase_auth_required
from child_auth import (
    save_child_account, verify_child_credentials, generate_child_token,
    child_auth_required
)
import os
from dotenv import load_dotenv
import jwt

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

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
@firebase_auth_required
def handle_request():
    data = request.get_json()
    query = data.get('query')
    # Use Firebase user ID from the token
    user_id = request.firebase_user.get('localId', 'user_id_placeholder')
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
            return jsonify({"confirmation": "Are you sure you want to start a new story? Please respond with 'yes' or 'no'.", "conversation_id": conversation_id})

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
@firebase_auth_required
def confirm_new_story_route():
    data = request.get_json()
    query = data.get('query')
    # Use Firebase user ID from the token
    user_id = request.firebase_user.get('localId', 'user_id_placeholder')
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


@app.route('/get_conversations', methods=['GET'])
@firebase_auth_required
def get_conversations():
    # Use Firebase user ID from the token
    user_id = request.firebase_user.get('localId', 'user_id_placeholder')
    
    try:
        conversations = fetch_conversations_by_user(user_id)
        result = []
        
        for conversation in conversations:
            # Get the first message (story) for each conversation
            messages = Message.query.filter_by(conversation_id=conversation.id).order_by(Message.created_at).all()
            first_story = next((msg for msg in messages if msg.sender_type == SenderType.MODEL), None)
            
            result.append({
                'id': conversation.id,
                'created_at': conversation.created_at.isoformat(),
                'preview': first_story.content[:100] + '...' if first_story else 'No story content',
                'message_count': len(messages)
            })
            
        return jsonify({"conversations": result})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/get_conversation_messages', methods=['GET'])
@firebase_auth_required
def get_conversation_messages():
    # Use Firebase user ID from the token
    user_id = request.firebase_user.get('localId', 'user_id_placeholder')
    conversation_id = request.args.get('conversation_id')
    
    if not conversation_id:
        return jsonify({"error": "Conversation ID is required"}), 400
    
    try:
        # Verify the conversation belongs to the user
        conversation = Conversation.query.filter_by(id=conversation_id, user_id=user_id).first()
        if not conversation:
            return jsonify({"error": "Conversation not found or access denied"}), 404
        
        messages = fetch_messages_by_user_and_conversation(user_id, conversation_id)
        result = []
        
        for message in messages:
            result.append({
                'id': message.id,
                'sender_type': message.sender_type.name,
                'content': message.content,
                'created_at': message.created_at.isoformat(),
                'code': message.code
            })
            
        return jsonify({"messages": result})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/create_child_account', methods=['POST'])
@firebase_auth_required
def create_child_account():
    data = request.get_json()
    username = data.get('username')
    pin = data.get('pin')
    display_name = data.get('display_name')
    age = data.get('age')
    
    # Use Firebase user ID from the token as the parent UID
    parent_uid = request.firebase_user.get('localId', 'user_id_placeholder')
    
    if not all([username, pin, display_name, age]):
        return jsonify({"error": "All fields are required"}), 400
    
    # Check if username already exists
    existing_account = ChildAccount.query.filter_by(username=username).first()
    if existing_account:
        return jsonify({"error": "Username already exists"}), 409
    
    # Save the child account
    success = save_child_account(username, pin, parent_uid, display_name, age)
    
    if success:
        return jsonify({"message": "Child account created successfully"})
    else:
        return jsonify({"error": "Failed to create child account"}), 500


@app.route('/child_login', methods=['POST'])
def child_login():
    data = request.get_json()
    username = data.get('username')
    pin = data.get('pin')
    
    if not all([username, pin]):
        return jsonify({"error": "Username and PIN are required"}), 400
    
    # Verify child credentials
    child_data = verify_child_credentials(username, pin)
    
    if not child_data:
        return jsonify({"error": "Invalid username or PIN"}), 401
    
    # Generate a token for the child
    token = generate_child_token(
        username, 
        child_data['parent_uid'], 
        child_data['display_name'], 
        child_data['age']
    )
    
    return jsonify({
        "token": token,
        "display_name": child_data['display_name'],
        "age": child_data['age']
    })


@app.route('/get_child_accounts', methods=['GET'])
@firebase_auth_required
def get_child_accounts():
    # Use Firebase user ID from the token
    parent_uid = request.firebase_user.get('localId', 'user_id_placeholder')
    
    # Query child accounts by parent UID
    child_accounts = ChildAccount.query.filter_by(parent_uid=parent_uid).all()
    
    # Format the results
    result = []
    for account in child_accounts:
        result.append({
            'username': account.username,
            'display_name': account.display_name,
            'age': account.age
        })
    
    return jsonify({"child_accounts": result})


@app.route('/handle_child_request', methods=['POST'])
@child_auth_required
def handle_child_request():
    data = request.get_json()
    query = data.get('query')
    conversation_id = data.get('conversation_id')
    
    # Use parent UID from the child token for database operations
    parent_uid = request.child_user.get('parent_uid', 'user_id_placeholder')
    
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
            conversation = Conversation(user_id=parent_uid)
            db.session.add(conversation)
            db.session.commit()
            conversation_id = conversation.id

        if code == 2 and conversation_id:  # If the user asks for a new story and there is an existing conversation
            return jsonify({"confirmation": "Are you sure you want to start a new story? Please respond with 'yes' or 'no'.", "conversation_id": conversation_id})

        log_message(conversation.id, SenderType.USER, code, query)

        if code == 0:  # If the user asks for something unrelated to telling a story
            response = "Sorry, I can only tell stories. Please ask me to tell you a story."
        elif code == 1:  # If the user asks for something related to a story but violates safety rules
            response = "Sorry, I can't tell that story. Please ask me to tell you a story."
        elif code == 2:  # If the user asks for a new story
            response = generate_new_story(query)
            log_message(conversation.id, SenderType.MODEL, code, response)
        elif code == 3:  # If the user asks for an addition to an existing story
            response = add_to_existing_story(conversation.id, query)
            log_message(conversation.id, SenderType.MODEL, code, response)
        else:
            response = f"Invalid code: {code}"

        return jsonify({"response": response, "conversation_id": conversation_id})
    else:
        return jsonify({"message": "Query required"})


if __name__ == '__main__':
    app.run(debug=True)
