import 'dart:ui' as ui;

/// Runtime rendering capabilities relevant to glass effects.
class GlassCapabilities {
  const GlassCapabilities({required this.shaderFiltersSupported});

  /// Probes the real engine. `ImageFilter.shader` requires Impeller.
  factory GlassCapabilities.detect() =>
      GlassCapabilities(shaderFiltersSupported: ui.ImageFilter.isShaderFilterSupported);

  /// Whether `ui.ImageFilter.shader` can be used on this backend.
  final bool shaderFiltersSupported;
}
