import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoinsService {
  static final _firestore = FirebaseFirestore.instance;

  static User get _user {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not logged in.');
    return user;
  }

  static DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_user.uid);

  /// Creates profile with 20 free coins if it doesn't exist yet.
  static Future<int> ensureProfile() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      await _doc.set({
        'coins': 20,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return 20;
    }
    return (snap.data()?['coins'] as num?)?.toInt() ?? 0;
  }

  /// Returns current coin balance.
  static Future<int> getCoins() async {
    final snap = await _doc.get();
    if (!snap.exists) return ensureProfile();
    return (snap.data()?['coins'] as num?)?.toInt() ?? 0;
  }

  /// Spends 1 coin. Returns false if not enough coins.
  static Future<bool> spendCoin() async {
    bool success = false;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_doc);
      final coins = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
      if (coins <= 0) { success = false; return; }
      tx.update(_doc, {'coins': FieldValue.increment(-1)});
      success = true;
    });
    return success;
  }

  /// Adds coins after purchase (called locally after Play verification).
  static Future<int> addCoins(int amount) async {
    await _doc.update({'coins': FieldValue.increment(amount)});
    final snap = await _doc.get();
    return (snap.data()?['coins'] as num?)?.toInt() ?? 0;
  }
}
