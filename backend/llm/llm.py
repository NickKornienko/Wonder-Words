import os
from dotenv import load_dotenv
from flask import jsonify
from openai import OpenAI
from db.db import db, Conversation, Message, SenderType

model = "gpt-4o-mini"

load_dotenv()
client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
)


def handler(query):
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": (
                    "You are the handler for a storytelling AI that can generate children's stories based on a given prompt."
                    "You should take the user input and decide what to do with it by returning the appropriate code, which is the integer only. Ex. 0, 1, 2, 3, 4, 5."
                    "If the user asks for something unrelated to telling a story, respond with code 0."
                    "If the user asks for something related to a story but violates safety rules, respond with code 1."
                    "If the user asks for a new story, respond with code 2."
                    "If the user asks for an addition to an existing story, respond with code 3."
                ),
            },
            {
                "role": "user",
                "content": query,
            }
        ],
        model=model,
    )

    return chat_completion.choices[0].message.content


def new_story_generator(query):
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": (
                    "You are the writer for a storytelling AI that can generate children's stories based on a given prompt."
                    "You should take the user unput and generate a new story based on it."
                    "The story should be appropriate for children and should be creative and engaging."
                    "You should return the story as the output."
                    "Only return the story and nothing else, include metacommentary 'such as sure here is a story or here is a story about'."
                    "Limit the story to 100 words."
                ),
            },
            {
                "role": "user",
                "content": query,
            }
        ],
        model=model,
    )

    return chat_completion.choices[0].message.content


def fetch_conversation_history(conversation_id):
    messages = Message.query.filter_by(
        conversation_id=conversation_id).order_by(Message.created_at).all()
    return messages


def update_conversation_history(conversation_id, extended_story):
    new_message = Message(
        conversation_id=conversation_id,
        sender_type=SenderType.MODEL,
        code=3,
        content=extended_story
    )
    db.session.add(new_message)
    db.session.commit()


def add_to_story(conversation_id, query):
    # Fetch the existing conversation history from the database using conversation_id
    conversation_history = fetch_conversation_history(conversation_id)

    # Extract the most recent story from the conversation history
    existing_story = ""
    for message in reversed(conversation_history):
        if message.sender_type == SenderType.MODEL and message.code in [2, 3]:
            existing_story = message.content
            break

    if not existing_story:
        return jsonify({"message": "No existing story found in the conversation history."})

    # Generate the extended story by appending the new query
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": (
                    "You are the writer for a storytelling AI that can generate children's stories based on a given prompt."
                    "You should take the existing story and the new user input to generate an extended story."
                    "The story should be appropriate for children and should be creative and engaging."
                    "You should return the extended story as the output."
                    "Only return the story and nothing else, include metacommentary 'such as sure here is a story or here is a story about'."
                    "Limit the extended part of the story to 100 words."
                    "This should be a full rewrite of the story, not just a continuation, but it should be consistent with the existing story."
                ),
            },
            {
                "role": "user",
                "content": f"Existing Story: {existing_story}\nNew Input: {query}",
            }
        ],
        model=model,
    )

    extended_story = chat_completion.choices[0].message.content

    return extended_story
