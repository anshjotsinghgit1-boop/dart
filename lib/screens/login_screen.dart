import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/coins_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _googleLoad = false;
  bool _obscure = true;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _fadeCtrl.reset();

    setState(() {
      _isLogin = !_isLogin;
    });

    _fadeCtrl.forward();
  }

  void _showSnack(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? const Color(0xFF4CAF50)
            : const Color(0xFFFF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';

      case 'wrong-password':
        return 'Incorrect password.';

      case 'invalid-credential':
        return 'Incorrect email or password.';

      case 'email-already-in-use':
        return 'An account already exists with this email.';

      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';

      case 'invalid-email':
        return 'That email address is invalid.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'network-request-failed':
        return 'Please check your internet connection.';

      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';

      default:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Makes sure that the user has a Firestore profile.
  ///
  /// Coins are created only by the backend when the profile does not exist.
  /// Existing users keep their current balance.
  Future<void> _goHome(User user) async {
  if (!mounted) return;
  final name = user.displayName?.trim().isNotEmpty == true
      ? user.displayName!.trim()
      : user.email?.split('@').first ?? 'User';

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => HomeScreen(userName: name)),
  );

  // Sync profile in background
  Future(() async {
    for (int i = 0; i < 10; i++) {
      try {
        await CoinsService.ensureProfile();
        return;
      } catch (_) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  });
  }
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );

        final user = credential.user;

        if (user == null) {
          _showSnack('Could not sign in. Please try again.');
          return;
        }

        await _goHome(user);
      } else {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );

        final user = credential.user;

        if (user == null) {
          _showSnack('Could not create your account.');
          return;
        }

        await user.updateDisplayName(_nameCtrl.text.trim());
        await user.reload();

        final updatedUser = FirebaseAuth.instance.currentUser;

        if (updatedUser == null) {
          _showSnack('Could not load your new account.');
          return;
        }

        await _goHome(updatedUser);
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyError(e.code));
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _googleSignIn() async {
    if (_googleLoad) return;

    setState(() {
      _googleLoad = true;
    });

    try {
      final googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user == null) {
        _showSnack('Could not sign in with Google.');
        return;
      }

      await _goHome(user);
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyError(e.code));
        } catch (e) {
      _showSnack('DEBUG Google: ${e.runtimeType}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _googleLoad = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter your email above first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      _showSnack(
        'Reset email sent! Check your inbox.',
        success: true,
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyError(e.code));
    } catch (_) {
      _showSnack('Could not send the reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D071F),
              Color(0xFF1A0A35),
              Color(0xFF0C0E21),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    _buildLogo(),

                    const SizedBox(height: 36),

                    _buildToggle(),

                    const SizedBox(height: 28),

                    if (!_isLogin) ...[
                      _buildField(
                        _nameCtrl,
                        'Full Name',
                        Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your name';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildField(
                      _emailCtrl,
                      'Email Address',
                      Icons.mail_outline_rounded,
                      type: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter email';
                        }

                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    _buildField(
                      _passCtrl,
                      'Password',
                      Icons.lock_outline_rounded,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: const Color(0xFF8A8AAA),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscure = !_obscure;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Min 6 characters';
                        }

                        return null;
                      },
                    ),

                    if (!_isLogin) ...[
                      const SizedBox(height: 16),

                      _buildField(
                        _confirmCtrl,
                        'Confirm Password',
                        Icons.lock_reset_outlined,
                        obscure: true,
                        validator: (value) {
                          if (value != _passCtrl.text) {
                            return "Passwords don't match";
                          }

                          return null;
                        },
                      ),
                    ],

                    if (_isLogin) ...[
                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _forgotPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color(0xFFFF5B63),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    _buildSubmitButton(),

                    const SizedBox(height: 24),

                    _buildDivider(),

                    const SizedBox(height: 24),

                    _buildGoogleButton(),

                    const SizedBox(height: 32),

                    _buildSwitchRow(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF5B63),
                Color(0xFF9B22F9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5B63).withOpacity(0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '💬',
              style: TextStyle(fontSize: 38),
            ),
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'RizzGuru',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Master the art of the perfect reply',
          style: TextStyle(
            color: Color(0xFF8A8AAA),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          _toggleBtn('Sign In', true),
          _toggleBtn('Sign Up', false),
        ],
      ),
    );
  }

  Widget _toggleBtn(
    String label,
    bool loginMode,
  ) {
    final active = _isLogin == loginMode;

    return Expanded(
      child: GestureDetector(
        onTap: active ? null : _toggleMode,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [
                      Color(0xFFFF5B63),
                      Color(0xFF9B22F9),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : const Color(0xFF8A8AAA),
                fontWeight: active
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType type = TextInputType.text,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF8A8AAA),
            size: 20,
          ),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF5B63),
              Color(0xFF9B22F9),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5B63).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _isLogin
                      ? 'Sign In  ✨'
                      : 'Create Account  🚀',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _googleLoad ? null : _googleSignIn,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        child: Center(
          child: _googleLoad
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF5B63),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFFDB4437),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin
              ? "Don't have an account?  "
              : 'Already have an account?  ',
          style: const TextStyle(
            color: Color(0xFF8A8AAA),
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: _toggleMode,
          child: Text(
            _isLogin ? 'Sign Up' : 'Sign In',
            style: const TextStyle(
              color: Color(0xFFFF5B63),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
