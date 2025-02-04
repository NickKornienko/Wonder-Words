from app import app, handle_request
from db.db import db

# Ensure the app context is available
with app.app_context():
    # Call the add_conversation function
    result = handle_request("Tell me a story about dragons")
    print(result)

    
