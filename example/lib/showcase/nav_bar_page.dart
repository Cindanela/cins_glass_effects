import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import '../glass_nav_bar.dart';
import 'theme.dart';

Offset _centre(Size size) => Offset(size.width / 2, size.height / 2);

/// One glass slab: bar ∪ FAB circle — the candidate fix for the doubled rim
/// and rectangular seam where two stacked backdrop filters overlap
/// (WORKLOG 2026-07-13, issue 4).
GlassShape navBarUnionShape() {
  final bar = GlassShape.path(
    (size) {
      final inset = (size.height - kNavBarHeight) / 2;
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, inset, size.width, kNavBarHeight),
          const Radius.circular(kNavCornerRadius),
        ));
    },
    sdfFn: (p, size) => ShapeSdf.roundedRect(
      p - _centre(size),
      Size(size.width / 2, kNavBarHeight / 2),
      kNavCornerRadius,
    ),
    id: 'showcase-union-bar',
  );
  final fab = GlassShape.path(
    (size) => Path()
      ..addOval(Rect.fromCircle(center: _centre(size), radius: kNavFabSize / 2)),
    sdfFn: (p, size) => ShapeSdf.circle(p - _centre(size), kNavFabSize / 2),
    id: 'showcase-union-fab',
  );
  return bar.union(fab);
}

/// The nav-bar fixture: `Separate` reproduces the two-widget composition from
/// the real app (and its seam bug); `Union` renders the same silhouette as one
/// GlassContainer.
class NavBarPage extends StatelessWidget {
  const NavBarPage({
    super.key,
    required this.union,
    required this.onUnionChanged,
  });

  final bool union;
  final ValueChanged<bool> onUnionChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ShowcaseTheme.pad,
              ShowcaseTheme.pad, ShowcaseTheme.pad, ShowcaseTheme.pageBottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Separate')),
                  ButtonSegment(value: true, label: Text('Union')),
                ],
                selected: {union},
                onSelectionChanged: (s) => onUnionChanged(s.single),
              ),
              const SizedBox(height: ShowcaseTheme.pad),
              if (union)
                const UnionNavBar()
              else
                // Static fixture — taps aren't the point here.
                GlassNavBar(currentIndex: 0, onTap: (_) {}, onAdd: () {}),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same bar + FAB silhouette as [GlassNavBar], but as ONE GlassContainer.
class UnionNavBar extends StatelessWidget {
  const UnionNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kNavFabSize,
      child: GlassContainer(
        material: GlassMaterials.clear,
        shape: navBarUnionShape(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                for (final (i, icon) in kNavIcons.indexed) ...[
                  Expanded(
                    child: Center(
                      child: Icon(
                        icon,
                        size: kNavIconSize,
                        color: i == 0 ? Colors.white : Colors.white60,
                      ),
                    ),
                  ),
                  if (i == 1) const SizedBox(width: kNavMiddleGap),
                ],
              ],
            ),
            const Icon(
              Icons.add_rounded,
              size: kNavFabIconSize,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
