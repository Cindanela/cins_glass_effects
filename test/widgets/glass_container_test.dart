import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('falls back to ClipPath + BackdropFilter without shader support',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const ColoredBox(color: Colors.orange),
            GlassContainer(
              capabilities: const GlassCapabilities(shaderFiltersSupported: false),
              material: GlassMaterials.liquid,
              shape: const GlassShape.roundedRect(20),
              child: const SizedBox(width: 120, height: 80),
            ),
          ],
        ),
      ),
    );

    expect(find.byType(ClipPath), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
