import 'package:flutter/material.dart';

class AuthForm extends StatelessWidget {
  final bool isLogin;
  final bool isLoading;
  final String actionLabel;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final VoidCallback onSubmit;

  const AuthForm({
    required this.isLogin,
    required this.isLoading,
    required this.actionLabel,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.onSubmit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            if (!isLogin) ...[
              _buildTextField(
                label: 'Full Name',
                hint: 'Riya Sharma',
                controller: nameController,
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Naam 3 letters se chota nahi hona chahiye';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
            ],
            _buildTextField(
              label: 'Email',
              hint: 'rizzguru@example.com',
              controller: emailController,
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || !value.contains('@')) {
                  return 'Valid email daalo bhai';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _buildTextField(
              label: 'Password',
              hint: 'At least 8 characters',
              controller: passwordController,
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Password kam se kam 8 characters ka hona chahiye';
                }
                return null;
              },
            ),
            if (!isLogin) ...[
              const SizedBox(height: 18),
              _buildTextField(
                label: 'Confirm Password',
                hint: 'Re-type password',
                controller: confirmController,
                icon: Icons.lock_reset,
                obscureText: true,
                validator: (value) {
                  if (value != passwordController.text) {
                    return 'Password match nahi kar raha';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: const Color(0xFFFF5B63),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : Text(
                      actionLabel,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          cursorColor: const Color(0xFFFF5B63),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.76)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          ),
        ),
      ],
    );
  }
}
