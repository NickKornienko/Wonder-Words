import 'package:flutter/material.dart';

class StoryResponse {
  //final int userId;
  //final String userPrompt;
  //final int id;
  final String title;
  final String genre;
  final String vocabulary;

  const StoryResponse({required this.title, required this.genre, required this.vocabulary});

  factory StoryResponse.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'title': String title,'genre': String genre, 'vocabulary': String vocabulary} => StoryResponse(
        title: title,
        genre: genre,
        vocabulary: vocabulary,
      ),
      _ => throw const FormatException('Failed to load story.'),
    };
  }
}


