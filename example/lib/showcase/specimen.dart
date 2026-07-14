import 'dart:math' as math;
import 'dart:ui';

import 'package:cins_glass_effects/cins_glass_effects.dart';

/// One gallery entry: a shape to render as glass plus what to eyeball on it.
class Specimen {
  const Specimen({
    required this.title,
    required this.shape,
    required this.checkNote,
    this.defaultMaterial = GlassMaterials.liquid,
  });

  final String title;

  /// Builder rather than a value: the blob needs its centre in the specimen
  /// box's local coordinates, which only exist at layout time.
  final GlassShape Function(Size size) shape;

  final GlassMaterial defaultMaterial;

  /// One-line "what to eyeball" hint, shown in the chrome header.
  final String checkNote;
}

/// Alternating outer/inner vertices of a star in the unit square, starting
/// from the top point.
List<Offset> starUnitVertices({
  int points = 5,
  double innerRadius = 0.22,
  double outerRadius = 0.48,
}) {
  return List.generate(points * 2, (i) {
    final r = i.isEven ? outerRadius : innerRadius;
    final angle = -math.pi / 2 + i * math.pi / points;
    return Offset(0.5 + r * math.cos(angle), 0.5 + r * math.sin(angle));
  });
}

final List<Specimen> specimens = [
  Specimen(
    title: 'Rounded rect',
    checkNote:
        'Analytic shader. Corners must match the clip; no dark hairlines on the sides.',
    shape: (_) => const GlassShape.roundedRect(32),
  ),
  Specimen(
    title: 'Circle',
    checkNote: 'Baked SDF. Rim should be a perfect, even ring.',
    shape: (_) => const GlassShape.circle(),
  ),
  Specimen(
    title: 'Squircle',
    checkNote:
        'Baked SDF. Corners smooth, edge band uniform all the way around.',
    shape: (_) => const GlassShape.squircle(),
  ),
  Specimen(
    title: 'Harmonic blob',
    checkNote: 'Baked SDF. Curves smooth — no staircase edges.',
    shape: (size) => harmonicBlobShape(
      center: Offset(size.width / 2, size.height / 2),
      innerRadius: size.shortestSide * 0.30,
      outerRadius: size.shortestSide * 0.46,
      seed: 7,
    ),
  ),
  Specimen(
    title: 'Star polygon',
    checkNote: 'Baked SDF, concave. Notches must show correct edge optics.',
    shape: (_) => GlassShape.normalizedPolygon(starUnitVertices()),
  ),
];
