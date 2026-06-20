import 'dart:math' as math;
import 'dart:ui';

/// Pure-Dart signed-distance functions. This is the executable specification
/// of the SDF math used inside `shaders/glass.frag` (which cannot be unit
/// tested because it requires Impeller). Keep the two in lockstep.
class ShapeSdf {
  const ShapeSdf._();

  /// Signed distance from [p] (relative to the rect centre) to a rounded
  /// rectangle of half-extent [halfExtent] and uniform corner [radius].
  /// Negative inside, zero on the boundary, positive outside.
  static double roundedRect(Offset p, Size halfExtent, double radius) {
    final qx = p.dx.abs() - halfExtent.width + radius;
    final qy = p.dy.abs() - halfExtent.height + radius;
    final outside = math.sqrt(math.pow(math.max(qx, 0.0), 2) + math.pow(math.max(qy, 0.0), 2));
    final inside = math.min(math.max(qx, qy), 0.0);
    return outside + inside - radius;
  }
}
