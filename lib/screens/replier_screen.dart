import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_reply_service.dart';
import '../services/coins_service.dart';
import 'plans_screen.dart';

class ReplierScreen extends StatefulWidget {
  final String mood;
  final String emoji;

  const ReplierScreen({
    required this.mood,
    required this.emoji,
    super.key,
  });

  @override
  State<ReplierScreen> createState() => _ReplierScreenState();
}

class _ReplierScreenState extends State<ReplierScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();

  String _reply = '';
  bool _isLoading = false;
  bool _copied = false;
  int _coins = 0;
  String _selectedTier = 'basic';

  final Map<String, Map<String, dynamic>> _tierConfig = {
    'basic': {
      'name': 'Basic',
      'cost': 1,
      'color': Color(0xFF00BCD4),
      'description': 'Standard AI reply',
      'enabled': true,
    },
    'smart': {
      'name': 'Smart',
      'cost': 3,
      'color': Color(0xFFFF9800),
      'description': 'Enhanced AI reply',
      'enabled': false,
    },
    'premium': {
      'name': 'Premium',
      'cost': 6,
      'color': Color(0xFFE91E63),
      'description': 'Best AI reply',
      'enabled': false,
    },
  };

  final List<Map<String, String>> _conversation = [];

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _loadCoins();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideCtrl,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCoins() async {
    try {
      final coins = await CoinsService.getCoins();

      if (mounted) {
        setState(() => _coins = coins);
      }
    } catch (error) {
      if (mounted) {
        _showSnack('Could not load coins: $error');
      }
    }
  }

  Future<void> _generate() async {
    final msg = _controller.text.trim();

    if (msg.isEmpty) {
      _showSnack('Paste the message you received first!');
      return;
    }

    final selectedTier = _tierConfig[_selectedTier];

    if (selectedTier == null) {
      _showSnack('Invalid AI tier.');
      return;
    }

    final isTierEnabled = selectedTier['enabled'] == true;

    if (!isTierEnabled) {
      _showSnack(
        '${selectedTier['name']} is not available yet.',
      );
      return;
    }

    final tierCost = selectedTier['cost'] as int;

    if (_coins < tierCost) {
      _showSnack(
        '${selectedTier['name']} requires $tierCost coins. You have $_coins.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _reply = '';
      _copied = false;
    });

    _fadeCtrl.reset();
    _slideCtrl.reset();

    try {
      final result = await AIReplyService.generateReply(
        tier: _selectedTier,
        message: msg,
        mood: widget.mood,
        conversation: List<Map<String, String>>.from(_conversation),
      );

      final aiReply = result['reply'] as String? ?? '';

      final remainingCoins =
          (result['remainingCoins'] as num?)?.toInt() ?? _coins;

      if (aiReply.trim().isEmpty) {
        throw Exception('AI returned an empty reply.');
      }

      _conversation.add({
        'role': 'user',
        'content': msg,
      });

      _conversation.add({
        'role': 'assistant',
        'content': aiReply,
      });

      if (_conversation.length > 8) {
        _conversation.removeRange(
          0,
          _conversation.length - 8,
        );
      }

      if (mounted) {
        setState(() {
          _reply = aiReply;
          _coins = remainingCoins;
        });

        _fadeCtrl.forward();
        _slideCtrl.forward();
      }
    } catch (error) {
      if (mounted) {
        _showSnack('Error: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyReply() {
    if (_reply.isEmpty) return;

    Clipboard.setData(
      ClipboardData(text: _reply),
    );

    setState(() => _copied = true);

    HapticFeedback.lightImpact();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFFF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showNoCoinsDialog() {
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          '🪙 Out of Coins!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'You\'ve used all your coins.\nGet more to keep generating rizz replies!',
          style: TextStyle(
            color: Color(0xFF8A8AAA),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Maybe Later',
              style: TextStyle(
                color: Color(0xFF8A8AAA),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5B63),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PlansScreen(),
                ),
              ).then((_) => _loadCoins());
            },
            child: const Text(
              'Get Coins',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
            colors: [
              Color(0xFF0D071F),
              Color(0xFF1A0A35),
              Color(0xFF0C0E21),
            ],
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
                      _buildTierSelector(),
                      const SizedBox(height: 20),
                      _buildGenerateButton(),
                      if (_isLoading) ...[
                        const SizedBox(height: 40),
                        _buildLoadingWidget(),
                      ],
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
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              '${widget.emoji} ${widget.mood} Rizz',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5B63).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFF5B63),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🪙',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Text(
                  '$_coins',
                  style: const TextStyle(
                    color: Color(0xFFFF5B63),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5B63).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5B63).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        'Mood: ${widget.mood.toUpperCase()}',
        style: const TextStyle(
          color: Color(0xFFFF5B63),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.4,
        ),
        minLines: 4,
        maxLines: 6,
        decoration: InputDecoration(
          hintText:
              'Paste the message you received...\n\n'
              'Tap "${_tierConfig[_selectedTier]?['name']}" to generate a reply!',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildTierSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose AI Tier',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _tierConfig.entries.map((entry) {
            final tierName = entry.key;
            final tierData = entry.value;

            final isSelected = _selectedTier == tierName;
            final isEnabled = tierData['enabled'] == true;

            final cost = tierData['cost'] as int;
            final displayName = tierData['name'] as String;
            final color = tierData['color'] as Color;

            return Expanded(
              child: GestureDetector(
                onTap: !isEnabled
                    ? null
                    : () {
                        setState(() {
                          _selectedTier = tierName;
                        });
                      },
                child: Opacity(
                  opacity: isEnabled ? 1.0 : 0.45,
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.2)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: isSelected
                                ? color
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$cost 🪙',
                          style: TextStyle(
                            color: isSelected
                                ? color
                                : Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isEnabled) ...[
                          const SizedBox(height: 3),
                          const Text(
                            'Soon',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    final tierData = _tierConfig[_selectedTier];

    final tierName =
        tierData?['name'] as String? ?? 'Basic';

    final tierCost =
        tierData?['cost'] as int? ?? 1;

    final isTierEnabled =
        tierData?['enabled'] == true;

    final isEnabled =
        !_isLoading &&
        isTierEnabled &&
        _coins >= tierCost &&
        _controller.text.trim().isNotEmpty;

    final color =
        tierData?['color'] as Color? ??
        const Color(0xFF00BCD4);

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withOpacity(0.7),
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.grey.withOpacity(0.3),
                  Colors.grey.withOpacity(0.2),
                ],
              ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? _generate : null,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Text(
              _isLoading
                  ? 'Generating $tierName Reply...'
                  : '✨ Generate $tierName Reply ($tierCost 🪙)',
              style: TextStyle(
                color: isEnabled
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFFFF5B63).withOpacity(0.7),
            ),
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Generating your perfect reply...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildReplyCard() {
    return ScaleTransition(
      scale: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF5B63).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5B63).withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '✨ Your Rizz Reply',
                    style: TextStyle(
                      color: Color(0xFFFF5B63),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: _copyReply,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5B63).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF5B63).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _copied ? '✓ Copied' : 'Copy',
                        style: TextStyle(
                          color: _copied
                              ? Colors.green
                              : const Color(0xFFFF5B63),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _reply,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}