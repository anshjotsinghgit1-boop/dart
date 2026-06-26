import 'package:flutter/material.dart';
import '../widgets/brand_header.dart';
import '../widgets/auth_mode_switcher.dart';
import '../widgets/auth_form.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  String get _title => _isLogin ? 'Welcome Back' : 'Create Your Rizz';
  String get _subtitle => _isLogin
      ? 'Login karo aur apni personal Hinglish AI reply buddy pao.'
      : 'Signup karo aur Rizz Guru se baat shuru karo.';
  String get _actionLabel => _isLogin ? 'Login' : 'Sign Up';

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            userName: _isLogin ? _emailController.text : _nameController.text,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0D071F), Color(0xFF271B4E), Color(0xFF120A24)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandHeader(),
                  const SizedBox(height: 24),
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AuthModeSwitcher(isLogin: _isLogin, onTap: _toggleMode),
                  const SizedBox(height: 24),
                  AuthForm(
                    isLogin: _isLogin,
                    isLoading: _isLoading,
                    formKey: _formKey,
                    nameController: _nameController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    confirmController: _confirmController,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 16),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _toggleMode,
          child: Text(
            _isLogin ? 'Naya user? Signup karo' : 'Already registered? Login',
            style: TextStyle(color: Colors.white.withOpacity(0.74)),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const HomeScreen(userName: 'Rizz Lover'),
              ),
            );
          },
          child: Text(
            'Skip & explore',
            style: TextStyle(color: Colors.white.withOpacity(0.74)),
          ),
        ),
      ],
    );
  }
}
