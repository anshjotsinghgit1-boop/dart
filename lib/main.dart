import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const RizzGuruApp());
}

class RizzGuruApp extends StatelessWidget {
  const RizzGuruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rizz Guru',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0D071F),
        primaryColor: const Color(0xFFFF5B63),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

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
                  _buildForm(context),
                  const SizedBox(height: 16),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            if (!_isLogin) ...[
              _buildTextField(
                label: 'Full Name',
                hint: 'Riya Sharma',
                controller: _nameController,
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Naam 3 letters se chota nahi hona chahiye';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
            ],
            _buildTextField(
              label: 'Email',
              hint: 'rizzguru@example.com',
              controller: _emailController,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || !value.contains('@')) {
                  return 'Valid email daalo bhai';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _buildTextField(
              label: 'Password',
              hint: 'At least 8 characters',
              controller: _passwordController,
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Password kam se kam 8 characters ka hona chahiye';
                }
                return null;
              },
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 18),
              _buildTextField(
                label: 'Confirm Password',
                hint: 'Re-type password',
                controller: _confirmController,
                icon: Icons.lock_reset,
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Password match nahi kar raha';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: const Color(0xFFFF5B63),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : Text(
                      _actionLabel,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          cursorColor: const Color(0xFFFF5B63),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.76)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
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

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, size: 30, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Rizz Guru',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Hinglish AI reply wala app',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class AuthModeSwitcher extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onTap;

  const AuthModeSwitcher({required this.isLogin, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isLogin ? const Color(0xFFFF5B63) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isLogin ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: !isLogin ? const Color(0xFFFF5B63) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Sign Up',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !isLogin ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({required this.userName, super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _messageController = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Hi! Main Rizz Guru hoon. Kehna kya hai? Main abhi 100% hinglish style mein reply dunga.',
      isBot: true,
    ),
  ];

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isBot: false));
      _messages.add(_ChatMessage(
        text: 'Suna: "$text". Ab suno, tumhara reply aa raha hai... aaj scene full rizz wala hai! 😎',
        isBot: true,
      ));
      _messageController.clear();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Rizz Guru', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D071F), Color(0xFF240A4A), Color(0xFF0C0E21)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, ${widget.userName}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tumhara personal AI reply buddy, sirf Hinglish mein.',
                            style: TextStyle(color: Colors.white.withOpacity(0.72)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.chat, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(34),
                      topRight: Radius.circular(34),
                    ),
                  ),
                  child: ListView.builder(
                    itemCount: _messages.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: message.isBot ? Colors.white.withOpacity(0.1) : const Color(0xFFFF5B63),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(22),
                              topRight: const Radius.circular(22),
                              bottomLeft: Radius.circular(message.isBot ? 0 : 22),
                              bottomRight: Radius.circular(message.isBot ? 22 : 0),
                            ),
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.2,
                              height: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type karo koi bhi message...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                          border: InputBorder.none,
                        ),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    Material(
                      color: const Color(0xFFFF5B63),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _sendMessage,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isBot;

  _ChatMessage({required this.text, required this.isBot});
}
