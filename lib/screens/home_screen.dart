import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/coins_service.dart';
import 'replier_screen.dart';
import 'plans_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({required this.userName, super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _coins = 0;
  bool _coinsLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _moods = [
    {'label': 'Flirty',    'emoji': '😏', 'gradient': [const Color(0xFFFF5B63), const Color(0xFFFF8A80)]},
    {'label': 'Romantic',  'emoji': '💕', 'gradient': [const Color(0xFFE91E8C), const Color(0xFFFF4081)]},
    {'label': 'Funny',     'emoji': '😂', 'gradient': [const Color(0xFFFF9800), const Color(0xFFFFCC02)]},
    {'label': 'Savage',    'emoji': '🔥', 'gradient': [const Color(0xFFFF4444), const Color(0xFFFF6B35)]},
    {'label': 'Sweet',     'emoji': '🍯', 'gradient': [const Color(0xFFFFB347), const Color(0xFFFFD700)]},
    {'label': 'Sad',       'emoji': '💔', 'gradient': [const Color(0xFF7B68EE), const Color(0xFF9C88FF)]},
    {'label': 'Confident', 'emoji': '😎', 'gradient': [const Color(0xFF00BCD4), const Color(0xFF00E5FF)]},
    {'label': 'Cute',      'emoji': '🥰', 'gradient': [const Color(0xFFFF80AB), const Color(0xFFFF4081)]},
  ];

  @override
  void initState() {
    super.initState();
    _loadCoins();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCoins() async {
    if (mounted) setState(() => _coinsLoading = true);
    try {
      final c = await CoinsService.getCoins();
      if (mounted) setState(() {
        _coins = c;
        _coinsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _coinsLoading = false);
    }
  }

  void _openReplier(String mood, String emoji) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReplierScreen(mood: mood, emoji: emoji)));
    _loadCoins();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D071F), Color(0xFF1A0A35), Color(0xFF0C0E21)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildHeroBanner(),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Choose Your Vibe', Icons.mood_rounded),
                      const SizedBox(height: 14),
                      _buildMoodGrid(),
                      const SizedBox(height: 28),
                      _buildCoinsCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final firstName = widget.userName.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Open settings',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          firstName.isNotEmpty
                              ? firstName[0].toUpperCase()
                              : 'R',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A0A35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0D071F),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hey, $firstName 👋',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('What\'s the vibe today?',
                    style: TextStyle(color: Color(0xFF8A8AAA), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PlansScreen()))
                .then((_) => _loadCoins()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF5B63).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 5),
                  if (_coinsLoading)
                    const SizedBox(width: 20, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  else
                    Text('$_coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFF8A8AAA), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A0A4A), Color(0xFF1A1035)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFF5B63).withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFF9B22F9).withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5B63).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF5B63).withOpacity(0.4)),
                    ),
                    child: const Text('✨ AI-Powered Rizz',
                        style: TextStyle(color: Color(0xFFFF5B63), fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Never Run Out\nof Words Again',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.25)),
                  const SizedBox(height: 8),
                  const Text('Pick a vibe and get the\nperfect reply in seconds.',
                      style: TextStyle(color: Color(0xFF8A8AAA), fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF5B63).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))
                ],
              ),
              child: const Center(child: Text('💬', style: TextStyle(fontSize: 34))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5B63).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFFF5B63), size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMoodGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _moods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (ctx, i) => _MoodCard(
        mood: _moods[i],
        onTap: () => _openReplier(_moods[i]['label'] as String, _moods[i]['emoji'] as String),
      ),
    );
  }

  Widget _buildCoinsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('🪙', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_coins Coins Left',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  _coins > 0 ? 'Each reply costs 1 coin' : 'Out of coins — top up now!',
                  style: const TextStyle(color: Color(0xFF8A8AAA), fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()))
                .then((_) => _loadCoins()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF5B63).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: const Text('Top Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodCard extends StatefulWidget {
  final Map<String, dynamic> mood;
  final VoidCallback onTap;
  const _MoodCard({required this.mood, required this.onTap});
  @override
  State<_MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<_MoodCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.mood['label'] as String;
    final emoji = widget.mood['emoji'] as String;
    final gradients = widget.mood['gradient'] as List<Color>;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradients[0].withOpacity(0.18), gradients[1].withOpacity(0.07)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gradients[0].withOpacity(0.4), width: 1.2),
            boxShadow: [
              BoxShadow(color: gradients[0].withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -12,
                right: -12,
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: gradients[0].withOpacity(0.15)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(label,
                        style: TextStyle(color: gradients[0], fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Tap to rizz',
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
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
