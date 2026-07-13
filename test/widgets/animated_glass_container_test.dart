import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = GlassMaterial(refraction: 0, blurSigma: 0);
  const b = GlassMaterial(refraction: 10, blurSigma: 8);

  Widget host(GlassMaterial material) => Directionality(
        textDirection: TextDirection.ltr,
        child: AnimatedGlassContainer(
          duration: const Duration(milliseconds: 100),
          material: material,
          capabilities: const GlassCapabilities(shaderFiltersSupported: false),
          child: const SizedBox(width: 100, height: 60),
        ),
      );

  testWidgets('tweens the material towards the new value', (tester) async {
    await tester.pumpWidget(host(a));
    await tester.pumpWidget(host(b));
    await tester.pump(const Duration(milliseconds: 50)); // halfway, linear

    final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(glass.material.refraction, closeTo(5, 0.5));
    expect(glass.material.blurSigma, closeTo(4, 0.4));
  });

  testWidgets('settles exactly on the target material', (tester) async {
    await tester.pumpWidget(host(a));
    await tester.pumpWidget(host(b));
    await tester.pumpAndSettle();

    final glass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(glass.material, b);
  });
}
