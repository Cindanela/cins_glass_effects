import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

// Real dimensions, lifted from a production bottom bar (subscription_tracker):
// the FAB is *larger* than the bar and centred, so the bar can't use Material's
// notch — it needs a custom circular through-cut bigger than its own height.
const double _barHeight = 58.0;
const double _fabSize = 70.0; // bar height + 12
const double _holeRadius = 43.0; // fab radius (35) + 8 glass gap
const double _cornerRadius = 29.0; // full pill (clamped to bar half-height)
const double _navIconSize = 28.0;
const double _fabIconSize = 47.6;
const double _middleGap = _fabSize + 24.0 * 2; // fab + gap on each side

Offset _centre(Size size) => Offset(size.width / 2, size.height / 2);

/// The bar silhouette: a pill with a circular hole punched for the FAB —
/// `roundedRect − circle`, so the hole rim is an exact, optically-correct edge.
GlassShape _navBarShape() {
  final bar = const GlassShape.roundedRect(_cornerRadius);
  final hole = GlassShape.path(
    (size) => Path()
      ..addOval(Rect.fromCircle(center: _centre(size), radius: _holeRadius)),
    sdfFn: (p, size) => ShapeSdf.circle(p - _centre(size), _holeRadius),
    id: 'fab-hole',
  );
  return bar.difference(hole);
}

/// A glass navigation bar with four items and a larger, centred glass FAB
/// dropped into the hole — assembled only from `cins_glass_effects` primitives.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  static const _icons = <IconData>[
    Icons.grid_view_rounded,
    Icons.calendar_month_rounded,
    Icons.list_rounded,
    Icons.bar_chart_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    // The middle gap splits the four items two-and-two around the FAB.
    Widget item(int iconIndex) {
      final active = currentIndex == iconIndex;
      return Expanded(
        child: InkResponse(
          onTap: () => onTap(iconIndex),
          radius: _navIconSize,
          child: Center(
            child: Icon(
              _icons[iconIndex],
              size: _navIconSize,
              color: active ? Colors.white : Colors.white60,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: _fabSize, // the FAB overhangs the bar
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The bar, centred vertically (the FAB sticks out above and below).
          Center(
            child: SizedBox(
              height: _barHeight,
              child: GlassContainer(
                material: GlassMaterials.clear,
                shape: _navBarShape(),
                child: Row(
                  children: [
                    item(0),
                    item(1),
                    const SizedBox(width: _middleGap),
                    item(2),
                    item(3),
                  ],
                ),
              ),
            ),
          ),
          // The FAB: a larger glass circle sitting in the hole.
          SizedBox(
            width: _fabSize,
            height: _fabSize,
            child: GlassContainer(
              material: GlassMaterials.liquid,
              shape: const GlassShape.circle(),
              child: InkResponse(
                onTap: onAdd,
                radius: _fabSize / 2,
                child: const Center(
                  child: Icon(Icons.add_rounded,
                      size: _fabIconSize, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
