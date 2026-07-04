import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/coins_service.dart';
import 'replier_screen.dart';
import 'plans_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({required this.userName, super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _coins = 0;

  final List<Map<String, dynamic>> _moods = [
    {'label': 'Flirty', 'emoji': '😏', 'color': const Color(0xFFFF5B63)},
    {'label': 'Romantic', 'emoji': '💕', 'color': const Color(0xFFE91E8C)},
    {'label': 'Funny', 'emoji': '😂', 'color': const Color(0xFFFF9800)},
    {'label': 'Savage', 'emoji': '🔥', 'color': const Color(0xFFFF4444)},
    {'label': 'Sweet', 'emoji': '🍯', 'color': const Color(0xFFFFB347)},
    {'label': 'Sad', 'emoji': '💔', 'color': const Color(0xFF7B68EE)},
    {'label': 'Confident', 'emoji': '😎', 'color': const Color(0xFF00BCD4)},
    {'label': 'Cute', 'emoji': '🥰', 'color': const Color(0xFFFF80AB)},
  ];

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final c = await CoinsService.getCoins();
    if (mounted) setState(() => _coins = c);
  }

  void _openReplier(String mood, String emoji) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ReplierScreen(mood: mood, emoji: emoji)));
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
            children: [_buildTopBar(), Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 24),
                _buildHeroCard(),
                const SizedBox(height: 28),
                const Text('Choose Your Vibe', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildMoodGrid(),
                const SizedBox(height: 28),
                _buildCoinsCard(),
                const SizedBox(height: 24),
              ]),
            ))],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hey, ${widget.userName.split(' ').first} 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text('What\'s the vibe today?', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ])),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())).then((_) => _loadCoins()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Text('🪙', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text('$_coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.logout, color: Colors.white54, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFFFF5B63).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🔥 Rizz Guru', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        const Text('AI-Powered\nReply Generator', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2)),
        const SizedBox(height: 12),
        const Text('Pick a mood, paste the message you received, and get the perfect reply instantly.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: ['✨ AI Powered', '⚡ Instant', '💯 Hinglish'].map((t) =>
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11)),
          )).toList()),
      ]),
    );
  }

  Widget _buildMoodGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.5),
      itemCount: _moods.length,
      itemBuilder: (context, i) {
        final mood = _moods[i];
        return GestureDetector(
          onTap: () => _openReplier(mood['label'], mood['emoji']),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (mood['color'] as Color).withOpacity(0.4), width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(mood['emoji'], style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(mood['label'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildCoinsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(children: [
        const Text('🪙', style: TextStyle(fontSize: 40)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_coins coins remaining', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Each reply costs 1 coin. Get more with a plan.', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())).then((_) => _loadCoins()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('Get More', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}
