import os
from dotenv import load_dotenv
from openai import OpenAI


load_dotenv()
client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
)


def gpt_4o_mini(query):
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a storying telling AI that can generate children's stories based on a given prompt. "
                    "If the prompt is not related to a story you should respond with \"I don't think I can help with that.\" "
                    "The stories should be longer than 300 words."
                ),
            },
            {
                "role": "user",
                "content": query,
            }
        ],
        model="gpt-4o-mini",
    )

    return chat_completion.choices[0].message.content
