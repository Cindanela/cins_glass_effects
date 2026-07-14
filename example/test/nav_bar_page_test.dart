import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:cins_glass_effects_example/showcase/nav_bar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester,
      {required bool union, ValueChanged<bool>? onChanged}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NavBarPage(union: union, onUnionChanged: onChanged ?? (_) {}),
      ),
    ));
  }

  testWidgets('separate mode: bar and FAB are two glass widgets',
      (tester) async {
    await pump(tester, union: false);
    expect(find.byType(GlassContainer), findsNWidgets(2));
  });

  testWidgets('union mode: one glass slab', (tester) async {
    await pump(tester, union: true);
    expect(find.byType(GlassContainer), findsOneWidget);
    final gc = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(gc.shape.hasSdf, isTrue);
  });

  testWidgets('toggle reports the new selection', (tester) async {
    bool? selected;
    await pump(tester, union: false, onChanged: (v) => selected = v);
    await tester.tap(find.text('Union'));
    expect(selected, isTrue);
  });

  test('union shape geometry: FAB area is glass, no hole', () {
    final shape = navBarUnionShape();
    const size = Size(360, 70);
    // FAB centre and its overhang above the bar band are inside the glass.
    expect(shape.sdf(const Offset(180, 35), size), lessThan(0));
    expect(shape.sdf(const Offset(180, 2), size), lessThan(0));
    // Above the bar band but away from the FAB is air.
    expect(shape.sdf(const Offset(20, 2), size), greaterThan(0));
  });
}
