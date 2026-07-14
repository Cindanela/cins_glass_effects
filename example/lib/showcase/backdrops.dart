import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The three things glass can sit on — each makes a different defect visible:
/// gradient = refraction, plain = hairlines/tint, scrolling = backdrop tracking.
enum ShowcaseBackdrop {
  gradient('Gradient', Icons.gradient),
  plain('Plain', Icons.crop_square),
  scrolling('Scrolling', Icons.swap_vert);

  const ShowcaseBackdrop(this.label, this.icon);

  final String label;
  final IconData icon;

  ShowcaseBackdrop get next => values[(index + 1) % values.length];
}

class BackdropView extends StatelessWidget {
  const BackdropView({super.key, required this.backdrop});

  final ShowcaseBackdrop backdrop;

  @override
  Widget build(BuildContext context) => switch (backdrop) {
        ShowcaseBackdrop.gradient => const _GradientBackdrop(),
        ShowcaseBackdrop.plain => const _PlainBackdrop(),
        ShowcaseBackdrop.scrolling => const _ScrollingBackdrop(),
      };
}

/// Colourful, high-frequency backdrop so refraction is obvious.
class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF0080), Color(0xFF7928CA), Color(0xFF00D4FF)],
        ),
      ),
      child: GridView.count(
        crossAxisCount: 6,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          60,
          (i) => Icon(
            Icons.star,
            color: Colors.white.withValues(alpha: 0.18),
            size: 40,
          ),
        ),
      ),
    );
  }
}

/// Light and quiet: dark hairlines and tint errors have nowhere to hide.
class _PlainBackdrop extends StatelessWidget {
  const _PlainBackdrop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF2F2F4),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(ShowcaseTheme.pad),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: ShowcaseTheme.gap),
          child: Text(
            'The quick brown fox jumps over the lazy dog — line $i',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.35),
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

const _cardColors = [
  Color(0xFFFF0080),
  Color(0xFF7928CA),
  Color(0xFF00D4FF),
  Color(0xFF00E5A0),
  Color(0xFFFFB300),
];

/// Auto-scrolls (ping-pong) so moving content passes under the glass hands-free.
/// Auto rather than manual: the PageView above it claims drag gestures, so a
/// user-scrolled list here would never receive them.
class _ScrollingBackdrop extends StatefulWidget {
  const _ScrollingBackdrop();

  @override
  State<_ScrollingBackdrop> createState() => _ScrollingBackdropState();
}

class _ScrollingBackdropState extends State<_ScrollingBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: ShowcaseTheme.scrollPeriod,
  )..repeat();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cycle.addListener(_drive);
  }

  void _drive() {
    if (!_scroll.hasClients) return;
    final range = _scroll.position.maxScrollExtent;
    // Smooth ping-pong: 0 → range → 0 over one controller cycle.
    final t = 0.5 - 0.5 * math.cos(_cycle.value * 2 * math.pi);
    _scroll.jumpTo(range * t);
  }

  @override
  void dispose() {
    _cycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF101014),
      child: ListView.builder(
        controller: _scroll,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(ShowcaseTheme.pad),
        itemCount: 40,
        itemBuilder: (_, i) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: ShowcaseTheme.pad),
          decoration: BoxDecoration(
            color: _cardColors[i % _cardColors.length],
            borderRadius: BorderRadius.circular(ShowcaseTheme.controlRadius),
          ),
          child: Center(
            child: Text(
              'Card $i',
              style: const TextStyle(color: Colors.white70, fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }
}
