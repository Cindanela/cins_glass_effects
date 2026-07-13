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
