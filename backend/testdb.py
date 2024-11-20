from app import app, get_conversation, handle_request
from db.db import db

# Ensure the app context is available
with app.app_context():
    # Call the add_conversation function
    result = handle_request("Tell me a story about dragons")
    print(result)

    result = get_conversation(result["id"])
    print(result)
