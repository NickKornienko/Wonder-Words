class StoryRequest {
  //final int userId; 
  //final int storyId;
  final String title;
  final String prompt;
  final String vocabulary;
  final String language_subprompt = "Important: Respond to the user's input in the language they are using. Interpret their request in their language to make decisions to your instructions.";

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
              ${language_subprompt} 
              Below is a story request that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

              ### Title: 
              ${title}
              
              ### Story Request:
              ${prompt}

              ### Word List:
              ${vocabulary} 
              <|im_end|>\n

              <|im_start|>assistant\n 
              Here's the full story titled '${title}' about '${prompt}' with the vocabulary '${vocabulary}':
              ### Story:

          ''';
      String continuationPrompt = '''<|im_start|>user\n
              ${language_subprompt} 
              Below is a continuation story request that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

              ### Title: 
              ${title}
              
              ### Story Request:
              ${prompt}

              ### Word List:
              ${vocabulary} 
              <|im_end|>\n

              <|im_start|>assistant\n 
              Here's the continuation of the story titled '${title}' about '${prompt}' with the vocabulary '${vocabulary}':
              ### Story:

          ''';
      if (promptType == 'story-generation') {
        return starterPrompt;
      }
      else if (promptType == 'story-continuation') {
        return continuationPrompt;
      }
      if (promptType == 'prompt-generation') {
          return '''<|im_start|>user\n
              ${language_subprompt} 
              Below is a prompt evaluation request that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.
              Do not include any additional information or context in your response, and only provide the updated prompt. The goal is not to provide a story, but to improve the prompt.
              
              ## Instruction (prompt evaluation request):
              Identify any potential issues with the prompt. Is it clear, specific, and relevant to the task? Edit this prompt for improvement.

              ## Prompt for Evaluation: 
              ${starterPrompt}

              <|im_end|>\n

              <|im_start|>assistant\n 
              ## Prompt:

          ''';
      }
    return '';
  }
}



