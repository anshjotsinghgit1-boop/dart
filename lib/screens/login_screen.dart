import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/gradient_button.dart';
import '../widgets/social_button.dart';

class AuthForm extends StatelessWidget {
  final bool isLogin;
  final bool isLoading;

  final GlobalKey<FormState> formKey;

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;

  final VoidCallback onSubmit;

  const AuthForm({
    super.key,
    required this.isLogin,
    required this.isLoading,
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [

          /// Name
          if (!isLogin) ...[
            CustomTextField(
              controller: nameController,
              hint: "Full Name",
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Please enter your name";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          /// Email
          CustomTextField(
            controller: emailController,
            hint: "Email Address",
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter email";
              }

              if (!value.contains("@")) {
                return "Enter a valid email";
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          /// Password
          CustomTextField(
            controller: passwordController,
            hint: "Password",
            icon: Icons.lock_outline_rounded,
            obscure: true,
            validator: (value) {
              if (value == null || value.length < 6) {
                return "Minimum 6 characters";
              }
              return null;
            },
          ),

          /// Confirm Password
          if (!isLogin) ...[
            const SizedBox(height: 16),

            CustomTextField(
              controller: confirmController,
              hint: "Confirm Password",
              icon: Icons.lock_reset_outlined,
              obscure: true,
              validator: (value) {
                if (value != passwordController.text) {
                  return "Passwords don't match";
                }
                return null;
              },
            ),
          ],

          const SizedBox(height: 12),

          if (isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: AppColors.pink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          GradientButton(
            text: isLogin ? "Login" : "Create Account",
            loading: isLoading,
            onTap: onSubmit,
          ),

          const SizedBox(height: 26),

          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white.withOpacity(.12),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  "OR",
                  style: TextStyle(
                    color: Colors.white.withOpacity(.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white.withOpacity(.12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          SocialButton(
            text: "Continue with Google",
            icon: Icons.g_mobiledata,
            onTap: () {},
          ),

          const SizedBox(height: 14),

          SocialButton(
            text: "Continue with Apple",
            icon: Icons.apple,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
