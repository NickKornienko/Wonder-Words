import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import 'auth/auth_provider.dart' as app_auth;

class StoryService {
  // Base URL for the Flask backend
  // Note: This should be updated to the actual backend URL when deployed
  final String baseUrl = 'http://localhost:5000';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Store the BuildContext for later use
  BuildContext? _context;

  // Set the BuildContext
  void setContext(BuildContext context) {
    print("Setting context in StoryService: $context");
    _context = context;
  }

  // Check if the context is initialized
  bool get isContextInitialized => _context != null;

  // Helper method to get the current user's ID token
  Future<String> _getIdToken() async {
    if (_context == null) {
      throw Exception('Context not initialized');
    }

    // Get the AuthProvider instance
    final authProvider =
        Provider.of<app_auth.AuthProvider>(_context!, listen: false);

    // Check if the user is a child
    if (authProvider.isChild) {
      // For child accounts, we need to use the child token
      // This token should be stored in the AuthProvider when the child logs in
      final childToken = await _getChildToken();
      if (childToken != null) {
        return childToken;
      }
    }

    // For parent accounts, use Firebase authentication
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

  // Helper method to get the child token
  Future<String?> _getChildToken() async {
    if (_context == null) {
      throw Exception('Context not initialized');
    }

    try {
      // Get the AuthProvider instance
      final authProvider =
          Provider.of<app_auth.AuthProvider>(_context!, listen: false);

      // Check if the user is a child
      if (authProvider.isChild) {
        // Get the child token from the AuthProvider
        return authProvider.childToken;
      }

      return null;
    } catch (e) {
      print('Error getting child token: $e');
      return null;
    }
  }

  // Method to get a new story
  Future<Map<String, dynamic>> getNewStory(String query, String userId) async {
    if (_context == null) {
      throw Exception('Context not initialized');
    }

    try {
      final String idToken = await _getIdToken();
      final authProvider =
          Provider.of<app_auth.AuthProvider>(_context!, listen: false);

      // Use the correct endpoint based on the account type
      final endpoint =
          authProvider.isChild ? 'handle_child_request' : 'handle_request';

      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
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
    if (_context == null) {
      throw Exception('Context not initialized');
    }

    try {
      final String idToken = await _getIdToken();
      final authProvider =
          Provider.of<app_auth.AuthProvider>(_context!, listen: false);

      // Use the correct endpoint based on the account type
      final endpoint =
          authProvider.isChild ? 'handle_child_request' : 'handle_request';

      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
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
    if (_context == null) {
      throw Exception('Context not initialized');
    }

    try {
      final String idToken = await _getIdToken();
      final authProvider =
          Provider.of<app_auth.AuthProvider>(_context!, listen: false);

      // Use the correct endpoint based on the account type
      final endpoint = authProvider.isChild
          ? 'confirm_child_new_story'
          : 'confirm_new_story';

      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
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
    if (_context == null) {
      throw Exception('Context not initialized');
    }

    try {
      final String idToken = await _getIdToken();
      final authProvider =
          Provider.of<app_auth.AuthProvider>(_context!, listen: false);

      // Use the correct endpoint based on the account type
      final endpoint = authProvider.isChild
          ? 'get_child_conversations'
          : 'get_conversations';

      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
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
    if (_context == null) {
      throw Exception('Context not initialized');
    }

    try {
      final String idToken = await _getIdToken();
      final authProvider =
          Provider.of<app_auth.AuthProvider>(_context!, listen: false);

      // Use the correct endpoint based on the account type
      final endpoint = authProvider.isChild
          ? 'get_child_conversation_messages'
          : 'get_conversation_messages';

      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint?conversation_id=$conversationId'),
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
