// PATH: lib/screens/challenges_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../services/challenge_service.dart';
import '../services/firestore_service.dart';

// Brand colours (mirrors main.dart)
const _cyan = Color(0xFF06B6D4);
const _purple = Color(0xFF8B5CF6);
const _coral = Color(0xFFFF6B9D);
const _bgDarkTop = Color(0xFF0B1120);
const _bgDarkMid = Color(0xFF0F172A);
const _bgDarkEnd = Color(0xFF1E293B);
const _bgLightTop = Color(0xFFF0F9FF);
const _bgLightMid = Color(0xFFFAFAFF);
const _bgLightEnd = Color(0xFFFFFFFF);
const _glassDark = Color(0xFF1A2332);
const _glassLight = Color(0xFFFEFEFE);

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  final _svc = ChallengeService();
  final _fs = FirestoreService();

  late TabController _tabs;
  String? _uid;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _initIdentity();
  }

  Future<void> _initIdentity() async {
    String? uid;
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      uid = FirebaseAuth.instance.currentUser?.uid;
    } on FirebaseAuthException catch (_) {
      // ignore auth errors here; we'll fall back to a local uid below
    } catch (_) {
      // ignore generic errors; we'll fall back to a local uid below
    }

    if (uid == null) {
      try {
        final sp = await SharedPreferences.getInstance();
        uid = sp.getString('local_uid');
        if (uid == null) {
          uid = const Uuid().v4();
          await sp.setString('local_uid', uid);
        }
      } catch (_) {
        uid = const Uuid().v4();
      }
    }

    if (!mounted) return;
    setState(() {
      _uid = uid;
      _initializing = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_cyan, _purple]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Challenges'),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Invites'),
            Tab(text: 'Browse'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [_bgDarkTop, _bgDarkMid, _bgDarkEnd]
                : [_bgLightTop, _bgLightMid, _bgLightEnd],
          ),
        ),
        child: SafeArea(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ActiveTab(uid: _uid, svc: _svc, isDark: isDark, cs: cs),
              _InvitesTab(uid: _uid, svc: _svc, isDark: isDark, cs: cs),
              _BrowseTab(uid: _uid, svc: _svc, fs: _fs, isDark: isDark, cs: cs),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ACTIVE TAB — challenges you're currently doing
// ============================================================================

class _ActiveTab extends StatelessWidget {
  const _ActiveTab(
      {required this.uid,
      required this.svc,
      required this.isDark,
      required this.cs});

  final String? uid;
  final ChallengeService svc;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(child: Text('Sign in to see challenges'));
    }
    return StreamBuilder<List<SharedChallenge>>(
      stream: svc.activeChallengesStream(uid!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final challenges = (snap.data ?? [])
            .where((c) => c.status == 'active')
            .toList();
        if (challenges.isEmpty) {
          return _EmptyState(
            icon: Icons.emoji_events_outlined,
            message: 'No active challenges yet.',
            sub: 'Browse templates or invite a friend to start one.',
            isDark: isDark,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: challenges.length,
          itemBuilder: (_, i) => _ActiveChallengeCard(
            challenge: challenges[i],
            uid: uid!,
            svc: svc,
            isDark: isDark,
            cs: cs,
          ),
        );
      },
    );
  }
}

class _ActiveChallengeCard extends StatelessWidget {
  const _ActiveChallengeCard({
    required this.challenge,
    required this.uid,
    required this.svc,
    required this.isDark,
    required this.cs,
  });

  final SharedChallenge challenge;
  final String uid;
  final ChallengeService svc;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final template = templateById(challenge.templateId);
    if (template == null) return const SizedBox.shrink();

    final day = challenge.currentDay;
    final task = template.dailyTasks[day];
    final myDone = challenge.isCompleted(day, uid);
    final partnerId = uid == challenge.initiatorUid
        ? challenge.partnerUid
        : challenge.initiatorUid;
    final partnerDone = challenge.isCompleted(day, partnerId);
    final bothDone = challenge.bothCompleted(day);
    final progress = challenge.sharedDaysCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark, cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Text(template.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: cs.onSurface)),
                  Text('Day ${day + 1} of 7',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Progress pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$progress/7 done',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ),
          ]),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress / 7,
              backgroundColor: cs.outline.withOpacity(0.15),
              color: cs.primary,
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 16),

          // Today's task
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: cs.primary.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's task",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.primary.withOpacity(0.7))),
                const SizedBox(height: 4),
                Text(task,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: cs.onSurface.withOpacity(0.85))),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Partner status + mark done
          Row(children: [
            // Me
            _PersonStatus(
                label: 'You',
                done: myDone,
                color: cs.primary),
            const SizedBox(width: 8),
            // Partner
            _PersonStatus(
                label: 'Friend',
                done: partnerDone,
                color: _purple),
            const Spacer(),
            if (!myDone)
              FilledButton(
                onPressed: () async {
                  await svc.markDayComplete(
                    challengeId: challenge.id,
                    dayIndex: day,
                    uid: uid,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(partnerDone
                          ? '🎉 Both of you completed day ${day + 1}!'
                          : '✅ Day ${day + 1} marked done!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                child: const Text('Done today ✓'),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('✓ Done',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981))),
              ),
          ]),

          if (bothDone) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🎉 Both of you did it today!',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF10B981))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonStatus extends StatelessWidget {
  const _PersonStatus(
      {required this.label, required this.done, required this.color});
  final String label;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
              color: done ? color : color.withOpacity(0.3), width: 2),
        ),
        child: done
            ? Icon(Icons.check, color: color, size: 13)
            : null,
      ),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: done ? color : color.withOpacity(0.5))),
    ]);
  }
}

// ============================================================================
// INVITES TAB — pending challenge invites
// ============================================================================

class _InvitesTab extends StatelessWidget {
  const _InvitesTab(
      {required this.uid,
      required this.svc,
      required this.isDark,
      required this.cs});

  final String? uid;
  final ChallengeService svc;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(child: Text('Sign in to see invites'));
    }
    return StreamBuilder<List<SharedChallenge>>(
      stream: svc.incomingInvitesStream(uid!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final invites = snap.data ?? [];
        if (invites.isEmpty) {
          return _EmptyState(
            icon: Icons.mark_email_unread_outlined,
            message: 'No pending invites.',
            sub: 'When a friend invites you to a challenge it shows up here.',
            isDark: isDark,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: invites.length,
          itemBuilder: (_, i) => _InviteCard(
            challenge: invites[i],
            svc: svc,
            isDark: isDark,
            cs: cs,
          ),
        );
      },
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard(
      {required this.challenge,
      required this.svc,
      required this.isDark,
      required this.cs});

  final SharedChallenge challenge;
  final ChallengeService svc;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final template = templateById(challenge.templateId);
    if (template == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(isDark, cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(template.emoji,
                style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: cs.onSurface)),
                  Text('7-day challenge',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(template.description,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: cs.onSurface.withOpacity(0.7))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await svc.declineChallenge(challenge.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Challenge declined'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.outline.withOpacity(0.4)),
                  foregroundColor: cs.onSurface.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  await svc.acceptChallenge(challenge.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '🎉 ${template.title} starts today!'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Accept 🎉'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ============================================================================
// BROWSE TAB — pick a template and invite a friend
// ============================================================================

class _BrowseTab extends StatefulWidget {
  const _BrowseTab(
      {required this.uid,
      required this.svc,
      required this.fs,
      required this.isDark,
      required this.cs});

  final String? uid;
  final ChallengeService svc;
  final FirestoreService fs;
  final bool isDark;
  final ColorScheme cs;

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
  String? _selectedTemplateId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pick a 7-day challenge',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: widget.cs.onSurface,
                  )),
          const SizedBox(height: 4),
          Text('You and a friend do one small thing every day.',
              style: TextStyle(
                  fontSize: 13,
                  color: widget.cs.onSurface.withOpacity(0.5))),
          const SizedBox(height: 16),
          ...kChallengeTemplates.map((t) => _TemplateCard(
                template: t,
                selected: _selectedTemplateId == t.id,
                isDark: widget.isDark,
                cs: widget.cs,
                onTap: () =>
                    setState(() => _selectedTemplateId = t.id),
              )),
          if (_selectedTemplateId != null) ...[
            const SizedBox(height: 8),
            _InviteFriendPanel(
              templateId: _selectedTemplateId!,
              uid: widget.uid,
              svc: widget.svc,
              fs: widget.fs,
              isDark: widget.isDark,
              cs: widget.cs,
              onSent: () => setState(() => _selectedTemplateId = null),
            ),
          ],
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  final ChallengeTemplate template;
  final bool selected;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(isDark ? 0.18 : 0.08)
              : (isDark
                  ? _glassDark.withOpacity(0.4)
                  : _glassLight.withOpacity(0.6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary.withOpacity(0.6)
                : (isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.07)),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(children: [
          Text(template.emoji,
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: selected ? cs.primary : cs.onSurface)),
                const SizedBox(height: 3),
                Text(template.description,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: cs.onSurface.withOpacity(0.55))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            color: selected ? cs.primary : cs.onSurface.withOpacity(0.25),
            size: 22,
          ),
        ]),
      ),
    );
  }
}

class _InviteFriendPanel extends StatefulWidget {
  const _InviteFriendPanel({
    required this.templateId,
    required this.uid,
    required this.svc,
    required this.fs,
    required this.isDark,
    required this.cs,
    required this.onSent,
  });

  final String templateId;
  final String? uid;
  final ChallengeService svc;
  final FirestoreService fs;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onSent;

  @override
  State<_InviteFriendPanel> createState() => _InviteFriendPanelState();
}

class _InviteFriendPanelState extends State<_InviteFriendPanel> {
  String? _selectedFriendUid;
  String? _selectedFriendName;
  bool _sending = false;
  List<Map<String, dynamic>> _friends = [];
  bool _loadingFriends = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    if (widget.uid == null) return;
    try {
      final snap = await FirestoreService()
          .getFriends(widget.uid!)
          .first;
      if (mounted) {
        setState(() {
          _friends = snap;
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = templateById(widget.templateId)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.cs.primary.withOpacity(widget.isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: widget.cs.primary.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite a friend to "${template.title}"',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: widget.cs.primary)),
          const SizedBox(height: 12),
          if (_loadingFriends)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ))
          else if (_friends.isEmpty)
            Text(
                'Add friends first to invite them to a challenge.',
                style: TextStyle(
                    fontSize: 13,
                    color: widget.cs.onSurface.withOpacity(0.5)))
          else ...[
            Text('Select a friend:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.cs.onSurface.withOpacity(0.6))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _friends.map((f) {
                final fUid = f['uid'] as String? ?? '';
                final fName =
                    f['username'] as String? ?? f['displayName'] as String? ?? 'Friend';
                final sel = _selectedFriendUid == fUid;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedFriendUid = fUid;
                    _selectedFriendName = fName;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? widget.cs.primary.withOpacity(0.15)
                          : widget.cs.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? widget.cs.primary.withOpacity(0.6)
                            : widget.cs.outline.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      fName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? widget.cs.primary
                            : widget.cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: (_selectedFriendUid == null || _sending)
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        try {
                          await widget.svc.sendChallenge(
                            fromUid: widget.uid!,
                            toUid: _selectedFriendUid!,
                            templateId: widget.templateId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                              content: Text(
                                  '💌 Challenge sent to $_selectedFriendName!'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ));
                            widget.onSent();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content:
                                  Text('Could not send invite. Try again.'),
                            ));
                          }
                        } finally {
                          if (mounted) setState(() => _sending = false);
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: widget.cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'Sending...' : 'Send invite'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// SHARED HELPERS
// ============================================================================

BoxDecoration _cardDecoration(bool isDark, ColorScheme cs) => BoxDecoration(
      color: isDark ? _glassDark.withOpacity(0.4) : _glassLight.withOpacity(0.7),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          blurRadius: 20,
          spreadRadius: -6,
          offset: const Offset(0, 6),
          color: isDark
              ? Colors.black.withOpacity(0.25)
              : cs.primary.withOpacity(0.07),
        ),
      ],
    );

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
    required this.isDark,
  });

  final IconData icon;
  final String message;
  final String sub;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: cs.onSurface.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.onSurface.withOpacity(0.5))),
            const SizedBox(height: 8),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.35))),
          ],
        ),
      ),
    );
  }
}