import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonder_words_flutter_application/storyInference.dart';
import 'package:wonder_words_flutter_application/storyResponse.dart';


class StoryDetails extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  StoryDetails({required this.onSubmit});

  @override
  _StoryDetailsState createState() => _StoryDetailsState();
}
//   to-do: final TextEditingController _idController = TextEditingController();
// to-do: final TextEditingController _userPromptController = TextEditingController();
class _StoryDetailsState extends State<StoryDetails> {
  final _formKey = GlobalKey<FormState>();

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      widget.onSubmit(_submittedData);
    }
  }
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _genreController = TextEditingController();
  final TextEditingController _vocabularyController = TextEditingController();
  Map<String, dynamic> _submittedData = {};

// to-do: read from user db table 'userId': _userIdController.text to _handleSubmit / buildContext
// to-do: read  from a request db table 'id': _idController.text, to _handleSubmit/buildContext
// to-do: write to the training/RLHF db a 'userPrompt' from template for inference input based on the user's input to the buildContext controller text


  void _handleSubmit() {
    setState(() {
      _submittedData = {
        'title': _titleController.text,
        'genre': _genreController.text,
        'vocabulary': _vocabularyController.text,
      };
    });
    //to-do: remove print statement and replace with a call to the API
    print('Submitted Data: $_submittedData');
    //WidgetsFlutterBinding.ensureInitialized();
    //final hfKey = await _loadApiKeyFromConfigFile('hf_token.json');

    //final openai = OpenAI(baseURL: 'https://zq0finoawyna397e.us-east-1.aws.endpoints.huggingface.cloud/v1/chat', apiKey: hfKey); // Replace with your actual key

    //final response = await openai.chatCompletionsCreate({
    //  "model": "tgi",
    //  "messages": [
    //    {"role": "user", "content": "Hi!"}
    //  ],
    //  'max_tokens': 150,
    //  'stream': false
    //});

    // Process the response (assuming it's a stream-like structure)
    //print(response);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Whats the title of your new story?',
          ),
        ),
        TextField(
          controller: _genreController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'What genre do you want this story to be?',
          ),
        ),
        TextField(
          controller: _vocabularyController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'What are some vocabulary words related to your story?',
          ),
        ),
        SizedBox(height: 16.0),
        ElevatedButton(
          onPressed: _handleSubmit,
          child: Text('Submit'),
        )
      ],
    );
  }
}