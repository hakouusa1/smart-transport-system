import 'package:flutter/material.dart';

class TariqiLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const TariqiLogo({super.key, this.size = 80, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.18),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Tariqi',
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: size * 0.04),
          Text(
            'My Way',
            style: TextStyle(
              fontSize: size * 0.16,
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
