import 'package:flutter/material.dart';

class MassarLogo extends StatelessWidget {
  final double size;

  const MassarLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    final width = size * 1.84;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.18,
        vertical: size * 0.14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/massar_logo.webp',
        width: width,
        fit: BoxFit.contain,
      ),
    );
  }
}

class MassarLogoSmall extends StatelessWidget {
  final double height;

  const MassarLogoSmall({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/massar_logo.webp',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
