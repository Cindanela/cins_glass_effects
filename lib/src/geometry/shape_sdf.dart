import 'dart:math' as math;
import 'dart:ui';

/// Pure-Dart signed-distance functions and the boolean operators that compose
/// them. This is the executable specification of the SDF math used inside
/// `shaders/glass.frag` (which cannot be unit tested because it requires
/// Impeller). Keep the two in lockstep.
///
/// Convention: points are expressed relative to the primitive's centre.
/// Distance is negative inside the shape, zero on the boundary, positive
/// outside. Because every primitive returns a true signed distance, the
/// operators below combine them into arbitrary shapes whose edges the glass
/// optics (refraction, Fresnel, specular) follow automatically.
class ShapeSdf {
  const ShapeSdf._();

  /// Signed distance from [p] (relative to the rect centre) to a rounded
  /// rectangle of half-extent [halfExtent] and uniform corner [radius].
  static double roundedRect(Offset p, Size halfExtent, double radius) {
    final qx = p.dx.abs() - halfExtent.width + radius;
    final qy = p.dy.abs() - halfExtent.height + radius;
    final outside = math.sqrt(math.pow(math.max(qx, 0.0), 2) + math.pow(math.max(qy, 0.0), 2));
    final inside = math.min(math.max(qx, qy), 0.0);
    return outside + inside - radius;
  }

  /// Signed distance from [p] (relative to the circle centre) to a circle of
  /// the given [radius].
  static double circle(Offset p, double radius) => p.distance - radius;

  /// Signed distance to an axis-aligned box (sharp corners) — a [roundedRect]
  /// with zero radius, spelled out for clarity at call sites.
  static double box(Offset p, Size halfExtent) => roundedRect(p, halfExtent, 0.0);

  /// Exact signed distance from [p] to a closed polygon [v] (vertices in
  /// order, the closing edge implied). Negative inside, zero on an edge,
  /// positive outside — for *any* polygon, convex or concave.
  ///
  /// This is the universal SDF: sample any smooth outline (a Fourier blob, a
  /// hand-drawn `Path`) into enough vertices and this gives its glass edge with
  /// no shape-specific code. [p] and [v] share one coordinate space.
  ///
  /// Distance magnitude uses point-to-segment distance; the sign comes from a
  /// crossing-number (winding) test, so concavities are handled correctly.
  /// (Port of Inigo Quilez's `sdPolygon`.)
  static double polygon(Offset p, List<Offset> v) {
    final n = v.length;
    assert(n >= 3, 'polygon needs at least 3 vertices');
    var d = _dot(p - v[0], p - v[0]);
    var s = 1.0;
    for (var i = 0, j = n - 1; i < n; j = i, i++) {
      final e = v[j] - v[i];
      final w = p - v[i];
      final ee = _dot(e, e);
      final t = ee == 0.0 ? 0.0 : (_dot(w, e) / ee).clamp(0.0, 1.0);
      final b = w - e * t;
      d = math.min(d, _dot(b, b));
      final c1 = p.dy >= v[i].dy;
      final c2 = p.dy < v[j].dy;
      final c3 = e.dx * w.dy > e.dy * w.dx;
      if ((c1 && c2 && c3) || (!c1 && !c2 && !c3)) s = -s;
    }
    return s * math.sqrt(d);
  }

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  // --- Boolean operators -------------------------------------------------
  // These mirror the canonical GLSL SDF combinators. They take and return
  // signed distances, so they chain freely: difference(union(a, b), c), etc.

  /// Union (A ∪ B): the nearer surface wins.
  static double union(double a, double b) => math.min(a, b);

  /// Intersection (A ∩ B): the farther surface wins.
  static double intersection(double a, double b) => math.max(a, b);

  /// Difference (A − B): carve B out of A. This is what punches a hole.
  static double difference(double a, double b) => math.max(a, -b);

  /// Smooth union with blend radius [k] — fuses A and B with a rounded seam
  /// (a "metaball" join) instead of a hard crease.
  static double smoothUnion(double a, double b, double k) {
    if (k <= 0.0) return union(a, b);
    final h = (0.5 + 0.5 * (b - a) / k).clamp(0.0, 1.0);
    return (b + (a - b) * h) - k * h * (1.0 - h);
  }
}
