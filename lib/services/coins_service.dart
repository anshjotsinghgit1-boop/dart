import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoinsService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  static User get _currentUser {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    return user;
  }

  static DocumentReference<Map<String, dynamic>>
      get _userDocument {
    return _firestore
        .collection('users')
        .doc(_currentUser.uid);
  }

  /// Creates the user profile only if it does not already exist.
  ///
  /// Existing users keep their existing coin balance.
  /// New users receive 20 free coins once.
  static Future<int> ensureProfile() async {
    final result = await _functions
        .httpsCallable('ensureUserProfile')
        .call();

    final data = Map<String, dynamic>.from(
      result.data as Map,
    );

    return (data['coins'] as num?)?.toInt() ?? 0;
  }

  /// Reads the current balance from Firestore.
  static Future<int> getCoins() async {
    final snapshot = await _userDocument.get();

    if (!snapshot.exists) {
      return ensureProfile();
    }

    final data = snapshot.data();

    return (data?['coins'] as num?)?.toInt() ?? 0;
  }

  /// Spends one coin atomically on the server.
  ///
  /// Returns false if the user has no coins.
  static Future<bool> spendCoin() async {
    final result = await _functions
        .httpsCallable('spendCoin')
        .call();

    final data = Map<String, dynamic>.from(
      result.data as Map,
    );

    return data['success'] == true;
  }
}
