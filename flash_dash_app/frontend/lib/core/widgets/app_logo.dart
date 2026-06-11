import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double opacity;
  final MainAxisSize mainAxisSize;

  const AppLogo({
    super.key,
    this.size = 48,
    this.showText = false,
    this.opacity = 1,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;

    return Opacity(
      opacity: opacity,
      child: Row(
        mainAxisSize: mainAxisSize,
        children: [
          Image.asset(
            'figuras/Logo_FlashDash.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
          if (showText) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Flash-Dash',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: (size * 0.36).clamp(16, 24).toDouble(),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
