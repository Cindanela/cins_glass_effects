import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses shader when supported, fallback otherwise', () {
    expect(
      resolveGlassRenderPath(capabilities: const GlassCapabilities(shaderFiltersSupported: true)),
      GlassRenderPath.shader,
    );
    expect(
      resolveGlassRenderPath(capabilities: const GlassCapabilities(shaderFiltersSupported: false)),
      GlassRenderPath.fallback,
    );
  });

  test('forceFallback overrides support', () {
    expect(
      resolveGlassRenderPath(
        capabilities: const GlassCapabilities(shaderFiltersSupported: true),
        forceFallback: true,
      ),
      GlassRenderPath.fallback,
    );
  });
}
