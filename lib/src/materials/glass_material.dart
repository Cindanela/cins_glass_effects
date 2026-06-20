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

  /// Backdrop blur sigma (used by the fallback path; subtle in shader path).
  final double blurSigma;

  /// Width (px) of the reactive edge band that drives Fresnel/refraction.
  final double edgeWidth;

  GlassMaterial copyWith({
    double? refraction,
    double? chromaticAberration,
    double? specular,
    double? shininess,
    double? fresnel,
    Color? tint,
    double? blurSigma,
    double? edgeWidth,
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
    );
  }

  /// Floats for shader uniform indices 2..15. Index 0,1 are `uSize`, which the
  /// engine sets automatically for `ImageFilter.shader`. Order MUST match the
  /// uniform declaration order in `shaders/glass.frag`.
  Float32List toShaderFloats({
    required Offset lightDir,
    required double cornerRadius,
    required double yFlip,
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
      yFlip,
      blurSigma,
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
      other.edgeWidth == edgeWidth;

  @override
  int get hashCode => Object.hash(
        refraction, chromaticAberration, specular, shininess,
        fresnel, tint, blurSigma, edgeWidth,
      );
}
