import 'package:flutter/material.dart';
import '../services/coins_service.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  int _coins = 0;

  @override
  void initState() { super.initState(); _loadCoins(); }

  Future<void> _loadCoins() async {
    final c = await CoinsService.getCoins();
    if (mounted) setState(() => _coins = c);
  }

  Future<void> _buyCoinsPack(int amount, String label) async {
    await CoinsService.addCoins(amount);
    await _loadCoins();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label unlocked! 🎉'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D071F), Color(0xFF1A0A35), Color(0xFF0C0E21)])),
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 12, 20, 0), child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
            const Expanded(child: Text('Get Coins', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [const Text('🪙', style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text('$_coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
            ),
          ])),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]), borderRadius: BorderRadius.circular(24)),
              child: Column(children: [
                const Text('🪙', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('$_coins Coins Left', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Each reply costs 1 coin', style: TextStyle(color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Text('Coin Packs', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            _buildPlanCard(emoji: '🌱', title: 'Starter Pack', coins: 20, price: '₹29', description: '20 replies', isPopular: false),
            const SizedBox(height: 14),
            _buildPlanCard(emoji: '🔥', title: 'Rizz Pack', coins: 60, price: '₹69', description: '60 replies — Best Value!', isPopular: true),
            const SizedBox(height: 14),
            _buildPlanCard(emoji: '👑', title: 'Guru Pack', coins: 150, price: '₹149', description: '150 replies', isPopular: false),
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Text('Daily Plans', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            _buildPlanCard(emoji: '⚡', title: 'Daily Unlimited', coins: 30, price: '₹19/day', description: '30 coins daily', isPopular: false),
            const SizedBox(height: 14),
            _buildPlanCard(emoji: '💎', title: 'Monthly Unlimited', coins: 999, price: '₹299/mo', description: 'Unlimited replies — Best Deal!', isPopular: true),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.white38, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Payments coming soon. Tap any plan to try it free during beta!', style: TextStyle(color: Colors.white38, fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 20),
          ]))),
        ])),
      ),
    );
  }

  Widget _buildPlanCard({required String emoji, required String title, required int coins, required String price, required String description, required bool isPopular}) {
    return Stack(children: [
      GestureDetector(
        onTap: () => _buyCoinsPack(coins, title),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isPopular ? const Color(0xFFFF5B63) : Colors.white.withOpacity(0.1), width: isPopular ? 2 : 1),
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(price, style: const TextStyle(color: Color(0xFFFF5B63), fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('+$coins 🪙', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ]),
        ),
      ),
      if (isPopular) Positioned(top: -1, right: 16, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]), borderRadius: BorderRadius.circular(10)),
        child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      )),
    ]);
  }
}
