import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roundedRect', () {
    const half = Size(50, 50);
    const r = 10.0;

    test('center is -50 (50px inside the nearest edge)', () {
      expect(ShapeSdf.roundedRect(Offset.zero, half, r), closeTo(-50, 1e-6));
    });

    test('on the straight edge is ~0', () {
      expect(ShapeSdf.roundedRect(const Offset(50, 0), half, r), closeTo(0, 1e-6));
    });

    test('10px past the edge is +10', () {
      expect(ShapeSdf.roundedRect(const Offset(60, 0), half, r), closeTo(10, 1e-6));
    });
  });

  group('circle', () {
    const r = 30.0;

    test('center is -r', () {
      expect(ShapeSdf.circle(Offset.zero, r), closeTo(-r, 1e-6));
    });

    test('on the rim is ~0', () {
      expect(ShapeSdf.circle(const Offset(30, 0), r), closeTo(0, 1e-6));
    });

    test('outside is positive distance to the rim', () {
      expect(ShapeSdf.circle(const Offset(0, 40), r), closeTo(10, 1e-6));
    });
  });

  group('boolean operators', () {
    // a = -5 (5px inside A), b = -3 (3px inside B), both points interior.
    test('union keeps the nearer (more-inside) surface', () {
      expect(ShapeSdf.union(-5, -3), -5);
      expect(ShapeSdf.union(-5, 8), -5);
    });

    test('intersection keeps the farther surface', () {
      expect(ShapeSdf.intersection(-5, -3), -3);
      expect(ShapeSdf.intersection(-5, 8), 8);
    });

    test('difference carves B out of A: a point inside both is now outside', () {
      // Inside A (-5) but also inside B (-3) -> removed -> positive distance.
      expect(ShapeSdf.difference(-5, -3), 3);
      // Inside A (-5) and outside B (+8) -> still solid -> stays inside.
      expect(ShapeSdf.difference(-5, 8), -5);
    });

    test('smoothUnion with k<=0 degrades to a hard union', () {
      expect(ShapeSdf.smoothUnion(-5, -3, 0), -5);
    });

    test('smoothUnion fuses below the hard union near the seam', () {
      // Where the two surfaces meet (equal distance), the blend dips inside.
      final hard = ShapeSdf.union(2, 2);
      final smooth = ShapeSdf.smoothUnion(2, 2, 4);
      expect(smooth, lessThan(hard));
    });
  });
}
