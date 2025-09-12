// PATH: lib/screens/profile_screen.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _uploadingAvatar = false;

  // local override so the new image appears instantly
  String? _localAvatarUrl;

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
        photoUrl: _localAvatarUrl ?? u.photoURL,
        providerIds: u.providerData.map((p) => p.providerId).toList(),
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

      final u = FirebaseAuth.instance.currentUser!;
      await _fs.upsertUser(
        uid: u.uid,
        displayName: u.displayName ?? 'Anonymous',
        username: _suggestUsername(u.email),
        photoUrl: u.photoURL,
        providerIds: u.providerData.map((p) => p.providerId).toList(),
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
      _localAvatarUrl = null;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Signed out')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Couldn’t sign out: $e')));
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to set a profile photo')),
      );
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      // 1) Pick image
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 85,
      );
      if (file == null) {
        setState(() => _uploadingAvatar = false);
        return;
      }

      // 2) Read bytes + guess content type
      final Uint8List bytes = await file.readAsBytes();
      String ct = 'image/jpeg';
      final lower = (file.name).toLowerCase();
      if (lower.endsWith('.png')) ct = 'image/png';
      if (lower.endsWith('.webp')) ct = 'image/webp';
      final ext = lower.split('.').last;

      // 3) Upload to Storage at avatars/{uid}/avatar.<ext>
      final path = 'avatars/${u.uid}/avatar.$ext';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(bytes, SettableMetadata(contentType: ct));

      // 4) Get URL
      final url = await ref.getDownloadURL();

      // 5) Update Auth photoURL and user doc (so StreamBuilder picks it up)
      await u.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser!.reload();

      // 6) Update local state so it appears immediately
      _localAvatarUrl = url;

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
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
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                        final uname = (data['username'] as String?) ?? '';
                        final photoUrl = _localAvatarUrl ??
                            (data['photoUrl'] as String?) ??
                            u.photoURL;
                        final daily = (data['dailyCurrentStreak'] as int?) ?? 0;

                        return ListView(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar with edit overlay
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 36,
                                      backgroundImage: (photoUrl != null)
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: (photoUrl == null)
                                          ? Text(
                                              (display.isNotEmpty
                                                      ? display[0]
                                                      : 'A')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 20,
                                              ),
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      right: -4,
                                      bottom: -4,
                                      child: IconButton.filledTonal(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Change photo',
                                        onPressed: _uploadingAvatar
                                            ? null
                                            : _pickAndUploadAvatar,
                                        icon: _uploadingAvatar
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2),
                                              )
                                            : const Icon(Icons.edit),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Name + streak + email/provider
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              display,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InputChip(
                                            avatar: const Icon(
                                              Icons.local_fire_department,
                                              size: 18,
                                            ),
                                            label: Text('$daily'),
                                            onPressed: () {},
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(u.email ?? 'No email',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Signed in with ${u.providerData.isNotEmpty ? u.providerData.first.providerId : 'unknown'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
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
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label:
                                  Text(_saving ? 'Saving…' : 'Save profile'),
                            ),

                            const SizedBox(height: 24),
                            Text('UID: ${u.uid}',
                                style:
                                    Theme.of(context).textTheme.labelSmall),
                            if (uname.isNotEmpty)
                              Text('Username: @$uname',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall),
                          ],
                        );
                      },
                    ),
            ),
    );
  }
}
