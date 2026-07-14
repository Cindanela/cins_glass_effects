import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/showcase/specimen.dart';
import 'package:cins_glass_effects_example/showcase/specimen_page.dart';
import 'package:cins_glass_effects_example/showcase/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the specimen as glass with the given material',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SpecimenPage(
        specimen: specimens.first,
        material: GlassMaterials.frosted,
      ),
    ));
    await tester.pump();
    final gc = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(gc.material, GlassMaterials.frosted);
  });

  testWidgets('specimen box is square at the themed fraction', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SpecimenPage(
        specimen: specimens.first,
        material: GlassMaterials.liquid,
      ),
    ));
    await tester.pump();
    // Default test surface is 800×600 → shortest side 600.
    final box = tester.getSize(find.byType(GlassContainer));
    expect(box.width, box.height);
    expect(box.width, closeTo(600 * ShowcaseTheme.specimenFraction, 1));
  });
}
