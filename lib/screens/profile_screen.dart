// PATH: lib/screens/profile_screen.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../widgets/badges_section.dart';
import '../screens/settings_screen.dart' show ghostMode;
import 'personalization_setup_screen.dart';

const kPrimaryCyan = Color(0xFF06B6D4);
const kSecondaryPurple = Color(0xFF8B5CF6);
const kAccentCoral = Color(0xFFFF6B9D);

const kBgLightTop = Color(0xFFF0F9FF);
const kBgLightMid = Color(0xFFFAFAFF);
const kBgLightEnd = Color(0xFFFFFFFF);

const kBgDarkTop = Color(0xFF0B1120);
const kBgDarkMid = Color(0xFF0F172A);
const kBgDarkEnd = Color(0xFF1E293B);

const kGlassLight = Color(0xFFFEFEFE);
const kGlassDark = Color(0xFF1A2332);

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

  String? _localAvatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
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
      _snack('Pick a username');
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
      _snack('Profile saved ✓');
    } catch (e) {
      if (!mounted) return;
      _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
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
    } catch (e) {
      if (!mounted) return;
      _snack('Could not sign out: $e');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      _snack('Sign in to set a profile photo');
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 768,
          maxHeight: 768,
          imageQuality: 85);
      if (file == null) {
        setState(() => _uploadingAvatar = false);
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      String ct = 'image/jpeg';
      final lower = file.name.toLowerCase();
      if (lower.endsWith('.png')) ct = 'image/png';
      if (lower.endsWith('.webp')) ct = 'image/webp';
      final ext = lower.split('.').last;
      final path = 'avatars/${u.uid}/avatar.$ext';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(bytes, SettableMetadata(contentType: ct));
      final url = await ref.getDownloadURL();
      await u.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set(
          {'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser!.reload();
      _localAvatarUrl = url;
      if (!mounted) return;
      _snack('Profile photo updated ✓');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _snack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          // Ghost mode toggle lives here now
          ValueListenableBuilder<bool>(
            valueListenable: ghostMode,
            builder: (_, isOn, __) => TextButton.icon(
              onPressed: () => ghostMode.value = !ghostMode.value,
              icon: Icon(
                isOn
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: isOn
                    ? cs.onSurface.withOpacity(0.4)
                    : cs.onSurface.withOpacity(0.7),
              ),
              label: Text(
                isOn ? 'Ghost ON' : 'Ghost OFF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOn
                      ? cs.onSurface.withOpacity(0.4)
                      : cs.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [kBgDarkTop, kBgDarkMid, kBgDarkEnd]
                : [kBgLightTop, kBgLightMid, kBgLightEnd],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : u == null
                  ? _buildSignInView(cs, isDark)
                  : _buildProfileView(u, cs, isDark),
        ),
      ),
    );
  }

  Widget _buildSignInView(ColorScheme cs, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [kGlassDark.withOpacity(0.7), kGlassDark.withOpacity(0.5)]
                  : [
                      kGlassLight.withOpacity(0.9),
                      kGlassLight.withOpacity(0.7)
                    ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.primary.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [cs.primary, cs.secondary]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text('Welcome!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Sign in to see your profile',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: cs.onSurface.withOpacity(0.6)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView(User u, ColorScheme cs, bool isDark) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
        final photoUrl =
            _localAvatarUrl ?? (data['photoUrl'] as String?) ?? u.photoURL;
        final daily = (data['dailyCurrentStreak'] as int?) ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ---- Profile card ----
              _glassCard(
                isDark: isDark,
                cs: cs,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      // Avatar
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                  colors: [cs.primary, cs.secondary]),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  color: cs.primary.withOpacity(0.3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? Text(
                                      (display.isNotEmpty ? display[0] : 'A')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 28))
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [cs.secondary, cs.tertiary]),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: 'Change photo',
                                onPressed: _uploadingAvatar
                                    ? null
                                    : _pickAndUploadAvatar,
                                icon: _uploadingAvatar
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.camera_alt_rounded,
                                        color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(display,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface),
                          textAlign: TextAlign.center),
                      if (uname.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('@$uname',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: cs.onSurface.withOpacity(0.6))),
                      ],
                      const SizedBox(height: 16),
                      // Streak chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            kAccentCoral.withOpacity(0.2),
                            kSecondaryPurple.withOpacity(0.2)
                          ]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: kAccentCoral.withOpacity(0.5),
                              width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              '$daily day streak',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: cs.outline.withOpacity(0.2)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.email_outlined,
                              size: 14,
                              color: cs.onSurface.withOpacity(0.4)),
                          const SizedBox(width: 6),
                          Text(u.email ?? 'No email',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ---- Badges ----
              _glassCard(
                isDark: isDark,
                cs: cs,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: const BadgesSection(),
                ),
              ),

              const SizedBox(height: 20),

              // ---- Edit profile ----
              _glassCard(
                isDark: isDark,
                cs: cs,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Profile',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _displayCtrl,
                        decoration: InputDecoration(
                          labelText: 'Display name',
                          prefixIcon: Icon(Icons.person_outline_rounded,
                              color: cs.primary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          hintText: 'e.g., noura',
                          prefixIcon: Icon(Icons.alternate_email_rounded,
                              color: cs.secondary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.save_rounded),
                          label:
                              Text(_saving ? 'Saving...' : 'Save changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PersonalizationSetupScreen(
                              isFirstTime: false))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.secondary.withOpacity(0.5)),
                    foregroundColor: cs.secondary,
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Edit My Preferences'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.error.withOpacity(0.5)),
                    foregroundColor: cs.error,
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),

              const SizedBox(height: 24),

              // ---- Journey / history ----
              _glassCard(
                isDark: isDark,
                cs: cs,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [cs.secondary, cs.tertiary]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.history_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text('My Journey',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildPersonalHistory(u.uid, cs, isDark),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _glassCard(
      {required bool isDark,
      required ColorScheme cs,
      required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [kGlassDark.withOpacity(0.7), kGlassDark.withOpacity(0.5)]
              : [kGlassLight.withOpacity(0.9), kGlassLight.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.primary.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            blurRadius: 32,
            spreadRadius: -4,
            offset: const Offset(0, 12),
            color: cs.primary.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPersonalHistory(
      String uid, ColorScheme cs, bool isDark) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _fs.entriesForRange(
        uid: uid,
        startInclusive: thirtyDaysAgo,
        endExclusive: now.add(const Duration(days: 1)),
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()));
        }

        final entries = snap.data ?? [];
        if (entries.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_awesome_outlined,
                    size: 48,
                    color: cs.onSurface.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('No moments yet',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.6))),
                const SizedBox(height: 6),
                Text('Your saved moments will appear here',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.45)),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        final grouped =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final e in entries) {
          final data = e.data();
          final ts =
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          grouped.putIfAbsent(_weekLabel(ts), () => []).add(e);
        }
        final weeks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: _statCard(
                        icon: Icons.calendar_today_rounded,
                        label: 'Last 30 days',
                        value: '${entries.length}',
                        color: cs.primary,
                        isDark: isDark)),
                const SizedBox(width: 12),
                Expanded(
                    child: _statCard(
                        icon: Icons.trending_up_rounded,
                        label: 'This week',
                        value:
                            '${grouped[weeks.first]?.length ?? 0}',
                        color: cs.secondary,
                        isDark: isDark)),
              ],
            ),
            const SizedBox(height: 24),
            ...weeks.map((week) {
              final we = grouped[week]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [cs.primary, cs.secondary],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(week,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      cs.onSurface.withOpacity(0.8))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${we.length}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onPrimaryContainer)),
                          ),
                        ],
                      ),
                    ),
                    ...we.map((e) =>
                        _entryCard(e.data(), cs, isDark)),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _statCard(
      {required IconData icon,
      required String label,
      required String value,
      required Color color,
      required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _entryCard(
      Map<String, dynamic> data, ColorScheme cs, bool isDark) {
    final mood = data['mood'] as String? ?? '';
    final suggestion = data['suggestion'] as String? ?? '';
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final timeStr =
        ts != null ? DateFormat('MMM d, h:mm a').format(ts) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    cs.primary.withOpacity(0.2),
                    cs.secondary.withOpacity(0.2)
                  ]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: cs.primary.withOpacity(0.4), width: 1),
                ),
                child: Text(mood,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
              ),
              const Spacer(),
              Text(timeStr,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.4))),
            ],
          ),
          const SizedBox(height: 10),
          Text(suggestion,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: cs.onSurface.withOpacity(0.75))),
        ],
      ),
    );
  }

  String _weekLabel(DateTime dt) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    if (dt.isAfter(startOfWeek)) return 'This week';
    final weekAgo = startOfWeek.subtract(const Duration(days: 7));
    if (dt.isAfter(weekAgo)) return 'Last week';
    final twoWeeksAgo = startOfWeek.subtract(const Duration(days: 14));
    if (dt.isAfter(twoWeeksAgo)) return '2 weeks ago';
    return '3+ weeks ago';
  }
}