import 'dart:ui' as ui;

import '../materials/glass_material.dart';

/// Asset key for the optics shader. Package-qualified so consuming apps resolve
/// it correctly.
const String glassShaderAsset = 'packages/cins_glass_effects/shaders/glass.frag';

/// Builds an `ImageFilter.shader` for the glass optics shader. Load once
/// (async), then [build] cheaply per frame as light/material change.
class GlassFilterBuilder {
  GlassFilterBuilder(this._program);

  final ui.FragmentProgram _program;

  static Future<GlassFilterBuilder> load() async =>
      GlassFilterBuilder(await ui.FragmentProgram.fromAsset(glassShaderAsset));

  ui.ImageFilter build({
    required GlassMaterial material,
    required ui.Offset lightDir,
    required double cornerRadius,
    required bool glesYFlip,
  }) {
    final shader = _program.fragmentShader();
    final floats = material.toShaderFloats(
      lightDir: lightDir,
      cornerRadius: cornerRadius,
      yFlip: glesYFlip ? 1.0 : 0.0,
    );
    // Indices 0,1 are uSize (engine-set); our uniforms start at index 2.
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(i + 2, floats[i]);
    }
    return ui.ImageFilter.shader(shader);
  }
}
