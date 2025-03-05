import 'package:flutter/material.dart';

class StoryRequest {
  //final int userId;
  //final String userPrompt;
  //final int id;
  final String title;
  final String prompt;
  final String vocabulary;

  const StoryRequest({required this.title, required this.prompt, required this.vocabulary});

  // Factory constructor to create a StoryRequest object from JSON
  factory StoryRequest.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'title': String title,'prompt': String prompt, 'vocabulary': String vocabulary} => StoryRequest(
        title: title,
        prompt: prompt,
        vocabulary: vocabulary,
      ),
      _ => throw const FormatException('Failed to load story.'),
    };
  }

  //simple print function to verify variables after StoryRequest.fromJson
  void printStoryRequest(StoryRequest storyRequest) {
    print('Title: ${storyRequest.title}');
    print('Genre: ${storyRequest.prompt}');
    print('Vocabulary: ${storyRequest.vocabulary}');
  }

  // format template of the StoryRequest object
  String formatStoryRequest(String promptType) {
      String starterPrompt = '''<|im_start|>user\n 
              Below is an instruction (story request) that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

              ### Title: 
              ${title}
              
              ### Instruction (story request):
              ${prompt}

              ### Word List:
              ${vocabulary} 
              <|im_end|>\n

              <|im_start|>assistant\n 
              Here's the full story titled '${title}' about '${prompt}' with the vocabulary '${vocabulary}':
              ### Story:

          ''';
      if (promptType == 'story-generation') {
        return starterPrompt;
    }
    if (promptType == 'prompt-generation') {
        return '''<|im_start|>user\n 
            Below is an instruction (prompt evaluation request) that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.
            
            ## Instruction (prompt evaluation request):
            Identify any potential issues with the prompt. Is it clear, specific, and relevant to the task? Edit this prompt for improvement.

            ## Prompt: 
            ${starterPrompt}

            <|im_end|>\n

            <|im_start|>assistant\n 
            The new and improved prompt 

            ## Prompt:

        ''';
    }
    return '';
  }
}



