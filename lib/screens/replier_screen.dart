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

class _ReplierScreenState extends State<ReplierScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  String _reply = '';
  bool _isLoading = false;
  bool _copied = false;
  int _coins = 0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadCoins();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
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
    _fadeCtrl.reset(); _slideCtrl.reset();

    try {
      final spent = await CoinsService.spendCoin();
      if (!spent) { _showNoCoinsDialog(); return; }
      final result = await GroqService.generateReply(message: msg, mood: widget.mood);
      await _loadCoins();
      if (mounted) {
        setState(() => _reply = result);
        _fadeCtrl.forward();
        _slideCtrl.forward();
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyReply() {
    Clipboard.setData(ClipboardData(text: _reply));
    setState(() => _copied = true);
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFFF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showNoCoinsDialog() {
    setState(() => _isLoading = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🪙 Out of Coins!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'You\'ve used all your coins.\nGet more to keep generating rizz replies!',
          style: TextStyle(color: Color(0xFF8A8AAA), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: Color(0xFF8A8AAA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5B63),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen()))
                  .then((_) => _loadCoins());
            },
            child: const Text('Get Coins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
                      _buildMoodBadge(),
                      const SizedBox(height: 24),
                      _buildInputArea(),
                      const SizedBox(height: 20),
                      _buildGenerateButton(),
                      if (_isLoading) ...[const SizedBox(height: 40), _buildLoadingWidget()],
                      if (_reply.isNotEmpty && !_isLoading) ...[
                        const SizedBox(height: 24),
                        _buildReplyCard(),
                      ],
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              '${widget.emoji} ${widget.mood} Rizz',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text('$_coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5B63).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF5B63).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.mood + ' Mode',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const Text('AI will match this vibe',
                  style: TextStyle(color: Color(0xFF8A8AAA), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Paste Their Message',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Drop what they sent you below',
            style: TextStyle(color: Color(0xFF8A8AAA), fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _controller,
            maxLines: 5,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
            decoration: InputDecoration(
              hintText: 'e.g. "hey, what are you up to tonight?" 😏',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear_rounded, color: Colors.white.withOpacity(0.3), size: 18),
                onPressed: () => _controller.clear(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _generate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: _isLoading
              ? LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade700])
              : const LinearGradient(colors: [Color(0xFFFF5B63), Color(0xFF9B22F9)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: _isLoading
              ? []
              : [BoxShadow(color: const Color(0xFFFF5B63).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(
                _isLoading ? 'Generating...' : 'Generate ${widget.mood} Reply',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2A0A4A), Color(0xFF1A1035)]),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFF5B63).withOpacity(0.4), width: 2),
          ),
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5B63)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Crafting your perfect rizz...', style: TextStyle(color: Color(0xFF8A8AAA), fontSize: 14)),
        const SizedBox(height: 6),
        const Text('AI is thinking 🧠', style: TextStyle(color: Color(0xFF8A8AAA), fontSize: 12)),
      ],
    );
  }

  Widget _buildReplyCard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A0A4A), Color(0xFF1A1035)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFF5B63).withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF9B22F9).withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5B63).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF5B63).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Text(widget.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text('Your Rizz Reply',
                            style: const TextStyle(color: Color(0xFFFF5B63), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _copyReply,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _copied
                            ? const Color(0xFF4CAF50).withOpacity(0.15)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _copied
                              ? const Color(0xFF4CAF50).withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            color: _copied ? const Color(0xFF4CAF50) : Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _copied ? 'Copied!' : 'Copy',
                            style: TextStyle(
                              color: _copied ? const Color(0xFF4CAF50) : Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0x22FFFFFF), height: 1),
              const SizedBox(height: 16),
              Text(_reply, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _generate,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFFFF5B63).withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Try Another Reply 🔄',
                      style: TextStyle(color: Color(0xFFFF5B63), fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
