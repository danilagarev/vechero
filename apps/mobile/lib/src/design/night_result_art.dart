import 'package:flutter/material.dart';

import 'night_art.dart';
import 'night_theme.dart';

/// Public result artwork only: never wraps a player's secret or an outgoing card.
class NightResultArt extends StatelessWidget {
  const NightResultArt({
    super.key,
    required this.kind,
    this.height = 180,
    this.color = NightColors.accent,
    this.onColor = NightColors.ink,
  });

  final NightArtKind kind;
  final double height;
  final Color color;
  final Color onColor;

  Widget _art(double progress) => NightArt(
    kind: kind,
    height: height,
    color: color,
    onColor: onColor,
    progress: progress,
  );

  @override
  Widget build(BuildContext context) {
    if (NightMotion.reduced(context)) return _art(1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NightMotion.verdict,
      curve: NightMotion.curve,
      builder: (context, progress, _) =>
          Transform.scale(scale: .92 + .08 * progress, child: _art(progress)),
    );
  }
}
