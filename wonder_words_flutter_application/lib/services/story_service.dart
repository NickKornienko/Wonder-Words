import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation.dart';

class StoryService {
  // Base URL for the Flask backend
  // Note: This should be updated to the actual backend URL when deployed
  final String baseUrl = 'http://localhost:5000';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper method to get the current user's ID token
  Future<String> _getIdToken() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final String? token = await user.getIdToken();
    if (token == null) {
      throw Exception('Failed to get ID token');
    }
    return token;
  }

  // Method to get a new story
  Future<Map<String, dynamic>> getNewStory(String query, String userId) async {
    try {
      final String idToken = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/handle_request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'query': query,
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
      final String idToken = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/handle_request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'query': query,
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
  Future<Map<String, dynamic>> confirmNewStory(String query, String userId,
      String conversationId, String confirmation) async {
    try {
      final String idToken = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/confirm_new_story'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'query': query,
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

  // Method to get all conversations for the current user
  Future<List<Conversation>> getConversations() async {
    try {
      final String idToken = await _getIdToken();

      final response = await http.get(
        Uri.parse('$baseUrl/get_conversations'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> conversationsJson = data['conversations'];
        return conversationsJson
            .map((json) => Conversation.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to get conversations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }

  // Method to get all messages for a specific conversation
  Future<List<Message>> getConversationMessages(String conversationId) async {
    try {
      final String idToken = await _getIdToken();

      final response = await http.get(
        Uri.parse(
            '$baseUrl/get_conversation_messages?conversation_id=$conversationId'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> messagesJson = data['messages'];
        return messagesJson.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }
}
