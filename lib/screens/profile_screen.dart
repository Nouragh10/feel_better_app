// PATH: lib/screens/profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fs = FirestoreService();
  final _displayCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        final snap = await _fs.getUser(u.uid);
        final data = snap.data();
        _displayCtrl.text =
            (data?['displayName'] as String?)?.trim().isNotEmpty == true
                ? data!['displayName']
                : (u.displayName ?? '');
        _usernameCtrl.text =
            (data?['username'] as String?) ?? _suggestUsername(u.email);
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _suggestUsername(String? email) {
    final raw = (email ?? '').trim();
    if (raw.isEmpty || !raw.contains('@')) return '';
    final local = raw.split('@').first;
    return local.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '').toLowerCase();
  }

  Future<void> _save() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final display = _displayCtrl.text.trim().isEmpty
        ? (u.displayName ?? 'Anonymous')
        : _displayCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a username')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _fs.upsertUser(
        uid: u.uid,
        displayName: display,
        username: username,
        photoUrl: u.photoURL,
        providerIds: u.providerData.map((p) => p.providerId).toList(),
        email: u.email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Couldn’t save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');

      final cur = FirebaseAuth.instance.currentUser;

      // Link if anonymous, otherwise sign in
      if (cur != null && cur.isAnonymous) {
        if (kIsWeb) {
          await cur.linkWithPopup(provider);
        } else {
          await cur.linkWithProvider(provider);
        }
      } else {
        if (kIsWeb) {
          await FirebaseAuth.instance.signInWithPopup(provider);
        } else {
          await FirebaseAuth.instance.signInWithProvider(provider);
        }
      }

      // Upsert user doc after sign-in
      final u = FirebaseAuth.instance.currentUser!;
      await _fs.upsertUser(
        uid: u.uid,
        displayName: u.displayName ?? 'Anonymous',
        username: _suggestUsername(u.email),
        photoUrl: u.photoURL,
        providerIds: u.providerData.map((p) => p.providerId).toList(),
        email: u.email,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      _displayCtrl.clear();
      _usernameCtrl.clear();
      if (!mounted) return;
      setState(() {}); // refresh UI
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Signed out')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Couldn’t sign out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: u == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Sign in to create your profile'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _signInWithGoogle,
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Continue with Google'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage:
                                  (u.photoURL != null) ? NetworkImage(u.photoURL!) : null,
                              child: (u.photoURL == null)
                                  ? Text(
                                      (u.displayName ?? 'A')[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),

                            // ---- Name + daily streak chip + email (live via stream)
                            Expanded(
                              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(u.uid)
                                    .snapshots(),
                                builder: (ctx, snap) {
                                  final data = snap.data?.data() ?? const {};
                                  final display =
                                      (data['displayName'] as String?)?.trim().isNotEmpty == true
                                          ? (data['displayName'] as String)
                                          : (u.displayName ?? 'Anonymous');
                                  final daily = (data['dailyCurrentStreak'] as int?) ?? 0;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              display,
                                              style: Theme.of(context).textTheme.titleMedium,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InputChip(
                                            avatar: const Icon(Icons.local_fire_department, size: 18),
                                            label: Text('$daily'),
                                            onPressed: () {},
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(u.email ?? 'No email',
                                          style: Theme.of(context).textTheme.bodyMedium),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Signed in with ${u.providerData.isNotEmpty ? u.providerData.first.providerId : 'unknown'}',
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            TextButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Sign out'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _displayCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            hintText: 'e.g., noura',
                          ),
                        ),
                        const SizedBox(height: 16),

                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_saving ? 'Saving…' : 'Save profile'),
                        ),

                        const SizedBox(height: 24),
                        Divider(color: cs.outlineVariant),
                        const SizedBox(height: 8),

                        Text('UID: ${u.uid}',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
            ),
    );
  }
}
