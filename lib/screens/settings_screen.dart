import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'child_safety_report_screen.dart';
import 'plans_screen.dart';

class SettingsScreen extends StatelessWidget {
  static const String safetyEmail = 'Prothonaidevelopers@gmail.com';

  const SettingsScreen({super.key});

  Future<void> _openSupportEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: safetyEmail,
      queryParameters: const {
        'subject': 'RizzGuru support request',
      },
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app is available on this device.'),
        ),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'RizzGuru',
      applicationLegalese: 'AI-powered reply assistant',
      children: const [
        SizedBox(height: 12),
        Text(
          'Use the Child Safety & Reporting section to report suspected grooming, exploitation, CSAM, or any other concern involving a minor.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'RizzGuru user';
    final email = user?.email ?? 'No email added';
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'R';

    return Scaffold(
      backgroundColor: const Color(0xFF0D071F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D071F), Color(0xFF1A0A35), Color(0xFF0C0E21)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFFF5B63),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFAAA0C6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _SectionLabel('Safety & support'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFFFFB347),
              title: 'Child Safety & Reporting',
              subtitle: 'Report CSAE, CSAM, grooming, or other concerns',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChildSafetyReportScreen(),
                  ),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.mail_outline_rounded,
              iconColor: const Color(0xFF00E5FF),
              title: 'Email support',
              subtitle: safetyEmail,
              onTap: () => _openSupportEmail(context),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Account & purchases'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFFFF5B63),
              title: 'Plans & coins',
              subtitle: 'Manage your subscription and coin balance',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlansScreen()),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFFF8A80),
              title: 'Sign out',
              subtitle: 'Sign out of this account on this device',
              onTap: () => _signOut(context),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('About'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFFB39DDB),
              title: 'About RizzGuru',
              subtitle: 'App information and safety guidance',
              onTap: () => _showAbout(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF8A8AAA),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: Colors.white.withOpacity(0.05),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8A8AAA),
                fontSize: 12,
              ),
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF8A8AAA),
          ),
        ),
      ),
    );
  }
}
