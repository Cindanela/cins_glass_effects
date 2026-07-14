import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/showcase/controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    GlassMaterial material = GlassMaterials.liquid,
    int presetIndex = 0,
    bool expanded = false,
    ValueChanged<int>? onPreset,
    ValueChanged<GlassMaterial>? onMaterial,
    VoidCallback? onToggle,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ControlsDrawer(
          material: material,
          presetIndex: presetIndex,
          expanded: expanded,
          onPresetSelected: onPreset ?? (_) {},
          onMaterialChanged: onMaterial ?? (_) {},
          onToggleExpanded: onToggle ?? () {},
        ),
      ),
    ));
  }

  testWidgets('preset chip tap reports its index', (tester) async {
    int? selected;
    await pump(tester, onPreset: (i) => selected = i);
    await tester.tap(find.text('Frosted'));
    expect(selected, 1);
  });

  testWidgets('collapsed hides sliders, expanded shows all six',
      (tester) async {
    await pump(tester);
    expect(find.byType(Slider), findsNothing);
    await pump(tester, expanded: true);
    expect(find.byType(Slider), findsNWidgets(6));
  });

  testWidgets('edge width slider emits a copyWith-modified material',
      (tester) async {
    GlassMaterial? changed;
    await pump(tester, expanded: true, onMaterial: (m) => changed = m);
    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    expect(changed, isNotNull);
    expect(changed!.edgeWidth, isNot(GlassMaterials.liquid.edgeWidth));
    expect(changed!.refraction, GlassMaterials.liquid.refraction);
  });

  testWidgets('reset restores the selected preset', (tester) async {
    GlassMaterial? changed;
    await pump(
      tester,
      expanded: true,
      material: GlassMaterials.liquid.copyWith(edgeWidth: 40),
      onMaterial: (m) => changed = m,
    );
    await tester.tap(find.text('Reset'));
    expect(changed, GlassMaterials.liquid);
  });
}
