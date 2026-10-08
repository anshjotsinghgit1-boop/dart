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
  String? _purchasingProductId;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': GooglePlayBillingService.coins200ProductId,
      'coins': 200,
      'label': '200 Coins',
      'description': 'Quick top-up for a few AI replies.',
      'badge': 'STARTER',
      'subscription': false,
      'gradient': [
        Color(0xFF00BCD4),
        Color(0xFF0088FF),
      ],
    },
    {
      'id': GooglePlayBillingService.coins450ProductId,
      'coins': 450,
      'label': '450 Coins',
      'description': 'A little more room to keep the conversation going.',
      'badge': 'POPULAR',
      'subscription': false,
      'gradient': [
        Color(0xFF7C4DFF),
        Color(0xFFB026FF),
      ],
    },
    {
      'id': GooglePlayBillingService.coins2400ProductId,
      'coins': 2400,
      'label': '2,400 Coins',
      'description': 'Great value for regular Rizz Guru users.',
      'badge': 'BEST VALUE',
      'subscription': false,
      'gradient': [
        Color(0xFFFF5B63),
        Color(0xFFFF2D8D),
      ],
    },
    {
      'id': GooglePlayBillingService.coins5000ProductId,
      'coins': 5000,
      'label': '5,000 Coins',
      'description': 'The biggest one-time coin pack.',
      'badge': 'MAX',
      'subscription': false,
      'gradient': [
        Color(0xFFFFA000),
        Color(0xFFFF5B63),
      ],
    },
    {
      'id': GooglePlayBillingService.weeklyProductId,
      'coins': 750,
      'label': 'Weekly',
      'description': '750 coins every week with automatic renewal.',
      'badge': 'WEEKLY',
      'subscription': true,
      'gradient': [
        Color(0xFF00C853),
        Color(0xFF00A884),
      ],
    },
  ];

  @override
  void initState() {
    super.initState();

    _billing = GooglePlayBillingService(
      onPurchaseCompleted: _handlePurchaseCompleted,
      onError: _handleBillingError,
      onPurchaseStarted: _handlePurchaseStarted,
      onPurchasePending: _handlePurchasePending,
      onPurchaseCancelled: _handlePurchaseCancelled,
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
    } catch (_) {
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
        'Could not load your coins.',
        isError: true,
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
    if (!mounted) return;

    setState(() {
      _purchasing = true;
      _purchasingProductId = productId;
    });
  }

  Future<void> _handlePurchaseCompleted(
    String productId,
    int coins,
  ) async {
    if (!mounted) return;

    final purchasedPlan = _plans.cast<Map<String, dynamic>?>().firstWhere(
          (plan) => plan?['id'] == productId,
          orElse: () => null,
        );

    setState(() {
      _currentCoins = coins;
      _purchasing = false;
      _purchasingProductId = null;
    });

    if (productId == GooglePlayBillingService.weeklyProductId) {
      widget.onSubscribed?.call();

      if (!widget.isPaywall) {
        _showSuccessDialog(
          title: 'Weekly plan active',
          message: '750 coins have been added to your account.',
        );
      }

      return;
    }

    if (purchasedPlan != null) {
      _showSuccessDialog(
        title: '${purchasedPlan['coins']} coins added',
        message:
            '${purchasedPlan['coins']} coins have been added to your account.',
      );
    }

    await _loadCoins();
  }

  void _handlePurchasePending() {
    if (!mounted) return;

    _showSnack(
      'Purchase is pending. Your balance will update when Google Play completes it.',
    );
  }

  void _handlePurchaseCancelled() {
    if (!mounted) return;

    setState(() {
      _purchasing = false;
      _purchasingProductId = null;
    });

    _showSnack('Purchase cancelled.');
  }

  void _handleBillingError(String message) {
    if (!mounted) return;

    setState(() {
      _purchasing = false;
      _purchasingProductId = null;
    });

    _showSnack(
      message,
      isError: true,
    );
  }

  Future<void> _restorePurchases() async {
    if (_isInitializingBilling || _purchasing) return;

    _showSnack('Checking previous purchases...');

    try {
      await _billing.restorePurchases();
    } catch (_) {
      _showSnack(
        'Could not restore purchases. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _purchase(
    Map<String, dynamic> plan,
  ) async {
    if (_purchasing) return;

    if (_isInitializingBilling) {
      _showSnack(
        'Google Play Billing is still loading.',
      );
      return;
    }

    final productId = plan['id'] as String;
    final isSubscription = plan['subscription'] as bool;

    setState(() {
      _purchasing = true;
      _purchasingProductId = productId;
    });

    try {
      if (isSubscription) {
        await _billing.buyWeeklyPlan();
      } else {
        await _billing.buyTopUp(productId);
      }
    } catch (_) {
      _handleBillingError(
        'Could not start the purchase. Please try again.',
      );
    }
  }

  void _showSuccessDialog({
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17132A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF00C853),
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFA9A5BC),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Current balance: $_currentCoins coins',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5B63),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
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

  void _showSnack(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFFB3261E)
              : const Color(0xFF272238),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0912),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFFF5B63),
                backgroundColor: const Color(0xFF17132A),
                onRefresh: _loadCoins,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    30,
                  ),
                  children: [
                    _buildIntro(),
                    const SizedBox(height: 20),
                    _buildBalanceCard(),
                    const SizedBox(height: 26),
                    _buildSectionHeader(),
                    const SizedBox(height: 12),
                    ..._plans.map(_buildPlanCard),
                    const SizedBox(height: 16),
                    _buildRestoreButton(),
                    const SizedBox(height: 14),
                    _buildFooterNote(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 18, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const Expanded(
            child: Text(
              'Coins & Plans',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: _isLoadingCoins ? null : _loadCoins,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFAAA5BA),
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get more coins.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Use them whenever you need a better reply.',
          style: TextStyle(
            color: Color(0xFF9893AA),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF17132A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F).withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Color(0xFFFFD54F),
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your balance',
                  style: TextStyle(
                    color: Color(0xFF8E899F),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Coins',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _isLoadingCoins ? '...' : '$_currentCoins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return const Row(
      children: [
        Text(
          'Choose a package',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        Spacer(),
        Text(
          'ONE-TIME + WEEKLY',
          style: TextStyle(
            color: Color(0xFF777286),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final productId = plan['id'] as String;
    final coins = plan['coins'] as int;
    final label = plan['label'] as String;
    final description = plan['description'] as String;
    final badge = plan['badge'] as String;
    final isSubscription = plan['subscription'] as bool;
    final colors = plan['gradient'] as List<Color>;

    final isPurchasingThis = _purchasingProductId == productId;
    final productPrice = _billing.price(productId);

    String fallbackPrice;

    if (isSubscription) {
      fallbackPrice = '₹150/week';
    } else {
      switch (productId) {
        case GooglePlayBillingService.coins200ProductId:
          fallbackPrice = '₹49';
          break;
        case GooglePlayBillingService.coins450ProductId:
          fallbackPrice = '₹100';
          break;
        case GooglePlayBillingService.coins2400ProductId:
          fallbackPrice = '₹500';
          break;
        case GooglePlayBillingService.coins5000ProductId:
          fallbackPrice = '₹1,000';
          break;
        default:
          fallbackPrice = '—';
      }
    }

    final price = productPrice ?? fallbackPrice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _purchasing && !isPurchasingThis ? 0.55 : 1,
        child: Material(
          color: const Color(0xFF17132A),
          borderRadius: BorderRadius.circular(19),
          child: InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: (_purchasing || _isInitializingBilling)
                ? null
                : () => _purchase(plan),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isSubscription
                      ? colors.first.withOpacity(0.28)
                      : Colors.white.withOpacity(0.065),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      isSubscription
                          ? Icons.autorenew_rounded
                          : Icons.monetization_on_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.first.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: colors.first,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8E899F),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$coins coins${isSubscription ? ' / week' : ''}',
                          style: TextStyle(
                            color: colors.first,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  _buildPriceButton(
                    price: price,
                    colors: colors,
                    isLoading: isPurchasingThis,
                  ),
                ],
              ),
            ),
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
        width: 58,
        height: 39,
        child: Center(
          child: SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                colors.first,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 55,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        price,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return OutlinedButton(
      onPressed: (_purchasing || _isInitializingBilling)
          ? null
          : _restorePurchases,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFB7B1C5),
        side: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      child: const Text(
        'Restore purchases',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Coin packs are one-time purchases. The weekly plan renews automatically every 7 days until cancelled. Coins do not expire.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF716C7D),
          fontSize: 10.5,
          height: 1.45,
        ),
      ),
    );
  }
}