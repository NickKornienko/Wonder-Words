import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AccountType { parent, child }

class UserData {
  final String uid;
  final String email;
  final String? displayName;
  final AccountType accountType;
  final String? parentUid; // Only for child accounts

  UserData({
    required this.uid,
    required this.email,
    this.displayName,
    required this.accountType,
    this.parentUid,
  });

  factory UserData.fromFirebaseUser(User user, AccountType type,
      {String? parentUid}) {
    return UserData(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      accountType: type,
      parentUid: parentUid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'accountType': accountType.toString(),
      'parentUid': parentUid,
    };
  }

  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      uid: map['uid'],
      email: map['email'],
      displayName: map['displayName'],
      accountType: map['accountType'] == 'AccountType.parent'
          ? AccountType.parent
          : AccountType.child,
      parentUid: map['parentUid'],
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserData> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('User is null after sign in');
      }

      // Get user data from secure storage
      final String? userDataJson = await _storage.read(key: user.uid);
      if (userDataJson == null) {
        // Default to parent account if not found
        final userData = UserData.fromFirebaseUser(user, AccountType.parent);
        await _saveUserData(userData);
        return userData;
      }

      // Parse the JSON string to a Map
      final Map<String, dynamic> userData = {};
      return UserData.fromMap(userData);
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  // Register with email and password (parent account)
  Future<UserData> registerParent(
      String email, String password, String displayName) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('User is null after registration');
      }

      // Update display name
      await user.updateDisplayName(displayName);

      // Create user data
      final userData = UserData.fromFirebaseUser(user, AccountType.parent);

      // Save user data
      await _saveUserData(userData);

      return userData;
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  // Create child account (linked to parent)
  Future<UserData> createChildAccount(
      String displayName, String parentUid) async {
    try {
      // Generate a unique email for the child (not visible to users)
      final String childEmail =
          'child_${DateTime.now().millisecondsSinceEpoch}@wonderwords.app';
      final String childPassword =
          'Child${DateTime.now().millisecondsSinceEpoch}';

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: childEmail,
        password: childPassword,
      );

      final User? user = result.user;
      if (user == null) {
        throw Exception('User is null after child account creation');
      }

      // Update display name
      await user.updateDisplayName(displayName);

      // Create user data
      final userData = UserData.fromFirebaseUser(
        user,
        AccountType.child,
        parentUid: parentUid,
      );

      // Save user data
      await _saveUserData(userData);

      return userData;
    } catch (e) {
      throw Exception('Failed to create child account: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Save user data to secure storage
  Future<void> _saveUserData(UserData userData) async {
    await _storage.write(
      key: userData.uid,
      value: userData.toMap().toString(),
    );
  }

  // Get user data from secure storage
  Future<UserData?> getUserData(String uid) async {
    final String? userDataJson = await _storage.read(key: uid);
    if (userDataJson == null) {
      return null;
    }

    // Parse the JSON string to a Map
    final Map<String, dynamic> userData = {};
    return UserData.fromMap(userData);
  }

  // Update user profile
  Future<void> updateProfile(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);

        // Update stored user data
        final userData = await getUserData(user.uid);
        if (userData != null) {
          final updatedUserData = UserData(
            uid: userData.uid,
            email: userData.email,
            displayName: displayName,
            accountType: userData.accountType,
            parentUid: userData.parentUid,
          );

          await _saveUserData(updatedUserData);
        }
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }
}
