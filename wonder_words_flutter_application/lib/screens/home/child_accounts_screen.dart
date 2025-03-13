import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth/auth_provider.dart';
import '../../services/auth/auth_service.dart';

class ChildAccountsScreen extends StatefulWidget {
  const ChildAccountsScreen({Key? key}) : super(key: key);

  @override
  State<ChildAccountsScreen> createState() => _ChildAccountsScreenState();
}

class _ChildAccountsScreenState extends State<ChildAccountsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isCreating = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createChildAccount() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.createChildAccount(
          _nameController.text.trim(),
        );

        if (success && mounted) {
          setState(() {
            _isCreating = false;
            _nameController.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Child account created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          setState(() {
            _error = authProvider.error ?? 'Failed to create child account';
          });
        }
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Only parent accounts should access this screen
    if (!authProvider.isParent) {
      return const Center(
        child: Text('Only parent accounts can manage child accounts'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Accounts'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple[50]!,
              Colors.purple[100]!,
            ],
          ),
        ),
        child: Column(
          children: [
            // Child Accounts List
            Expanded(
              child: _buildChildAccountsList(),
            ),

            // Create Child Account Form
            if (_isCreating)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create Child Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Child Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Child\'s Name',
                          prefixIcon: const Icon(Icons.child_care),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name for the child';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isCreating = false;
                                      _nameController.clear();
                                      _error = null;
                                    });
                                  },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _createChildAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Create Account'),
                          ),
                        ],
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
          ],
        ),
      ),
      floatingActionButton: !_isCreating
          ? FloatingActionButton(
              heroTag: 'createChildAccount',
              onPressed: () {
                setState(() {
                  _isCreating = true;
                });
              },
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildChildAccountsList() {
    // This is a placeholder for the child accounts list
    // In a real implementation, you would fetch child accounts from the backend
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.family_restroom,
            size: 80,
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 24),
          const Text(
            'Child Accounts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create child accounts to let your children enjoy personalized stories.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No child accounts yet',
            style: TextStyle(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isCreating = true;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Child Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
