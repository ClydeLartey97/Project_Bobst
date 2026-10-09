import 'package:flutter/material.dart';

/// NYU logo if `assets/brand/nyu_logo.png` exists, otherwise a wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final wordmark = Text(
      'NYU  ·  BOBST LIBRARY',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: color,
        letterSpacing: 2,
        fontWeight: FontWeight.w700,
      ),
    );
    return Image.asset(
      'assets/brand/nyu_logo.png',
      height: 28,
      errorBuilder: (_, _, _) => wordmark,
    );
  }
}
