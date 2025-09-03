// PATH: lib/services/friend_requests_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestsService {
  /// Writes the friendship doc for BOTH users:
  /// - sender sees {status: "pending",   direction: "outgoing"}
  /// - recipient sees {status: "incoming", direction: "incoming"}
  static Future<void> sendFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    final db = FirebaseFirestore.instance;
    final now = FieldValue.serverTimestamp();

    final senderDoc = db
        .collection('friendships')
        .doc(fromUid)
        .collection('friends')
        .doc(toUid);

    final recipientDoc = db
        .collection('friendships')
        .doc(toUid)
        .collection('friends')
        .doc(fromUid);

    final batch = db.batch();
    batch.set(senderDoc, {
      'status': 'pending',
      'direction': 'outgoing',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    batch.set(recipientDoc, {
      'status': 'incoming',
      'direction': 'incoming',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
