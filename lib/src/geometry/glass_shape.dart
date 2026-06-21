import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'shape_sdf.dart';

/// The geometry of a glass surface.
///
/// A shape exposes two things the renderer needs:
///
///  * [clipPath] — the silhouette to clip the backdrop to (works for *any*
///    shape, including holes).
///  * [sdf] — the signed distance from a point to the surface boundary, which
///    is what drives the optics (refraction, Fresnel rim, specular). Because
///    the optics read distance rather than a hardcoded rounded-rect, they
///    follow whatever silhouette the shape describes.
///
/// Shapes compose: [union], [intersection] and [difference] combine two shapes
/// into a new one whose SDF is the boolean combination of its parts — so a bar
/// with a circular hole is just `bar.difference(hole)`, with a mathematically
/// exact edge around the hole.
@immutable
abstract class GlassShape {
  const GlassShape();

  /// A uniform-radius rounded rectangle filling the available size.
  const factory GlassShape.roundedRect(double cornerRadius) = RoundedRectShape;

  /// A circle inscribed in the available size (radius = half the shorter side).
  const factory GlassShape.circle() = CircleShape;

  /// A closed polygon with an exact analytic SDF — the universal escape hatch.
  /// Sample any smooth outline (a Fourier blob, a traced `Path`) into enough
  /// [vertices] and the optics get a correct edge with no shape-specific code.
  /// Vertices are absolute (top-left origin) coordinates; the closing edge is
  /// implied.
  const factory GlassShape.polygon(List<Offset> vertices) = PolygonShape;

  /// An arbitrary silhouette built from a [Path].
  ///
  /// [builder] returns the clip path for a given size. Optionally supply [sdfFn]
  /// — a signed-distance function in absolute (top-left origin) coordinates —
  /// to give the optics an exact edge; without it the path still clips and the
  /// fallback rim still follows the outline, but the analytic [GlassShape.sdf]
  /// is unavailable (it throws). [id] participates in equality so the widget
  /// knows when to re-clip; pass a stable value if the builder is a fresh
  /// closure each build.
  const factory GlassShape.path(
    Path Function(Size size) builder, {
    double Function(Offset p, Size size)? sdfFn,
    Object? id,
  }) = PathShape;

  /// The silhouette to clip to, for a surface of [size].
  Path clipPath(Size size);

  /// Signed distance (logical px) from [p] to the surface boundary, negative
  /// inside. [p] is in absolute coordinates (top-left origin), matching
  /// [clipPath]. The shader's `sdRoundedBox` is the GPU twin of this for the
  /// rounded-rect case.
  double sdf(Offset p, Size size);

  /// Representative corner radius handed to the analytic shader. Only read when
  /// [shaderRepresentable] is true.
  double get shaderCornerRadius => 0.0;

  /// Whether the analytic rounded-rect shader can render this shape *exactly*.
  /// When false the widget routes to the shape-accurate fallback rather than
  /// drawing a silhouette the shader can't represent. (Arbitrary shapes gain
  /// full shader optics once baked distance-field textures land.)
  bool get shaderRepresentable => false;

  /// A ∪ B — this shape merged with [other].
  GlassShape union(GlassShape other) => BooleanShape(BooleanOp.union, this, other);

  /// A ∩ B — only where this shape and [other] overlap.
  GlassShape intersection(GlassShape other) =>
      BooleanShape(BooleanOp.intersection, this, other);

  /// A − B — this shape with [other] carved out (e.g. a hole).
  GlassShape difference(GlassShape other) =>
      BooleanShape(BooleanOp.difference, this, other);
}

/// Centre of a surface of [size].
Offset _centre(Size size) => Offset(size.width / 2, size.height / 2);

/// A uniform-radius rounded rectangle. The one shape the analytic shader renders
/// directly; everything else composes from the SDF model and uses the fallback.
class RoundedRectShape extends GlassShape {
  const RoundedRectShape(this.cornerRadius);

  final double cornerRadius;

  /// The radius actually used at [size], clamped so it never exceeds half the
  /// shorter side (a fully-rounded square becomes a circle, not garbage).
  double _radiusFor(Size size) =>
      math.min(cornerRadius, math.min(size.width, size.height) / 2);

  @override
  Path clipPath(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(_radiusFor(size))));

  @override
  double sdf(Offset p, Size size) {
    final half = Size(size.width / 2, size.height / 2);
    return ShapeSdf.roundedRect(p - _centre(size), half, _radiusFor(size));
  }

  @override
  double get shaderCornerRadius => cornerRadius;

  @override
  bool get shaderRepresentable => true;

  @override
  bool operator ==(Object other) =>
      other is RoundedRectShape && other.cornerRadius == cornerRadius;

  @override
  int get hashCode => cornerRadius.hashCode;
}

/// A circle inscribed in the available size. Rendered via the shape-accurate
/// fallback (the fixed-radius analytic shader can't track a size-dependent
/// circle), so its rim and tint still follow the exact outline.
class CircleShape extends GlassShape {
  const CircleShape();

  double _radiusFor(Size size) => math.min(size.width, size.height) / 2;

  @override
  Path clipPath(Size size) =>
      Path()..addOval(Rect.fromCircle(center: _centre(size), radius: _radiusFor(size)));

  @override
  double sdf(Offset p, Size size) => ShapeSdf.circle(p - _centre(size), _radiusFor(size));

  @override
  bool operator ==(Object other) => other is CircleShape;

  @override
  int get hashCode => (CircleShape).hashCode;
}

enum BooleanOp { union, intersection, difference }

/// Two shapes combined by a boolean SDF operator. The result's [sdf] is the
/// operator applied to the children's distances, so the join is exact — a hole
/// punched by [difference] has a real, optically-correct rim.
class BooleanShape extends GlassShape {
  const BooleanShape(this._op, this.a, this.b);

  final BooleanOp _op;
  final GlassShape a;
  final GlassShape b;

  @override
  Path clipPath(Size size) {
    final pa = a.clipPath(size);
    final pb = b.clipPath(size);
    switch (_op) {
      case BooleanOp.union:
        return Path.combine(PathOperation.union, pa, pb);
      case BooleanOp.intersection:
        return Path.combine(PathOperation.intersect, pa, pb);
      case BooleanOp.difference:
        return Path.combine(PathOperation.difference, pa, pb);
    }
  }

  @override
  double sdf(Offset p, Size size) {
    final da = a.sdf(p, size);
    final db = b.sdf(p, size);
    switch (_op) {
      case BooleanOp.union:
        return ShapeSdf.union(da, db);
      case BooleanOp.intersection:
        return ShapeSdf.intersection(da, db);
      case BooleanOp.difference:
        return ShapeSdf.difference(da, db);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BooleanShape && other._op == _op && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(_op, a, b);
}

/// An arbitrary silhouette described by a [Path]. Clips and (via the fallback)
/// rims any outline; supply an [sdf] to also give it analytic optics.
class PathShape extends GlassShape {
  const PathShape(this.builder, {this.sdfFn, this.id});

  final Path Function(Size size) builder;
  final double Function(Offset p, Size size)? sdfFn;
  final Object? id;

  @override
  Path clipPath(Size size) => builder(size);

  @override
  double sdf(Offset p, Size size) {
    final fn = sdfFn;
    if (fn == null) {
      throw StateError(
        'PathShape has no analytic SDF. Pass `sdfFn:` to GlassShape.path, or use '
        'GlassShape.polygon (sample the outline into vertices) for an exact SDF '
        'with no extra code.',
      );
    }
    return fn(p, size);
  }

  @override
  bool operator ==(Object other) =>
      other is PathShape &&
      other.builder == builder &&
      other.sdfFn == sdfFn &&
      other.id == id;

  @override
  int get hashCode => Object.hash(builder, sdfFn, id);
}

/// A closed polygon in absolute coordinates with an exact analytic SDF.
///
/// The vertices already carry their own positions and scale, so [clipPath]
/// returns them as-is regardless of the available size (unlike the size-filling
/// [RoundedRectShape] / [CircleShape]). This is the bridge from "any outline" to
/// "fully-optical glass": sample a curve into vertices and the edge is exact.
class PolygonShape extends GlassShape {
  const PolygonShape(this.vertices)
      : assert(vertices.length >= 3, 'a polygon needs at least 3 vertices');

  final List<Offset> vertices;

  @override
  Path clipPath(Size size) {
    final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
    for (var i = 1; i < vertices.length; i++) {
      path.lineTo(vertices[i].dx, vertices[i].dy);
    }
    return path..close();
  }

  @override
  double sdf(Offset p, Size size) => ShapeSdf.polygon(p, vertices);

  @override
  bool operator ==(Object other) =>
      other is PolygonShape && listEquals(other.vertices, vertices);

  @override
  int get hashCode => Object.hashAll(vertices);
}

/// Clips a child to a [GlassShape].
class GlassClipper extends CustomClipper<Path> {
  const GlassClipper(this.shape);

  final GlassShape shape;

  @override
  Path getClip(Size size) => shape.clipPath(size);

  @override
  bool shouldReclip(GlassClipper oldClipper) => oldClipper.shape != shape;
}
