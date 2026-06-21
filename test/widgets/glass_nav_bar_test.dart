import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Exact values from subscription_tracker's app_bottom_bar.dart + app_dimensions.dart
// (at the default text scale). This is the real fixture: a FAB that is *larger*
// than the bar and centred, so the bar can't use Material's notch — it needs a
// custom circular through-cut bigger than its own height.
const double _barHeight = 58.0; // AppLayout.bottomBarHeight
const double _fabSize = 70.0; // bottomBarHeight + 12
const double _holeRadius = 43.0; // fabSize / 2 + 8
const double _cornerRadius = 29.0; // AppRadius.full, clamped to barHeight / 2
const double _navIconSize = 28.0; // AppLayout.tabBarIconSize
const double _fabIconSize = 47.6; // (tabBarIconSize + 6) * 1.4
const double _middleGap = _fabSize + 24.0 * 2; // fabSize + AppSpacing.gap * 2

Offset _centre(Size size) => Offset(size.width / 2, size.height / 2);

/// The bar silhouette: a full pill with a circular hole punched for the FAB.
/// `roundedRect − circle`, so the hole rim is an exact, optically-correct edge.
GlassShape navBarShape() {
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
/// dropped into the hole — assembled only from this package's primitives.
class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar();

  static const _noShader = GlassCapabilities(shaderFiltersSupported: false);

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon) =>
        Expanded(child: Center(child: Icon(icon, size: _navIconSize)));

    return SizedBox(
      height: _fabSize, // the FAB overhangs the bar, so the row is FAB-tall
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The bar, centred vertically (the FAB sticks out above/below it).
          Center(
            child: SizedBox(
              height: _barHeight,
              child: GlassContainer(
                capabilities: _noShader,
                material: GlassMaterials.clear,
                shape: navBarShape(),
                child: Row(
                  children: [
                    item(Icons.grid_view_rounded),
                    item(Icons.calendar_month_rounded),
                    const SizedBox(width: _middleGap),
                    item(Icons.list_rounded),
                    item(Icons.bar_chart_rounded),
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
              capabilities: _noShader,
              material: GlassMaterials.liquid,
              shape: const GlassShape.circle(),
              child: const Center(
                child: Icon(Icons.add_rounded, size: _fabIconSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  group('navBarShape geometry (real bottom-bar dimensions)', () {
    const size = Size(360, _barHeight);
    final shape = navBarShape();

    test('keeps the bar body solid but carves the FAB hole', () {
      final path = shape.clipPath(size);
      expect(path.contains(const Offset(20, _barHeight / 2)), isTrue); // bar end
      expect(path.contains(Offset(180, _barHeight / 2)), isFalse); // hole centre
    });

    test('hole radius (43) exceeds the bar half-height (29): the cut goes '
        'clean through the bar', () {
      // A point at the top edge of the bar, on the vertical centreline, is
      // inside the hole circle (43 > 29) -> removed.
      expect(shape.sdf(const Offset(180, 0), size), greaterThan(0));
    });

    test('sdf is ~0 on the hole rim, giving the FAB cutout a real glass edge', () {
      final onRim = const Offset(180, _barHeight / 2) + const Offset(_holeRadius, 0);
      expect(shape.sdf(onRim, size), closeTo(0, 1e-6));
    });
  });

  testWidgets('renders the glass bar with four items and a centred FAB',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ColoredBox(color: Colors.deepPurple),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: _GlassNavBar(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // Two glass surfaces: the bar and the FAB.
    expect(find.byType(GlassContainer), findsNWidgets(2));
    // Four nav icons + the FAB add icon.
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    expect(find.byIcon(Icons.list_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
