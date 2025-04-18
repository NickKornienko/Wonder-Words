import os
from dotenv import load_dotenv
from flask import jsonify
from openai import OpenAI
from db.db import db, Conversation, Message, SenderType
import mysql
from mysql.connector import Error
import pandas as pd

model = "gpt-4o-mini"

load_dotenv(dotenv_path=os.path.join(
    os.path.dirname(__file__), '..', '..', '.env'))

client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
)
# Database connection details
host = os.getenv("DB_HOST")
user = os.getenv("DB_USER")
password = os.getenv("DB_PASSWORD")
database = os.getenv("DB_NAME")

def connect_to_database():
    """Create a connection to the MySQL database."""
    try:
        connection = mysql.connector.connect(
            host=host,
            user=user,
            password=password,
            database=database
        )
        if connection.is_connected():
            print("Connected to the database")
            return connection
    except Error as e:
        print(f"Error while connecting to MySQL: {e}")
        return None

def add_to_prompt_table(features, vocabulary, user_prompt, model_response):
    """Add a new prompt and its features to the MySQL database."""
    connection = connect_to_database()
    if connection:
        try:
            cursor = connection.cursor()
            # Insert the new prompt into the prompts table
            insert_query = """
                INSERT INTO prompt_data (features, vocabulary, user_prompt, model_response)
                VALUES (%s, %s, %s, %s)
            """
            cursor.execute(insert_query, (features, vocabulary, user_prompt, model_response))
            connection.commit()
            print("New prompt added successfully")
        except Error as e:
            print(f"Error while inserting data: {e}")
        finally:
            cursor.close()
            connection.close()    

def add_to_meta_prompt_table(user_meta_prompt, model_meta_response):
    """Add a new meta prompt and its response to the MySQL database."""
    connection = connect_to_database()
    if connection:
        try:
            cursor = connection.cursor()
            # Insert the new meta prompt into the meta_prompts table
            insert_query = """
                INSERT INTO meta_prompt_data (user_meta_prompt, model_meta_response)
                VALUES (%s, %s)
            """
            cursor.execute(insert_query, (user_meta_prompt, model_meta_response))
            connection.commit()
            print("New meta prompt added successfully")
        except Error as e:
            print(f"Error while inserting data: {e}")
        finally:
            cursor.close()
            connection.close()

# This subprompt is used to handle the language of the user's input.
language_handling_subprompt = "Important: Respond to the user's input in the language they are using. Interpret their request in their language to make decisions to your instructions."
def handler(query):
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": (
                    f"{language_handling_subprompt}"
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

    # chat completion to extract interesting vocabulary from the query
    vocabulary_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": (
                    f"{language_handling_subprompt}"
                    "You are a vocabulary expert for a storytelling AI."
                    "You should create a list of some existing or novel (around 3-5) vocabulary words that pair well with the story query."
                    "Return the vocabulary as a comma-separated list of words."
                    "Aim to include words that are unique, descriptive, and engaging for children."
                    "Do not include common words or phrases, and only return the vocabulary words without any additional text."
                ),
            },
            {
                "role": "user",
                "content": query,
            }
        ],
        model=model,
    )
    # chat completion to generate narrative features from the query
    example_narrative_features = ['dialogue', 'twist', 'moralvalue', 'foreshadowing', 'goodending', 'badending', 'characterdevelopment']
    features_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": (
                    f"{language_handling_subprompt}"
                    "You are a narrative features expert for a storytelling AI."
                    "You should create a list of some existing or novel (around 3-5) narrative features that pair well with the story query."
                    f"Example narrative features include: {', '.join(example_narrative_features)}."
                    "Return the features as a comma-separated list of words."
                    "Aim to include storytelling or literature narratives that are unique, descriptive, and engaging for children."
                    "Do not include common words or phrases, and only return the narrative features without any additional text."
                ),
            },
            {
                "role": "user",
                "content": query,
            }
        ],
        model=model,
    )

    vocabulary_response = vocabulary_completion.choices[0].message.content
    features_response = features_completion.choices[0].message.content
    formatted_prompt = (
        f"Relevant vocabulary: {vocabulary_response}\n"
        f"Relevant narrative features: {features_response}\n"
        f"User prompt: {query}\n"
    )
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": (
                    f"{language_handling_subprompt}"
                    "You are the writer for a storytelling AI that can generate children's stories based on a given prompt."
                    "You should take the user input and generate a new story based on it."
                    "The story should be appropriate for children and should be creative and engaging."
                    "You should return BOTH a title and a story in the following format:\n\n"
                    "TITLE: [Your creative, unique title for the story]\n\n"
                    "STORY: [The story content]\n\n"
                    "The title should be creative, unique, and descriptive - avoid generic titles like 'The Dragon' or 'Space Adventure'."
                    "Instead, use specific, imaginative titles like 'Sparky the Fire-Breathing Friend' or 'Journey to the Purple Moon'."
                    "Do not include phrases like 'Once upon a time' in the title."
                    "Limit the story to 100 words."
                ),
            },
            {
                "role": "user",
                "content": formatted_prompt,
            }
        ],
        model=model,
    )

    response = chat_completion.choices[0].message.content
    # logging the words, features, query, and response to the db's prompt_data table
    add_to_prompt_table(
        features=features_response,
        vocabulary=vocabulary_response,
        user_prompt=query,
        model_response=response
    )

    # Parse the response to extract title and story
    try:
        # Split by the STORY: marker
        parts = response.split("STORY:", 1)

        # Extract title from the first part
        title_part = parts[0].strip()
        title = title_part.replace("TITLE:", "").strip()
        
        # Extract story from the second part (if it exists)
        story = parts[1].strip() if len(parts) > 1 else response

        # If we couldn't parse properly, just return the original response
        if not title or not story:
            return response

        # Store the title in a global variable or database for later use
        # For now, we'll just return the story, but we'll modify app.py to handle the title

        return {"title": title, "story": story}
    except:
        # If parsing fails, return the original response
        return {"title": "New Story", "story": response}


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
    existing_title = "Continued Story"
    for message in reversed(conversation_history):
        if message.sender_type == SenderType.MODEL and message.code in [2, 3]:
            # Check if the content has a title format
            if "TITLE:" in message.content and "STORY:" in message.content:
                parts = message.content.split("STORY:", 1)
                title_part = parts[0].strip()
                existing_title = title_part.replace("TITLE:", "").strip()
                existing_story = parts[1].strip()
            else:
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
                    f"{language_handling_subprompt}"
                    "You are the writer for a storytelling AI that can generate children's stories based on a given prompt."
                    "You should take the existing story and the new user input to generate an extended story."
                    "The story should be appropriate for children and should be creative and engaging."
                    "You should return BOTH the original title and the extended story in the following format:\n\n"
                    "TITLE: [Keep the original title]\n\n"
                    "STORY: [The extended story content]\n\n"
                    "Limit the extended part of the story to 100 words."
                    "This should be a full rewrite of the story, not just a continuation, but it should be consistent with the existing story."
                ),
            },
            {
                "role": "user",
                "content": f"Existing Title: {existing_title}\nExisting Story: {existing_story}\nNew Input: {query}",
            }
        ],
        model=model,
    )

    response = chat_completion.choices[0].message.content

    # Parse the response to extract title and story
    try:
        # Split by the STORY: marker
        parts = response.split("STORY:", 1)

        # Extract title from the first part
        title_part = parts[0].strip()
        title = title_part.replace("TITLE:", "").strip()

        # Extract story from the second part (if it exists)
        story = parts[1].strip() if len(parts) > 1 else response

        # If we couldn't parse properly, just return the original response
        if not title or not story:
            return response

        # Return both title and story
        return {"title": title, "story": story}
    except:
        # If parsing fails, return the original response
        return {"title": existing_title, "story": response}
