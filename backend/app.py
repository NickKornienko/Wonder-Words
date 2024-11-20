from flask import Flask, jsonify, request
from db.db import db, init_db, Conversation
from llm.llm import llm

app = Flask(__name__)

# Initialize the SQLAlchemy db instance
init_db(app)


def get_llm_response(query):
    response = llm(query)
    return response


def get_conversation(conversation_id):
    conversation = Conversation.query.get(conversation_id)
    if conversation:
        return {"request": conversation.request, "response": conversation.response}
    else:
        return {"message": "No conversation found"}


def add_conversation(new_request, new_response):
    if new_request and new_response:
        conversation = Conversation(request=new_request, response=new_response)
        db.session.add(conversation)
        db.session.commit()
        return {"message": "Conversation added", "id": conversation.id}
    else:
        return {"message": "Request and response required"}


def handle_request(request):
    query = request
    if query:
        response = get_llm_response(query)
        result = add_conversation(query, response)
        return {"request": query, "response": response, "id": result["id"], "message": "Conversation added"}
    else:
        return jsonify({"message": "Query required"})


if __name__ == '__main__':
    app.run(debug=True)
