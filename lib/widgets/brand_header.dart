import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo
        Container(
          width: 105,
          height: 105,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withOpacity(.35),
                blurRadius: 35,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                size: 90,
                color: AppColors.purple,
              ),

              Positioned(
                top: 32,
                child: Icon(
                  Icons.sunglasses,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // RizzGuru
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: "Rizz",
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -.5,
                ),
              ),
              TextSpan(
                text: "Guru",
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  color: AppColors.pink,
                  letterSpacing: -.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Speak smooth. Win more. 💖",
          style: TextStyle(
            color: Colors.white.withOpacity(.75),
            fontSize: 17,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
