import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/groq_service.dart';
import '../services/coins_service.dart';
import 'plans_screen.dart';

class ReplierScreen extends StatefulWidget {
  final String mood;
  final String emoji;
  const ReplierScreen({required this.mood, required this.emoji, super.key});
  @override
  State<ReplierScreen> createState() => _ReplierScreenState();
}

class _ReplierScreenState extends State<ReplierScreen> {
  final _controller = TextEditingController();
  String _reply = '';
  bool _isLoading = false;
  bool _copied = false;
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final c = await CoinsService.getCoins();
    if (mounted) setState(() => _coins = c);
  }

  Future<void> _generate() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) { _showSnack('Paste the message you received first!'); return; }
    if (_coins <= 0) { _showNoCoinsDialog(); return; }
    setState(() { _isLoading = true; _reply = ''; _copied = false; });
    try {
      final spent = await CoinsService.spendCoin();
      if (!spent) { _showNoCoinsDialog(); return; }
      final result = await GroqService.generateReply(message: msg, mood: widget.mood);
      await _loadCoins();
      if (mounted) setState(() => _reply = result);
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyReply() {
    Clipboard.setData(ClipboardData(text: _reply));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copied = false); });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  void _showNoCoinsDialog() {
    setState(() => _isLoading = false);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A0A35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('🪙 Out of Coins!', style: TextStyle(color: Colors.white)),
      content: const Text('You\'ve used all your coins. Get more to keep generating rizz replies!', style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Maybe Later', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5B63), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())).then((_) => _loadCoins()); },
          child: const Text('Get Coins'),
        ),
      ],
    ));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0D071F), Color(0xFF1A0A35), Color(0xFF0C0E21)]),
        ),
        child: SafeArea(child: Column(children: [
          _buildAppBar(),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
            _buildMoodBadge(),
            const SizedBox(height: 24),
            _buildInputArea(),
            const SizedBox(height: 20),
            _buildGenerateButton(),
            if (_isLoading) ...[const SizedBox(height: 40), _buildLoadingWidget()],
            if (_reply.isNotEmpty && !_isLoading) ...[const SizedBox(height: 24), _buildReplyCard()],
          ]))),
        ])),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(padding: const EdgeInsets.fromLTRB(8, 12, 20, 0), child: Row(children: [
      IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
      const Expanded(child: Text('Rizz Guru', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [const Text('🪙', style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text('$_coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
      ),
    ]));
  }

  Widget _buildMoodBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFF5B63).withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Text('${widget.mood} Mode', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Paste the message you received:', style: TextStyle(color: Colors.white54, fontSize: 13))),
        TextField(controller: _controller, style: const TextStyle(color: Colors.white, fontSize: 15), maxLines: 5, minLines: 3,
          decoration: InputDecoration(hintText: 'E.g. "Hey, what are you doing tonight? 😊"', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16))),
      ]),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(width: double.infinity, child: GestureDetector(
      onTap: _isLoading ? null : _generate,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: const Color(0xFFFF5B63).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('⚡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(_isLoading ? 'Generating...' : 'Generate Reply  (-1 🪙)',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    ));
  }

  Widget _buildReplyCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFF5B63).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('✨ Your Reply', style: TextStyle(color: Colors.white54, fontSize: 13)),
          const Spacer(),
          GestureDetector(onTap: _generate, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [Icon(Icons.refresh, color: Colors.white54, size: 14), SizedBox(width: 4), Text('Retry', style: TextStyle(color: Colors.white54, fontSize: 12))]),
          )),
        ]),
        const SizedBox(height: 14),
        Text(_reply, style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.6)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: GestureDetector(
          onTap: _copyReply,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: _copied ? Colors.green : const Color(0xFFFF5B63), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_copied ? Icons.check : Icons.copy, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(_copied ? 'Copied!' : 'Copy Reply', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(children: [
      const CircularProgressIndicator(color: Color(0xFFFF5B63)),
      const SizedBox(height: 16),
      Text('Cooking up your ${widget.mood.toLowerCase()} reply... 🔥', style: const TextStyle(color: Colors.white54)),
    ]);
  }
}
