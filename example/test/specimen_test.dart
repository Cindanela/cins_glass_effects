import 'dart:ui';

import 'package:cins_glass_effects_example/showcase/specimen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(300, 300);

  test('registry has the five spec pages with unique titles', () {
    expect(specimens, hasLength(5));
    expect(specimens.map((s) => s.title).toSet(), hasLength(5));
  });

  test('every specimen shape has an SDF (full optics, no fallback)', () {
    for (final s in specimens) {
      expect(s.shape(size).hasSdf, isTrue, reason: s.title);
    }
  });

  test('shape builders are stable: same size twice gives equal shapes', () {
    // GlassContainer rebuilds call shape(size) fresh each frame; equality is
    // what lets SdfTextureCache reuse the bake instead of re-baking.
    for (final s in specimens) {
      expect(s.shape(size), equals(s.shape(size)), reason: s.title);
    }
  });

  test('star polygon is concave: between two arms is outside, centre inside', () {
    final star =
        specimens.firstWhere((s) => s.title == 'Star polygon').shape(size);
    expect(star.sdf(const Offset(220, 90), size), greaterThan(0));
    expect(star.sdf(const Offset(150, 150), size), lessThan(0));
  });
}
