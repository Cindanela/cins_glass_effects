import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/showcase/animation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int presetIndex = 0,
    bool driftEnabled = false,
    VoidCallback? onTap,
    ValueChanged<bool>? onDrift,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimationPage(
            presetIndex: presetIndex,
            driftEnabled: driftEnabled,
            driftRight: false,
            onTapGlass: onTap ?? () {},
            onDriftToggled: onDrift ?? (_) {},
            onDriftLegComplete: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('material follows presetIndex and tap invokes callback', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, presetIndex: 1, onTap: () => taps++);
    final agc = tester.widget<AnimatedGlassContainer>(
      find.byType(AnimatedGlassContainer),
    );
    expect(agc.material, GlassMaterials.frosted);
    await tester.tapAt(
      tester.getTopLeft(find.byType(AnimatedGlassContainer)) +
          const Offset(10, 10),
    );
    expect(taps, 1);
  });

  testWidgets('drift chip reports toggling on', (tester) async {
    bool? drifting;
    await pump(tester, onDrift: (v) => drifting = v);
    await tester.tap(find.text('Drift'));
    expect(drifting, isTrue);
  });
}
