import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/coins_service.dart';
import '../services/google_play_billing_service.dart';

class PlansScreen extends StatefulWidget {
  final bool isPaywall;
  final VoidCallback? onSubscribed;

  const PlansScreen({
    super.key,
    this.isPaywall = false,
    this.onSubscribed,
  });

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late final GooglePlayBillingService _billing;

  int _currentCoins = 0;
  bool _isLoadingCoins = true;
  bool _isInitializingBilling = true;
  bool _purchasing = false;
  int? _purchasingIndex;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': GooglePlayBillingService.weeklyProductId,
      'coins': 150,
      'label': 'Weekly Plan',
      'emoji': '♻',
      'description': '150 coins every week with automatic renewal.',
      'badge': 'WEEKLY',
      'subscription': true,
      'gradient': [
        Color(0xFFFF5B63),
        Color(0xFF9B22F9),
      ],
    },
    {
      'id': GooglePlayBillingService.topUpProductId,
      'coins': 150,
      'label': 'Coin Top-up',
      'emoji': '+',
      'description': '150 coins as a one-time purchase.',
      'badge': 'TOP-UP',
      'subscription': false,
      'gradient': [
        Color(0xFF00BCD4),
        Color(0xFF00E5FF),
      ],
    },
  ];

  @override
  void initState() {
    super.initState();

    _billing = GooglePlayBillingService(
      onCoinsUpdated: _handleCoinsUpdated,
      onError: _handleBillingError,
      onPurchaseStarted: _handlePurchaseStarted,
    );

    _loadCoins();
    _initializeBilling();
  }

  @override
  void dispose() {
    _billing.dispose();
    super.dispose();
  }

  Future<void> _initializeBilling() async {
    try {
      await _billing.initialize();
    } catch (error) {
      _handleBillingError(
        'Could not initialize Google Play Billing.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingBilling = false;
        });
      }
    }
  }

  Future<void> _loadCoins() async {
    if (mounted) {
      setState(() {
        _isLoadingCoins = true;
      });
    }

    try {
      final coins = await CoinsService.getCoins();

      if (!mounted) return;

      setState(() {
        _currentCoins = coins;
      });
    } catch (error) {
      if (!mounted) return;

      _showSnack(
        'Could not load your coins. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCoins = false;
        });
      }
    }
  }

  void _handlePurchaseStarted(String productId) {
    final index = _plans.indexWhere(
      (plan) => plan['id'] == productId,
    );

    if (!mounted) return;

    setState(() {
      _purchasing = true;
      _purchasingIndex = index == -1 ? null : index;
    });
  }

  // ✅ FIXED — proper brace structure, both branches reachable
  Future<void> _handleCoinsUpdated(int coins) async {
    if (!mounted) return;

    final purchasedPlan = _purchasingIndex == null
        ? null
        : _plans[_purchasingIndex!];

    setState(() {
      _currentCoins = coins;
      _purchasing = false;
      _purchasingIndex = null;
    });

    // If weekly plan purchased and we're in paywall mode, unlock the app
    if (purchasedPlan != null &&
        purchasedPlan['id'] == GooglePlayBillingService.weeklyProductId) {
      widget.onSubscribed?.call();
      return;
    }

    // Otherwise show success dialog (for top-up purchases)
    if (purchasedPlan != null) {
      _showSuccessDialog(
        coinsAdded: purchasedPlan['coins'] as int,
        isSubscription: purchasedPlan['subscription'] as bool,
      );
    } else {
      await _loadCoins();
    }
  }

  void _handleBillingError(String message) {
    if (!mounted) return;

    setState(() {
      _purchasing = false;
      _purchasingIndex = null;
    });

    _showSnack(message);
  }

  Future<void> _purchase(
    int index,
    Map<String, dynamic> plan,
  ) async {
    if (_purchasing) return;

    if (_isInitializingBilling) {
      _showSnack(
        'Google Play Billing is still loading. Please wait.',
      );
      return;
    }

    setState(() {
      _purchasing = true;
      _purchasingIndex = index;
    });

    try {
      final isSubscription = plan['subscription'] as bool;

      if (isSubscription) {
        await _billing.buyWeeklyPlan();
      } else {
        await _billing.buyTopUp();
      }
    } catch (error) {
      _handleBillingError(
        'Could not start the purchase. Please try again.',
      );
    }
  }

  void _showSuccessDialog({
    required int coinsAdded,
    required bool isSubscription,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0A35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF5B63),
                      Color(0xFF9B22F9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isSubscription ? 'Weekly Plan Activated' : 'Coins Added',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$coinsAdded coins were added to your account.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8A8AAA),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your balance is now $_currentCoins coins.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5B63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D071F),
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
              _buildTopBar(),
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFFF5B63),
                  backgroundColor: const Color(0xFF1A0A35),
                  onRefresh: _loadCoins,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 22),
                        _buildBalanceCard(),
                        const SizedBox(height: 28),
                        _buildSectionTitle(),
                        const SizedBox(height: 14),
                        ...List.generate(
                          _plans.length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildPlanCard(index, _plans[index]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildFooterNote(),
                        // ✅ Sign-out escape hatch (paywall only)
                        if (widget.isPaywall) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                              },
                              child: const Text(
                                'Sign out',
                                style: TextStyle(
                                  color: Color(0xFF8A8AAA),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FIXED — hides back button when used as paywall
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
      child: Row(
        children: [
          if (!widget.isPaywall)
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          const Expanded(
            child: Text(
              'Get More Coins',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFD54F),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _isLoadingCoins ? '...' : '$_currentCoins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your plan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Use coins to generate AI-powered replies.',
          style: TextStyle(
            color: Color(0xFF8A8AAA),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A0A4A),
            Color(0xFF1A1035),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF5B63).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B22F9).withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F).withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Color(0xFFFFD54F),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available balance',
                  style: TextStyle(
                    color: Color(0xFF8A8AAA),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoadingCoins ? 'Loading...' : '$_currentCoins coins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoadingCoins ? null : _loadCoins,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFFF5B63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return const Row(
      children: [
        Icon(
          Icons.local_offer_outlined,
          color: Color(0xFFFF5B63),
          size: 19,
        ),
        SizedBox(width: 8),
        Text(
          'Available options',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(int index, Map<String, dynamic> plan) {
    final productId = plan['id'] as String;
    final coins = plan['coins'] as int;
    final label = plan['label'] as String;
    final emoji = plan['emoji'] as String;
    final description = plan['description'] as String;
    final badge = plan['badge'] as String;
    final isSubscription = plan['subscription'] as bool;
    final gradientColors = plan['gradient'] as List<Color>;

    final isThisPlanPurchasing = _purchasing && _purchasingIndex == index;

    final price = _billing.price(productId) ??
        (isSubscription ? '₹140/week' : '₹100');

    return GestureDetector(
      onTap: _purchasing || _isInitializingBilling
          ? null
          : () => _purchase(index, plan),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _purchasing && !isThisPlanPurchasing ? 0.55 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1035).withOpacity(0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isThisPlanPurchasing
                  ? gradientColors.first
                  : Colors.white.withOpacity(0.09),
              width: isThisPlanPurchasing ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradientColors),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8A8AAA),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$coins coins',
                      style: TextStyle(
                        color: gradientColors.first,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildPriceButton(
                price: price,
                colors: gradientColors,
                isLoading: isThisPlanPurchasing,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceButton({
    required String price,
    required List<Color> colors,
    required bool isLoading,
  }) {
    if (isLoading) {
      return SizedBox(
        width: 46,
        height: 42,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(colors.first),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        price,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1035).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8A8AAA).withOpacity(0.2),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF8A8AAA),
            size: 17,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Top-ups are one-time purchases. The weekly plan renews automatically every week. Coins do not expire.',
              style: TextStyle(
                color: Color(0xFF8A8AAA),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
