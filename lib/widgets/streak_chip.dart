// PATH: lib/widgets/streak_chip.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StreakChip extends StatelessWidget {
  final String myUid;
  final String friendUid;
  final FirestoreService fs;

  const StreakChip({
    super.key,
    required this.myUid,
    required this.friendUid,
    required this.fs,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: fs.streakPairStream(myUid, friendUid),
      builder: (context, snap) {
        final data = snap.data?.data();
        final count = (data?['currentStreak'] as int?) ?? 0;
        return InputChip(
          avatar: const Icon(Icons.local_fire_department, size: 18),
          label: Text('$count'),
          onPressed: () {},
        );
      },
    );
  }
}
