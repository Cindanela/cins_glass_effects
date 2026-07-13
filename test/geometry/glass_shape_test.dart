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

    test('a stable id makes fresh builder closures equal', () {
      // Docs promise: "pass a stable id if the builder is a fresh closure each
      // build". Equality must then be decided by the id, or every rebuild
      // re-clips and re-bakes.
      final a = GlassShape.path((s) => triangle(s), id: 'tri');
      final b = GlassShape.path((s) => triangle(s), id: 'tri');
      final c = GlassShape.path((s) => triangle(s), id: 'other');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('squircle', () {
    test('clips a superellipse inscribed in the size', () {
      const shape = GlassShape.squircle();
      const size = Size(200, 200);
      final path = shape.clipPath(size);
      expect(path.contains(const Offset(100, 100)), isTrue); // centre
      expect(path.contains(const Offset(4, 4)), isFalse); // corner cut away
      // Fuller than a circle: a point outside the inscribed circle but inside
      // the squircle's shoulder.
      expect(path.contains(const Offset(170, 170)), isTrue);
    });

    test('sdf is negative inside and ~0 on the mid-edge boundary', () {
      const shape = GlassShape.squircle();
      const size = Size(200, 100);
      expect(shape.sdf(const Offset(100, 50), size), lessThan(0));
      // (width, height/2) is exactly on the superellipse boundary.
      expect(shape.sdf(const Offset(200, 50), size).abs(), lessThan(0.5));
      expect(shape.sdf(const Offset(1, 1), size), greaterThan(0));
    });

    test('exponent 2 degenerates to the inscribed ellipse', () {
      const shape = GlassShape.squircle(exponent: 2);
      const size = Size(100, 100);
      expect(shape.sdf(const Offset(50, 50), size), closeTo(-50, 0.5));
    });

    test('has an SDF, is not analytic-shader representable, equals by exponent',
        () {
      const shape = GlassShape.squircle();
      expect(shape.hasSdf, isTrue);
      expect(shape.shaderRepresentable, isFalse);
      expect(shape, const GlassShape.squircle());
      expect(shape == const GlassShape.squircle(exponent: 3), isFalse);
    });
  });

  group('normalized polygon', () {
    const unitTriangle = [Offset(0.5, 0), Offset(1, 1), Offset(0, 1)];

    test('scales unit vertices to the available size', () {
      final shape = GlassShape.normalizedPolygon(unitTriangle);
      const size = Size(200, 100);
      final bounds = shape.clipPath(size).getBounds();
      expect(bounds.width, closeTo(200, 1e-3));
      expect(bounds.height, closeTo(100, 1e-3));
      expect(shape.clipPath(size).contains(const Offset(100, 60)), isTrue);
    });

    test('sdf follows the scaled outline', () {
      final shape = GlassShape.normalizedPolygon(unitTriangle);
      const size = Size(200, 100);
      expect(shape.sdf(const Offset(100, 60), size), lessThan(0));
      expect(shape.sdf(const Offset(10, 10), size), greaterThan(0));
      // The apex (0.5, 0) scales to (100, 0) — on the boundary.
      expect(shape.sdf(const Offset(100, 0), size).abs(), lessThan(1e-6));
    });

    test('value equality over the vertex list', () {
      expect(GlassShape.normalizedPolygon(unitTriangle),
          GlassShape.normalizedPolygon(const [Offset(0.5, 0), Offset(1, 1), Offset(0, 1)]));
      expect(
        GlassShape.normalizedPolygon(unitTriangle) ==
            GlassShape.normalizedPolygon(const [Offset(0, 0), Offset(1, 1), Offset(0, 1)]),
        isFalse,
      );
    });
  });

  group('hasSdf', () {
    test('every shape with distance maths reports an SDF', () {
      expect(const GlassShape.roundedRect(8).hasSdf, isTrue);
      expect(const GlassShape.circle().hasSdf, isTrue);
      expect(
        GlassShape.polygon(const [Offset.zero, Offset(10, 0), Offset(5, 8)]).hasSdf,
        isTrue,
      );
    });

    test('a path without sdfFn has none, and poisons boolean combos', () {
      final noSdf = GlassShape.path((s) => Path()..addRect(Offset.zero & s));
      final withSdf = GlassShape.path(
        (s) => Path()..addRect(Offset.zero & s),
        sdfFn: (p, s) => 0,
      );
      expect(noSdf.hasSdf, isFalse);
      expect(withSdf.hasSdf, isTrue);
      expect(const GlassShape.circle().union(noSdf).hasSdf, isFalse);
      expect(const GlassShape.circle().union(withSdf).hasSdf, isTrue);
    });
  });
}
