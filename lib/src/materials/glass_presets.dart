import 'dart:ui';

import 'glass_material.dart';

/// Named glass recipes. Each "type" of glass is just a tuned [GlassMaterial].
abstract final class GlassMaterials {
  /// Apple-style "liquid" glass: strong refraction, visible fringing, glossy.
  static const GlassMaterial liquid = GlassMaterial(
    refraction: 14,
    chromaticAberration: 3,
    specular: 0.7,
    shininess: 48,
    fresnel: 0.6,
    tint: Color(0x14FFFFFF),
    blurSigma: 2,
    edgeWidth: 18,
  );

  /// Clean, nearly-clear glass with light refraction and a crisp rim.
  static const GlassMaterial clear = GlassMaterial(
    refraction: 8,
    chromaticAberration: 1.5,
    specular: 0.5,
    shininess: 64,
    fresnel: 0.5,
    tint: Color(0x0AFFFFFF),
    blurSigma: 0.5,
    edgeWidth: 14,
  );
}
