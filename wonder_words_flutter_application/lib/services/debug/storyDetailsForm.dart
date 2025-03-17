import 'package:flutter/material.dart';
import 'package:wonder_words_flutter_application/storyDetails.dart';

class StoryDetailsForm extends StatefulWidget {
  @override
  _StoryDetailsFormState createState() => _StoryDetailsFormState();
}

class _StoryDetailsFormState extends State<StoryDetailsForm> {
  Map<String, dynamic> _submittedData = {};
  String _model = 'llama'; // Add a state variable for the model
  String _taskType = 'story-generation'; // Add a state variable for the task type
  String _responseText = '';
  String _promptResponseText = '';
  String _formattedRequestText = '';
  final TextEditingController _additionalTextController = TextEditingController(); // Add a controller for the new text box

  void _handleSubmittedData(Map<String, dynamic> onSubmit) {
    setState(() {
      _submittedData = onSubmit;
      print('Submitted Data: $_submittedData');
    });
  }

  void _handleResponse(String response, String formattedRequest, String promptResponse) {
    setState(() {
      // only set if the parameters are not null or empty strings
      if (response.isNotEmpty) {
        _responseText = response;
      }
      if (formattedRequest.isNotEmpty) {
        _formattedRequestText = formattedRequest;
      }
      if (promptResponse.isNotEmpty) {
        _promptResponseText = promptResponse;
      }
    });
  }

  void _toggleModel() {
    setState(() {
      _model = _model == 'llama' ? 'gpt' : 'llama';
      print('Model changed to: $_model');
    });
  }

  void _toggleTaskType() {
    setState(() {
      _taskType = _taskType == 'story-generation' ? 'prompt-generation' : 'story-generation';
      print('Task type changed to: $_taskType');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Wonder Words"),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text('llama'),
                      Switch(
                        value: _model == 'gpt',
                        onChanged: (value) {
                          _toggleModel();
                        },
                      ),
                      const Text('gpt'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text('story-generation'),
                      Switch(
                        value: _taskType == 'prompt-generation',
                        onChanged: (value) {
                          _toggleTaskType();
                        },
                      ),
                      const Text('prompt-generation'),
                    ],
                  ),
                  StoryDetails(
                    onSubmit: _handleSubmittedData,
                    model: _model,
                    taskType: _taskType,
                    onResponse: _handleResponse,
                  ),
                  const SizedBox(height: 20),
                  if (_taskType == 'story-generation') ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 200.0, // Adjust the max height as needed
                      ),
                      child: SingleChildScrollView(
                        child: TextField(
                          controller: TextEditingController(text: _responseText),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Story Response',
                          ),
                          readOnly: true,
                          maxLines: null,
                        ),
                      ),
                    ),
                  ],
                  if (_taskType == 'prompt-generation') ...[
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 200.0, // Adjust the max height as needed
                      ),
                      child: SingleChildScrollView(
                        child: TextField(
                          controller: TextEditingController(text: _formattedRequestText),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'AI Prompt',
                          ),
                          readOnly: true,
                          maxLines: null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 200.0, // Adjust the max height as needed
                      ),
                      child: SingleChildScrollView(
                        child: TextField(
                          controller: TextEditingController(text: _promptResponseText),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Prompt Response',
                          ),
                          readOnly: true,
                          maxLines: null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
