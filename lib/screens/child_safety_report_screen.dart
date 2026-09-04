import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChildSafetyReportScreen extends StatefulWidget {
  const ChildSafetyReportScreen({super.key});

  @override
  State<ChildSafetyReportScreen> createState() =>
      _ChildSafetyReportScreenState();
}

class _ChildSafetyReportScreenState extends State<ChildSafetyReportScreen> {
  static const String _recipient = 'Prothonaidevelopers@gmail.com';
  static const List<String> _categories = [
    'Suspected CSAM',
    'Child sexual abuse or exploitation',
    'Grooming or sexual solicitation of a minor',
    'Other child-safety concern',
  ];

  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();
  String _category = _categories.first;
  bool _confirmedNoIllegalContent = false;
  bool _openingEmail = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _sendReport() async {
    final description = _descriptionController.text.trim();
    final reference = _referenceController.text.trim();

    if (description.isEmpty) {
      _showMessage('Please describe the concern before continuing.');
      return;
    }

    if (!_confirmedNoIllegalContent) {
      _showMessage(
        'Please confirm that you are not attaching or pasting illegal content.',
      );
      return;
    }

    setState(() => _openingEmail = true);

    final user = FirebaseAuth.instance.currentUser;
    final body = [
      'Child-safety concern reported through RizzGuru',
      '',
      'Category: ' + _category,
      'Reporter email: ' + (user?.email ?? 'Not provided'),
      'Reference or account identifier: ' +
          (reference.isEmpty ? 'Not provided' : reference),
      '',
      'Description:',
      description,
      '',
      'I confirm that I have not attached, pasted, or forwarded suspected CSAM or other illegal sexual content involving a minor.',
    ].join('\n');

    final uri = Uri(
      scheme: 'mailto',
      path: _recipient,
      queryParameters: {
        'subject': 'URGENT: Child Safety Concern - RizzGuru',
        'body': body,
      },
    );

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted) return;
    setState(() => _openingEmail = false);

    if (opened) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A0A35),
          title: const Text(
            'Report email ready',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Review the message and send it to complete your report. Please do not add illegal images or videos as attachments.',
            style: TextStyle(color: Color(0xFFB7AEC9), height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Done',
                style: TextStyle(color: Color(0xFFFF5B63)),
              ),
            ),
          ],
        ),
      );
    } else {
      _showMessage(
        'No email app is available. Email ' +
            _recipient +
            ' from another device.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2B174A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D071F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Child Safety',
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
                color: const Color(0xFFFFB347).withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFFB347).withOpacity(0.35),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFFFB347),
                    size: 25,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Use this form for suspected CSAM, child sexual exploitation, grooming, or any other child-safety concern.',
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.45,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Concern type',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              dropdownColor: const Color(0xFF24113F),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Select a category'),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'What happened?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                'Describe the concern without including illegal content',
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Optional reference',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _referenceController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                'Username, message ID, or lawful URL (if available)',
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _confirmedNoIllegalContent,
              onChanged: (value) => setState(
                () => _confirmedNoIllegalContent = value ?? false,
              ),
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFFFF5B63),
              checkColor: Colors.white,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I will not attach, paste, or forward suspected CSAM or other illegal sexual content involving a minor.',
                style: TextStyle(color: Color(0xFFB7AEC9), fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _openingEmail ? null : _sendReport,
                icon: _openingEmail
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mail_outline_rounded),
                label: Text(
                  _openingEmail ? 'Opening email…' : 'Prepare report email',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5B63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The report email will be addressed to Prothonaidevelopers@gmail.com. Review it and press Send in your email app. If a child is in immediate danger, contact local emergency services or the appropriate child-protection authority.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A8AAA),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8A8AAA), fontSize: 13),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
        borderSide: BorderSide(color: Color(0xFFFF5B63)),
      ),
    );
  }
}
