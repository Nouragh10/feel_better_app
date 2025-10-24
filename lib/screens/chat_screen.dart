import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'shared_activity_screen.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String chatId; // Unique ID for this friendship chat

  const ChatScreen({
    Key? key,
    required this.friendId,
    required this.friendName,
    required this.chatId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': _currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _initiateSharedActivity(String activityType) async {
    // Create an activity session
    final activityRef = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('activities')
        .add({
      'type': activityType,
      'initiatorId': _currentUserId,
      'status': 'pending', // pending, in_progress, completed
      'createdAt': FieldValue.serverTimestamp(),
      'participants': {
        _currentUserId: {'completed': false, 'joinedAt': null},
        widget.friendId: {'completed': false, 'joinedAt': null},
      },
    });

    // Send activity invitation message
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'type': 'activity_invite',
      'activityType': activityType,
      'activityId': activityRef.id,
      'senderId': _currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.friendName),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final streak = data?['streak'] ?? 0;
                return Text(
                  '🔥 $streak day streak',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChatInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Start your conversation!',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try doing a mental health exercise together',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final type = message['type'] as String;

                    if (type == 'text') {
                      return _buildTextMessage(message);
                    } else if (type == 'activity_invite') {
                      return _buildActivityInvite(message);
                    } else if (type == 'activity_completed') {
                      return _buildActivityCompleted(message);
                    }

                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),

          // Activity selector button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Do together:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                _buildActivityButton('Breathing', Icons.air, Colors.cyan),
                const SizedBox(width: 8),
                _buildActivityButton('Yoga', Icons.self_improvement, Colors.purple),
                const SizedBox(width: 8),
                _buildActivityButton('Video', Icons.play_circle, Colors.orange),
              ],
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Send a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: Colors.cyan,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityButton(String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () => _initiateSharedActivity(label.toLowerCase()),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildTextMessage(Map<String, dynamic> message) {
    final isMe = message['senderId'] == _currentUserId;
    final text = message['text'] as String;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.cyan : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityInvite(Map<String, dynamic> message) {
    final activityType = message['activityType'] as String;
    final activityId = message['activityId'] as String;
    final isMe = message['senderId'] == _currentUserId;

    IconData icon;
    Color color;
    String displayName;

    switch (activityType) {
      case 'breathing':
        icon = Icons.air;
        color = Colors.cyan;
        displayName = 'Breathing Exercise';
        break;
      case 'yoga':
        icon = Icons.self_improvement;
        color = Colors.purple;
        displayName = 'Yoga Session';
        break;
      case 'video':
        icon = Icons.play_circle;
        color = Colors.orange;
        displayName = 'Calm Video';
        break;
      default:
        icon = Icons.favorite;
        color = Colors.pink;
        displayName = activityType;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? 'You invited $displayName' : '${widget.friendName} invited $displayName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete together to grow your streak! 🔥',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .collection('activities')
                .doc(activityId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final activity = snapshot.data!.data() as Map<String, dynamic>?;
              if (activity == null) return const SizedBox.shrink();

              final participants = activity['participants'] as Map<String, dynamic>;
              final myStatus = participants[_currentUserId] as Map<String, dynamic>;
              final friendStatus = participants[widget.friendId] as Map<String, dynamic>;
              
              final iCompleted = myStatus['completed'] as bool;
              final friendCompleted = friendStatus['completed'] as bool;

              if (iCompleted && friendCompleted) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Both completed! 🎉',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildParticipantStatus(
                          'You',
                          iCompleted,
                          color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildParticipantStatus(
                          widget.friendName,
                          friendCompleted,
                          color,
                        ),
                      ),
                    ],
                  ),
                  if (!iCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _joinActivity(activityId, activityType),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Start Activity'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantStatus(String name, bool completed, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: completed ? color.withOpacity(0.2) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: completed ? color : Colors.grey,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                color: completed ? color : Colors.grey.shade600,
                fontWeight: completed ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCompleted(Map<String, dynamic> message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration, color: Colors.green),
          SizedBox(width: 8),
          Text(
            'Activity completed together! Streak +1 🔥',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinActivity(String activityId, String activityType) async {
    // Navigate to the shared activity screen
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SharedActivityScreen(
          chatId: widget.chatId,
          activityId: activityId,
          activityType: activityType,
          friendName: widget.friendName,
        ),
      ),
    );

    if (completed == true) {
      // Mark this user as completed
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('activities')
          .doc(activityId)
          .update({
        'participants.$_currentUserId.completed': true,
        'participants.$_currentUserId.completedAt': FieldValue.serverTimestamp(),
      });

      // Check if both completed
      await _checkBothCompleted(activityId);
    }
  }

  Future<void> _checkBothCompleted(String activityId) async {
    final activityDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('activities')
        .doc(activityId)
        .get();

    final activity = activityDoc.data() as Map<String, dynamic>;
    final participants = activity['participants'] as Map<String, dynamic>;
    
    final allCompleted = participants.values.every(
      (p) => (p as Map<String, dynamic>)['completed'] == true,
    );

    if (allCompleted) {
      // Increment streak
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .set({
        'streak': FieldValue.increment(1),
        'lastActivityDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send completion message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'type': 'activity_completed',
        'activityId': activityId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update activity status
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('activities')
          .doc(activityId)
          .update({'status': 'completed'});
    }
  }

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final streak = data?['streak'] ?? 0;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Friendship Stats',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('🔥', streak.toString(), 'Day Streak'),
                    _buildStat('💜', 'Together', 'Growing'),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Complete mental health exercises together to grow your streak!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}