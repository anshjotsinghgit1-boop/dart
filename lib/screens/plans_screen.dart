import 'package:flutter/material.dart';
import '../services/coins_service.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  int _currentCoins = 0;
  bool _purchasing = false;
  int? _purchasingIndex;

  final List<Map<String, dynamic>> _plans = [
    {
      'coins': 20,
      'label': 'Starter',
      'price': 'Free',
      'priceINR': null,
      'emoji': '🎁',
      'desc': 'Perfect to get started',
      'badge': null,
      'gradient': [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
      'free': true,
    },
    {
      'coins': 50,
      'label': 'Basic',
      'price': '₹49',
      'priceINR': 49,
      'emoji': '⚡',
      'desc': '50 rizz replies',
      'badge': null,
      'gradient': [const Color(0xFF00BCD4), const Color(0xFF00E5FF)],
      'free': false,
    },
    {
      'coins': 120,
      'label': 'Pro',
      'price': '₹99',
      'priceINR': 99,
      'emoji': '🚀',
      'desc': '120 rizz replies — best value',
      'badge': 'POPULAR',
      'gradient': [const Color(0xFFFF5B63), const Color(0xFF9B22F9)],
      'free': false,
    },
    {
      'coins': 300,
      'label': 'Guru',
      'price': '₹199',
      'priceINR': 199,
      'emoji': '👑',
      'desc': '300 replies — become the Guru',
      'badge': 'BEST DEAL',
      'gradient': [const Color(0xFFFFB347), const Color(0xFFFFD700)],
      'free': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final c = await CoinsService.getCoins();
    if (mounted) setState(() => _currentCoins = c);
  }

  Future<void> _purchase(int index, Map<String, dynamic> plan) async {
    setState(() { _purchasing = true; _purchasingIndex = index; });

    // Add coins (replace with real payment gateway later)
    await CoinsService.addCoins(plan['coins'] as int);
    await _loadCoins();

    if (mounted) {
      setState(() { _purchasing = false; _purchasingIndex = null; });
      _showSuccessDialog(plan);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(plan['emoji'] as String, style: const TextStyle(fontSize: 50)),
            const SizedBox(height: 16),
            Text('${plan['coins']} Coins Added!',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You now have $_currentCoins coins total.',
                style: const TextStyle(color: Color(0xFF8A8AAA), fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5B63),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Let\'s Rizz! 🔥', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
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
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildCurrentCoinsWidget(),
                      const SizedBox(height: 28),
                      _buildSectionHeader(),
                      const SizedBox(height: 16),
                      ..._plans.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildPlanCard(e.key, e.value),
                          )),
                      const SizedBox(height: 20),
                      _buildFooterNote(),
                      const SizedBox(height: 24),
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Get More Coins 🪙',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCoinsWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A0A4A), Color(0xFF1A1035)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFB347).withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347).withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text('🪙', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Balance', style: TextStyle(color: Color(0xFF8A8AAA), fontSize: 12)),
              const SizedBox(height: 4),
              Text('$_currentCoins Coins',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          if (_currentCoins <= 5)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.4)),
              ),
              child: const Text('Low!', style: TextStyle(color: Color(0xFFFF4444), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Text(
          'Choose a Pack',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        const Text(
          '1 coin = 1 reply',
          style: TextStyle(color: Color(0xFF8A8AAA), fontSize: 12),
        ),
      ],
    );
  }
