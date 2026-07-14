import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/main.dart';
import 'package:cins_glass_effects_example/showcase/backdrops.dart';
import 'package:cins_glass_effects_example/showcase/specimen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots on the first specimen with title and check note',
      (tester) async {
    await tester.pumpWidget(const GlassGalleryApp());
    await tester.pump();
    expect(find.text(specimens.first.title), findsOneWidget);
    expect(find.text(specimens.first.checkNote), findsOneWidget);
  });

  testWidgets('swiping walks every page through to Animation',
      (tester) async {
    await tester.pumpWidget(const GlassGalleryApp());
    await tester.pump();
    for (var i = 1; i < specimens.length; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text(specimens[i].title), findsOneWidget);
    }
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Nav bar + FAB'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Animation'), findsOneWidget);
  });

  testWidgets('material chip swaps the specimen material', (tester) async {
    await tester.pumpWidget(const GlassGalleryApp());
    await tester.pump();
    await tester.tap(find.text('Frosted'));
    await tester.pump();
    final gc = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(gc.material, GlassMaterials.frosted);
  });

  testWidgets('backdrop button cycles the backdrop', (tester) async {
    await tester.pumpWidget(const GlassGalleryApp());
    await tester.pump();
    expect(
      tester.widget<BackdropView>(find.byType(BackdropView)).backdrop,
      ShowcaseBackdrop.gradient,
    );
    await tester.tap(find.byIcon(ShowcaseBackdrop.gradient.icon));
    await tester.pump();
    expect(
      tester.widget<BackdropView>(find.byType(BackdropView)).backdrop,
      ShowcaseBackdrop.plain,
    );
  });
}
