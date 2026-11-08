import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'night_theme.dart';

class NightPanel extends StatelessWidget {
  const NightPanel({
    super.key,
    required this.child,
    this.accent = false,
    this.padding = 24,
  });
  final Widget child;
  final bool accent;
  final double padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: accent ? NightColors.accent : NightColors.surface,
      borderRadius: BorderRadius.circular(28),
      border: accent ? null : Border.all(color: NightColors.border),
    ),
    child: Padding(
      padding: EdgeInsets.all(padding),
      child: accent
          ? DefaultTextStyle.merge(
              style: const TextStyle(color: NightColors.ink),
              child: child,
            )
          : child,
    ),
  );
}

class NightEyebrow extends StatelessWidget {
  const NightEyebrow(this.text, {super.key, this.color = NightColors.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      height: 1.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
      color: color,
    ),
  );
}

class NightBadge extends StatelessWidget {
  const NightBadge(this.text, {super.key, this.dark = false});
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: dark ? NightColors.ink : NightColors.border),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: dark ? NightColors.ink : NightColors.muted,
      ),
    ),
  );
}

/// An entrance only: there is deliberately no retained outgoing child.
/// Replacing/removing this widget removes its secret text in the same frame.
class NightEntrance extends StatefulWidget {
  const NightEntrance({super.key, required this.child});
  final Widget child;
  @override
  State<NightEntrance> createState() => _NightEntranceState();
}

class _NightEntranceState extends State<NightEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: NightMotion.enter)
      ..forward();
    _animation = CurvedAnimation(parent: _controller, curve: NightMotion.curve);
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (NightMotion.reduced(context)) return widget.child;
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

class NightButton extends StatefulWidget {
  const NightButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.dark = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool dark;
  @override
  State<NightButton> createState() => _NightButtonState();
}

class _NightButtonState extends State<NightButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.onPressed == null
        ? null
        : (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed && !NightMotion.reduced(context) ? .985 : 1,
      duration: NightMotion.reduced(context)
          ? Duration.zero
          : NightMotion.quick,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: widget.dark
              ? FilledButton.styleFrom(
                  backgroundColor: NightColors.ink,
                  foregroundColor: NightColors.text,
                )
              : null,
          onPressed: widget.onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onPressed!();
                },
          child: Text(widget.label, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

class NightRoute<T> extends MaterialPageRoute<T> {
  NightRoute({required super.builder});

  @override
  Duration get transitionDuration => NightMotion.route;
  @override
  Duration get reverseTransitionDuration => NightMotion.enter;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced = NightMotion.reduced(context);
    // Keep the gesture detector even when decorative motion is disabled.
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return super.buildTransitions(
        context,
        reduced ? kAlwaysCompleteAnimation : animation,
        reduced ? kAlwaysDismissedAnimation : secondaryAnimation,
        child,
      );
    }
    if (reduced) return child;
    final curved = animation.drive(CurveTween(curve: NightMotion.curve));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(.04, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class NightRule extends StatelessWidget {
  const NightRule({
    super.key,
    required this.number,
    required this.title,
    required this.text,
  });
  final String number;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => NightPanel(
    padding: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number · $title',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: NightColors.accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: NightColors.muted)),
      ],
    ),
  );
}
