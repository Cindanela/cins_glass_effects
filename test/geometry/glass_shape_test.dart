import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roundedRect', () {
    test('clip path covers the size and contains the centre', () {
      const shape = GlassShape.roundedRect(16);
      final path = shape.clipPath(const Size(200, 100));
      expect(path.getBounds().width, closeTo(200, 1e-3));
      expect(path.contains(const Offset(100, 50)), isTrue);
      expect(path.contains(const Offset(-5, -5)), isFalse);
    });

    test('radius is clamped to half the shorter side', () {
      // A huge radius on a square becomes a circle, not a broken shape: the
      // SDF at a corner stays positive (corner is outside the rounded form).
      const shape = GlassShape.roundedRect(9999);
      const size = Size(100, 100);
      expect(shape.sdf(const Offset(2, 2), size), greaterThan(0));
      expect(shape.sdf(const Offset(50, 50), size), closeTo(-50, 1e-6));
    });

    test('is the only shape the analytic shader renders directly', () {
      expect(const GlassShape.roundedRect(8).shaderRepresentable, isTrue);
      expect(const GlassShape.circle().shaderRepresentable, isFalse);
    });

    test('equality drives re-clip decisions', () {
      expect(const GlassShape.roundedRect(8), const GlassShape.roundedRect(8));
      expect(const GlassShape.roundedRect(8) == const GlassShape.roundedRect(12), isFalse);
    });
  });

  group('circle', () {
    test('clips to a circle inscribed in the size', () {
      const shape = GlassShape.circle();
      const size = Size(120, 80); // shorter side 80 -> radius 40
      final path = shape.clipPath(size);
      expect(path.contains(const Offset(60, 40)), isTrue); // centre
      expect(path.contains(const Offset(2, 2)), isFalse); // corner is outside
      expect(shape.sdf(const Offset(60, 40), size), closeTo(-40, 1e-6));
    });
  });

  group('arbitrary path', () {
    Path triangle(Size size) => Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    test('clips to the supplied outline', () {
      const size = Size(100, 100);
      final shape = GlassShape.path(triangle);
      final path = shape.clipPath(size);
      expect(path.contains(const Offset(50, 60)), isTrue); // inside the triangle
      expect(path.contains(const Offset(5, 5)), isFalse); // top-left, cut away
    });

    test('sdf throws without an analytic function, but clipPath still works', () {
      final shape = GlassShape.path(triangle);
      expect(() => shape.sdf(Offset.zero, const Size(100, 100)), throwsStateError);
      expect(shape.clipPath(const Size(100, 100)).getBounds().height, closeTo(100, 1e-3));
    });

    test('routes to the fallback, never the analytic shader', () {
      expect(GlassShape.path(triangle).shaderRepresentable, isFalse);
    });
  });
}
