import 'glass_capabilities.dart';

/// Which rendering strategy a glass widget should use.
enum GlassRenderPath { shader, fallback }

/// Picks the shader path only when custom shader filters are available.
GlassRenderPath resolveGlassRenderPath({
  required GlassCapabilities capabilities,
  bool forceFallback = false,
}) {
  if (forceFallback || !capabilities.shaderFiltersSupported) {
    return GlassRenderPath.fallback;
  }
  return GlassRenderPath.shader;
}
