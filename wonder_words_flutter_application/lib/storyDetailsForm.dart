import 'package:flutter/material.dart';
import 'package:wonder_words_flutter_application/storyInference.dart';
import 'package:wonder_words_flutter_application/storyResponse.dart';
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Wonder Words"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StoryDetails(onSubmit: _handleSubmittedData),
          ),
        ),
      ),
    );
  }

}
