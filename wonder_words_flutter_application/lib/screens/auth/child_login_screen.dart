import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth/auth_provider.dart';
import '../../services/auth/auth_service.dart';
import '../home/home_screen.dart';

class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({Key? key}) : super(key: key);

  @override
  State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        // Print debug information
        print('Attempting child login with:');
        print('Username: ${_usernameController.text.trim()}');
        print('PIN: ${_pinController.text.trim()}');

        // Call the backend API to authenticate the child
        final response = await http.post(
          Uri.parse('http://localhost:5000/child_login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': _usernameController.text.trim(),
            'pin': _pinController.text.trim(),
          }),
        );

        // Print response for debugging
        print('Response status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          // Parse the response
          final data = json.decode(response.body);
          final token = data['token'];
          final displayName = data['display_name'];
          final age = data['age'];

          // Update the AuthProvider with the child's authentication information
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);

          // Create a child user data object
          final childUserData = UserData(
            uid:
                'child-${DateTime.now().millisecondsSinceEpoch}', // Generate a temporary UID
            email: 'child@example.com', // Placeholder email
            displayName: displayName,
            accountType: AccountType.child,
            username: _usernameController.text.trim(),
            pin: _pinController.text.trim(),
            age: age,
          );

          // Set the user data in the AuthProvider
          authProvider.setChildUserData(childUserData, token);

          if (mounted) {
            // Navigate to the home screen
            Navigator.of(context).pushReplacementNamed('/home');
          }
        } else {
          // Handle authentication error
          final data = json.decode(response.body);
          setState(() {
            _error = data['error'] ?? 'Authentication failed';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _error = 'Connection error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple[300]!,
              Colors.purple[600]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo/Icon
                  const Icon(
                    Icons.auto_stories,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),

                  // App Name
                  const Text(
                    'Wonder Words',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // App Tagline
                  const Text(
                    'Stories just for you!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Login Card - More child-friendly design
                  Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.purple[50]!,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Fun header for kids
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.emoji_people,
                                  size: 32,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Welcome, Explorer!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.stars,
                                  size: 32,
                                  color: Colors.deepPurple,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter your magic words to begin',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.purple,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Username Field - Matching the PIN field style
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Your Name',
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                                prefixIcon: const Icon(
                                  Icons.person,
                                  color: Colors.deepPurple,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.purple,
                                    width: 3,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.purple[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // PIN Field - More kid-friendly design
                            TextFormField(
                              controller: _pinController,
                              decoration: InputDecoration(
                                labelText: 'Secret PIN',
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Colors.deepPurple,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Colors.purple,
                                    width: 3,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.purple[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                letterSpacing: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your secret PIN';
                                }
                                if (value.length != 4 ||
                                    int.tryParse(value) == null) {
                                  return 'PIN must be exactly 4 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Login Button - More child-friendly design
                            Container(
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple,
                                    Colors.deepPurple,
                                    Colors.indigo,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.5),
                                    spreadRadius: 1,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.login_rounded,
                                            size: 24,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Start Adventure!',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            // Error Message
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Parent Login Link
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: const Text(
                        'Parent Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
