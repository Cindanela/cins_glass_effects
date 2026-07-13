import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The optical description of a sheet of glass. Purely data — the same
/// material renders through either the shader path or the fallback path.
@immutable
class GlassMaterial {
  const GlassMaterial({
    this.refraction = 0.0,
    this.chromaticAberration = 0.0,
    this.specular = 0.0,
    this.shininess = 32.0,
    this.fresnel = 0.0,
    this.tint = const Color(0x00FFFFFF),
    this.blurSigma = 0.0,
    this.edgeWidth = 12.0,
    this.grain = 0.0,
  });

  /// Max backdrop displacement near edges, in logical px.
  final double refraction;

  /// Per-channel offset for colour fringing, in logical px.
  final double chromaticAberration;

  /// Specular highlight strength, 0..1.
  final double specular;

  /// Specular exponent (higher = tighter highlight).
  final double shininess;

  /// Fresnel rim brightness, 0..1.
  final double fresnel;

  /// Glass colour wash (alpha = strength).
  final Color tint;

  /// Backdrop blur sigma — the "frost". Applied on both render paths.
  final double blurSigma;

  /// Width (px) of the reactive edge band that drives Fresnel/refraction.
  final double edgeWidth;

  /// Frosted-surface grain strength, 0..1 — the fine noise that makes frosted
  /// glass read as tactile instead of slick. Shader paths only.
  final double grain;

  GlassMaterial copyWith({
    double? refraction,
    double? chromaticAberration,
    double? specular,
    double? shininess,
    double? fresnel,
    Color? tint,
    double? blurSigma,
    double? edgeWidth,
    double? grain,
  }) {
    return GlassMaterial(
      refraction: refraction ?? this.refraction,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      specular: specular ?? this.specular,
      shininess: shininess ?? this.shininess,
      fresnel: fresnel ?? this.fresnel,
      tint: tint ?? this.tint,
      blurSigma: blurSigma ?? this.blurSigma,
      edgeWidth: edgeWidth ?? this.edgeWidth,
      grain: grain ?? this.grain,
    );
  }

  static GlassMaterial lerp(GlassMaterial a, GlassMaterial b, double t) {
    return GlassMaterial(
      refraction: lerpDouble(a.refraction, b.refraction, t)!,
      chromaticAberration: lerpDouble(a.chromaticAberration, b.chromaticAberration, t)!,
      specular: lerpDouble(a.specular, b.specular, t)!,
      shininess: lerpDouble(a.shininess, b.shininess, t)!,
      fresnel: lerpDouble(a.fresnel, b.fresnel, t)!,
      tint: Color.lerp(a.tint, b.tint, t)!,
      blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t)!,
      edgeWidth: lerpDouble(a.edgeWidth, b.edgeWidth, t)!,
      grain: lerpDouble(a.grain, b.grain, t)!,
    );
  }

  /// Floats for shader uniform indices 2..16. Index 0,1 are `uSize`, which the
  /// engine sets automatically for `ImageFilter.shader`. Order MUST match the
  /// uniform declaration order in `shaders/glass.frag`.
  Float32List toShaderFloats({
    required Offset lightDir,
    required double lightIntensity,
    required double cornerRadius,
  }) {
    return Float32List.fromList(<double>[
      lightDir.dx, lightDir.dy,
      refraction,
      chromaticAberration,
      specular,
      shininess,
      fresnel,
      tint.r, tint.g, tint.b, tint.a,
      cornerRadius,
      edgeWidth,
      lightIntensity,
      grain,
    ]);
  }

  /// Floats for the baked-SDF shader (`shaders/glass_sdf.frag`), indices 2..16.
  /// No corner radius — the silhouette lives entirely in the SDF texture.
  /// [sdfRangePx] is the pixel span the texture's `[0,1]` encoding maps back
  /// onto (2 × spread, pre-multiplied by the device pixel ratio). Order MUST
  /// match the uniform declaration order in `shaders/glass_sdf.frag`.
  Float32List toSdfShaderFloats({
    required Offset lightDir,
    required double lightIntensity,
    required double sdfRangePx,
  }) {
    return Float32List.fromList(<double>[
      lightDir.dx, lightDir.dy,
      refraction,
      chromaticAberration,
      specular,
      shininess,
      fresnel,
      tint.r, tint.g, tint.b, tint.a,
      edgeWidth,
      lightIntensity,
      sdfRangePx,
      grain,
    ]);
  }

  @override
  bool operator ==(Object other) =>
      other is GlassMaterial &&
      other.refraction == refraction &&
      other.chromaticAberration == chromaticAberration &&
      other.specular == specular &&
      other.shininess == shininess &&
      other.fresnel == fresnel &&
      other.tint == tint &&
      other.blurSigma == blurSigma &&
      other.edgeWidth == edgeWidth &&
      other.grain == grain;

  @override
  int get hashCode => Object.hash(
        refraction, chromaticAberration, specular, shininess,
        fresnel, tint, blurSigma, edgeWidth, grain,
      );
}
