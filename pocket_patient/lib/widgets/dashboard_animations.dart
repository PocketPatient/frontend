import 'package:flutter/material.dart';

/// Fades + slides [child] up on first build. Give successive cards in a list
/// increasing [index] values for a staggered entrance (Week 15 Task 3).
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;

  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    // Staggered start — capped so a long list doesn't feel sluggish to load.
    final delayMs = (widget.index * 60).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Animates a numeric stat value counting up/down from its previous value
/// whenever [value] changes (e.g. after pull-to-refresh) — Week 15 Task 3.
class AnimatedCountUp extends StatefulWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;

  const AnimatedCountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  @override
  State<AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<AnimatedCountUp> {
  double _previous = 0;

  @override
  void initState() {
    super.initState();
    _previous = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previous = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _previous, end: widget.value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, animatedValue, _) =>
          Text(widget.format(animatedValue), style: widget.style),
    );
  }
}
