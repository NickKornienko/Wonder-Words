import 'package:firebase_core/firebase_core.dart';

// This is a placeholder for Firebase configuration
// Replace with actual configuration from Firebase console
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Default configuration for development
    return const FirebaseOptions(
      apiKey: 'placeholder-api-key',
      appId: 'placeholder-app-id',
      messagingSenderId: 'placeholder-messaging-sender-id',
      projectId: 'placeholder-project-id',
    );
  }
}
