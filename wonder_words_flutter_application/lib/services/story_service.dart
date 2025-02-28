import 'dart:convert';
import 'package:http/http.dart' as http;

class StoryService {
  // Base URL for the Flask backend
  // Note: This should be updated to the actual backend URL when deployed
  final String baseUrl = 'http://localhost:5000';

  // Method to get a new story
  Future<Map<String, dynamic>> getNewStory(String query, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/handle_request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get story: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }

  // Method to add to an existing story
  Future<Map<String, dynamic>> addToStory(
      String query, String userId, String conversationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/handle_request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'user_id': userId,
          'conversation_id': conversationId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to add to story: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }

  // Method to confirm a new story when there's an existing conversation
  Future<Map<String, dynamic>> confirmNewStory(
      String query, String userId, String conversationId, String confirmation) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/confirm_new_story'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': query,
          'user_id': userId,
          'conversation_id': conversationId,
          'confirmation': confirmation,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to confirm new story: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }
}
