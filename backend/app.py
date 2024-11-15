from flask import Flask, jsonify

app = Flask(__name__)


@app.route('/api/word', methods=['GET'])
def get_word():
    # Return a basic word as JSON
    return jsonify({"word": "Hello"}), 200


if __name__ == '__main__':
    app.run(debug=True)
