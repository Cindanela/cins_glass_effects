import 'dart:math' as math;
import 'dart:ui';

import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShapeSdf.polygon (universal exact SDF)', () {
    // A 10x10 square, CCW. Negative inside, 0 on an edge, positive outside.
    const square = [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)];

    test('centre is -5 (5px to the nearest edge)', () {
      expect(ShapeSdf.polygon(const Offset(5, 5), square), closeTo(-5, 1e-9));
    });

    test('on an edge is ~0', () {
      expect(ShapeSdf.polygon(const Offset(5, 0), square), closeTo(0, 1e-9));
    });

    test('outside is the positive distance to the outline', () {
      expect(ShapeSdf.polygon(const Offset(5, -3), square), closeTo(3, 1e-9));
      expect(ShapeSdf.polygon(const Offset(13, 5), square), closeTo(3, 1e-9));
    });

    test('handles concavity: a point in the notch of an arrow is outside', () {
      // A chevron/arrow whose concave notch sits around (5, 6).
      const arrow = [
        Offset(0, 0),
        Offset(5, 3),
        Offset(10, 0),
        Offset(5, 10),
      ];
      expect(ShapeSdf.polygon(const Offset(5, 1), arrow), greaterThan(0)); // in the notch
      expect(ShapeSdf.polygon(const Offset(5, 6), arrow), lessThan(0)); // in the body
    });
  });

  group('harmonicBlob', () {
    const center = Offset(100, 100);

    test('every vertex stays within [innerRadius, outerRadius]', () {
      final verts = harmonicBlob(
        center: center,
        innerRadius: 6,
        outerRadius: 15,
        harmonics: 6,
        seed: 42,
      );
      for (final v in verts) {
        final r = (v - center).distance;
        expect(r, greaterThanOrEqualTo(6 - 1e-9));
        expect(r, lessThanOrEqualTo(15 + 1e-9));
      }
    });

    test('is seamless: first and last vertices are not coincident and the '
        'loop closes smoothly across the 2π seam', () {
      final verts = harmonicBlob(center: center, samples: 360, seed: 7);
      // No duplicated closing point.
      expect(verts.first, isNot(verts.last));
      // The step across the seam (last -> first) is the same magnitude as a
      // typical interior step: no sudden jump where the wave wrapped.
      final seamStep = (verts.first - verts.last).distance;
      final interiorStep = (verts[1] - verts[0]).distance;
      expect(seamStep, closeTo(interiorStep, interiorStep * 0.6));
    });

    test('is deterministic for a given seed', () {
      final a = harmonicBlob(center: center, seed: 123);
      final b = harmonicBlob(center: center, seed: 123);
      expect(a, equals(b));
    });

    test('different seeds give different shapes', () {
      final a = harmonicBlob(center: center, seed: 1);
      final b = harmonicBlob(center: center, seed: 2);
      expect(a, isNot(equals(b)));
    });
  });

  group('harmonicBlobShape (organic glass with an exact edge)', () {
    const center = Offset(100, 100);
    final shape = harmonicBlobShape(center: center, seed: 99);

    test('sdf sign agrees with clip-path containment', () {
      final path = shape.clipPath(const Size(200, 200));
      // The centre is well inside the [6,15] annulus core -> inside both.
      expect(shape.sdf(center, const Size(200, 200)), lessThan(0));
      expect(path.contains(center), isTrue);

      // A point far outside the outer bound -> outside both.
      final far = center + const Offset(40, 0);
      expect(shape.sdf(far, const Size(200, 200)), greaterThan(0));
      expect(path.contains(far), isFalse);
    });

    test('the outline never has a sharp corner (turning angle stays shallow)', () {
      final verts = harmonicBlob(center: center, samples: 360, seed: 99);
      var maxTurn = 0.0;
      for (var i = 0; i < verts.length; i++) {
        final a = verts[i];
        final b = verts[(i + 1) % verts.length];
        final c = verts[(i + 2) % verts.length];
        final v1 = b - a;
        final v2 = c - b;
        final dot = (v1.dx * v2.dx + v1.dy * v2.dy);
        final cosAngle = (dot / (v1.distance * v2.distance)).clamp(-1.0, 1.0);
        maxTurn = math.max(maxTurn, math.acos(cosAngle));
      }
      // No vertex turns more than ~25°; a hard corner would approach 180°.
      expect(maxTurn, lessThan(25 * math.pi / 180));
    });
  });
}
