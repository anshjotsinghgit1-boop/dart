import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/plans_screen.dart';
import 'services/subscription_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D071F),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        return _SubscriptionGate(user: user);
      },
    );
  }
}

class _SubscriptionGate extends StatefulWidget {
  final User user;
  const _SubscriptionGate({required this.user});

  @override
  State<_SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<_SubscriptionGate> {
  bool _checking = true;
  bool _hasSubscription = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final active = await SubscriptionService.hasActiveSubscription();
      if (!mounted) return;
      setState(() {
        _hasSubscription = active;
        _checking = false;
      });
    } catch (_) {
      // On any error — always show paywall, never grant free access
      if (!mounted) return;
      setState(() {
        _hasSubscription = false;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D071F),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasSubscription) {
      return const _PaywallScreen();
    }

    final name = widget.user.displayName?.trim().isNotEmpty == true
        ? widget.user.displayName!
        : widget.user.email?.split('@').first ?? 'User';

    return HomeScreen(userName: name);
  }
}

class _PaywallScreen extends StatefulWidget {
  const _PaywallScreen();

  @override
  State<_PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<_PaywallScreen> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: PlansScreen(
        isPaywall: true,
        onSubscribed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
          );
        },
      ),
    );
  }
}
