// PATH: lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/firestore_service.dart';

// Import color constants from main.dart
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

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fs = FirestoreService();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final uid = userCredential.user?.uid;
      
      if (uid != null) {
        // Create user document if it doesn't exist
        try {
          final snap = await _fs.getUser(uid);
          final data = snap.data();
          if (data == null || data['username'] == null) {
            await _fs.upsertUser(
              uid: uid,
              displayName: 'Anonymous',
              username: 'user_${uid.substring(0, 6)}',
            );
          }
        } catch (_) {}
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Failed to sign in anonymously';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential;
      if (_isSignUp) {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Create user document for new user
        final uid = userCredential.user?.uid;
        if (uid != null) {
          try {
            final snap = await _fs.getUser(uid);
            final data = snap.data();
            if (data == null || data['username'] == null) {
              await _fs.upsertUser(
                uid: uid,
                displayName: userCredential.user?.displayName ?? 'User',
                username: 'user_${uid.substring(0, 6)}',
                email: email,
              );
            }
          } catch (_) {}
        }
      } else {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        default:
          message = e.message ?? 'Authentication failed';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.secondary],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 24,
                            spreadRadius: -4,
                            offset: const Offset(0, 8),
                            color: cs.primary.withOpacity(0.3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    Text(
                      'Welcome to Nearby',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find your next moment of calm',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Auth Card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark
                            ? kGlassDark.withOpacity(0.5)
                            : kGlassLight.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 24,
                            spreadRadius: -8,
                            offset: const Offset(0, 8),
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : cs.primary.withOpacity(0.08),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email/Password Form
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                            ),
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 24),

                          // Error message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: cs.errorContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.error.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: cs.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: cs.error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Sign In/Up Button
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _signInWithEmail,
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Toggle Sign In/Sign Up
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                      _errorMessage = null;
                                    });
                                  },
                            child: Text(
                              _isSignUp
                                  ? 'Already have an account? Sign in'
                                  : 'Don\'t have an account? Sign up',
                              style: TextStyle(
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: cs.outline.withOpacity(0.3))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: cs.outline.withOpacity(0.3))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Anonymous Sign In
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInAnonymously,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: cs.outline.withOpacity(0.5),
                          ),
                          foregroundColor: cs.onSurface,
                        ),
                        icon: const Icon(Icons.person_outline_rounded),
                        label: const Text('Continue as Guest'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
