from app import app
import json
import os


def get_user_input(prompt):
    return input(prompt)


def clear_terminal():
    os.system('cls' if os.name == 'nt' else 'clear')


def main():
    with app.app_context():
        client = app.test_client()
        conversation_id = None
        while True:
            user_input = get_user_input("You: ")
            if user_input.lower() in ['exit', 'quit']:
                print("Exiting the chatbot. Goodbye!")
                break

            # Simulate a request to handle_request
            request_data = {
                "query": user_input,
                "user_id": "test_user"
            }
            if conversation_id:
                request_data["conversation_id"] = conversation_id

            response = client.post(
                '/handle_request', data=json.dumps(request_data), content_type='application/json')
            response_data = response.get_json()

            if response_data is None:
                print(
                    "Error: No response data received. The server might have encountered an error.")
                print(f"Response status code: {response.status_code}")
                print(f"Response data: {response.data.decode('utf-8')}")
                continue

            if "confirmation" in response_data:
                print(f"Bot: {response_data['confirmation']}")
                confirmation = get_user_input("You (y/n): ")
                confirmation_data = {
                    "query": user_input,
                    "user_id": "test_user",
                    "confirmation": confirmation
                }
                if conversation_id:
                    confirmation_data["conversation_id"] = conversation_id

                confirm_response = client.post(
                    '/confirm_new_story', data=json.dumps(confirmation_data), content_type='application/json')
                confirm_response_data = confirm_response.get_json()

                if confirm_response_data is None:
                    print(
                        "Error: No response data received. The server might have encountered an error.")
                    print(
                        f"Response status code: {confirm_response.status_code}")
                    print(
                        f"Response data: {confirm_response.data.decode('utf-8')}")
                    continue

                if confirmation.lower() == 'y':
                    clear_terminal()
                    print("Bot: New story initiated.")
                    conversation_id = confirm_response_data.get(
                        'conversation_id')
                    print(
                        f"Bot: {confirm_response_data.get('response', 'Error')}")
                else:
                    print(
                        f"Bot: {confirm_response_data.get('message', 'Error')}")
            else:
                print(
                    f"Bot: {response_data.get('response', response_data.get('message', 'Error'))}")
                conversation_id = response_data.get('conversation_id')


if __name__ == '__main__':
    main()
