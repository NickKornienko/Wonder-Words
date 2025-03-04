import 'package:flutter/material.dart';
import 'package:wonder_words_flutter_application/storyInference.dart';
import 'package:wonder_words_flutter_application/storyRequest.dart';
import 'package:wonder_words_flutter_application/storyDetails.dart';
import 'dart:io';

class StoryDetailsForm extends StatefulWidget {
  //final Function(Map<String, dynamic>) onSubmit;

  //StoryDetailsForm({required this.onSubmit});
  @override
  _StoryDetailsFormState createState() => _StoryDetailsFormState();
}

class _StoryDetailsFormState extends State<StoryDetailsForm> {
   Map<String, dynamic> _submittedData = {};

  void _handleSubmittedData(Map<String, dynamic> onSubmit) {
    setState(() {
      _submittedData = onSubmit;
      print('Submitted Data: $_submittedData');
    });
  }

  String _model = 'llama';

  void _toggleModel() {
    setState(() {
      _model = _model == 'llama' ? 'gpt' : 'llama';
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
                  StoryDetails(onSubmit: _handleSubmittedData, model: _model),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
