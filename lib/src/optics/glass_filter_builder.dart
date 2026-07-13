import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../light/glass_light.dart';
import '../materials/glass_material.dart';

/// Asset key for the optics shader. Package-qualified so consuming apps resolve
/// it correctly.
const String glassShaderAsset = 'packages/cins_glass_effects/shaders/glass.frag';

/// Builds an `ImageFilter.shader` for the glass optics shader. Load once
/// (async), then [build] cheaply per frame as light/material change.
///
/// Owns a single [ui.FragmentShader] for its whole lifetime — [build] only
/// updates uniforms on it (shader allocation per frame causes jank and leaks
/// GPU state). Call [dispose] when the owning widget goes away.
class GlassFilterBuilder {
  GlassFilterBuilder(ui.FragmentProgram program) : _shader = program.fragmentShader();

  final ui.FragmentShader _shader;

  static Future<GlassFilterBuilder> load() async =>
      GlassFilterBuilder(await ui.FragmentProgram.fromAsset(glassShaderAsset));

  /// The reused shader instance, for tests only.
  @visibleForTesting
  ui.FragmentShader get debugShader => _shader;

  ui.ImageFilter build({
    required GlassMaterial material,
    required GlassLight light,
    required double cornerRadius,
  }) {
    final floats = material.toShaderFloats(
      lightDir: light.direction,
      lightIntensity: light.intensity,
      cornerRadius: cornerRadius,
    );
    // Indices 0,1 are uSize (engine-set); our uniforms start at index 2.
    for (var i = 0; i < floats.length; i++) {
      _shader.setFloat(i + 2, floats[i]);
    }
    return ui.ImageFilter.shader(_shader);
  }

  void dispose() => _shader.dispose();
}

/// Asset key for the baked-SDF optics shader (arbitrary silhouettes).
const String glassSdfShaderAsset =
    'packages/cins_glass_effects/shaders/glass_sdf.frag';

/// Builds an `ImageFilter.shader` for the baked-SDF glass shader: the same
/// optics as [GlassFilterBuilder], but the shape is a signed-distance texture
/// (baked by `SdfField`) instead of an analytic rounded rect — so any
/// silhouette gets full shader fidelity.
///
/// Same lifecycle contract as [GlassFilterBuilder]: one shader per builder,
/// [build] only updates uniforms, [dispose] when the owning widget goes away.
class GlassSdfFilterBuilder {
  GlassSdfFilterBuilder(ui.FragmentProgram program)
      : _shader = program.fragmentShader();

  final ui.FragmentShader _shader;

  static Future<GlassSdfFilterBuilder> load() async => GlassSdfFilterBuilder(
      await ui.FragmentProgram.fromAsset(glassSdfShaderAsset));

  /// The reused shader instance, for tests only.
  @visibleForTesting
  ui.FragmentShader get debugShader => _shader;

  ui.ImageFilter build({
    required GlassMaterial material,
    required GlassLight light,
    required ui.Image sdfTexture,
    required double sdfRangePx,
  }) {
    final floats = material.toSdfShaderFloats(
      lightDir: light.direction,
      lightIntensity: light.intensity,
      sdfRangePx: sdfRangePx,
    );
    for (var i = 0; i < floats.length; i++) {
      _shader.setFloat(i + 2, floats[i]);
    }
    // Sampler 0 is the backdrop — the engine binds it when the filter runs.
    _shader.setImageSampler(1, sdfTexture);
    return ui.ImageFilter.shader(_shader);
  }

  void dispose() => _shader.dispose();
}
