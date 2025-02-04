import os
from dotenv import load_dotenv
from openai import OpenAI

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
                    "You should take the user input and decide what to do with it by returning the appropriate code, which is the inter only. Ex. 0, 1, 2, 3, 4, 5."
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


def add_to_story(query):
    return 0
