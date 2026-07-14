import 'package:cins_glass_effects_example/showcase/backdrops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('next cycles through all backdrops and wraps', () {
    expect(ShowcaseBackdrop.gradient.next, ShowcaseBackdrop.plain);
    expect(ShowcaseBackdrop.plain.next, ShowcaseBackdrop.scrolling);
    expect(ShowcaseBackdrop.scrolling.next, ShowcaseBackdrop.gradient);
  });

  testWidgets('every backdrop builds and survives a frame of animation',
      (tester) async {
    for (final b in ShowcaseBackdrop.values) {
      await tester.pumpWidget(MaterialApp(home: BackdropView(backdrop: b)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BackdropView), findsOneWidget);
    }
  });
}
