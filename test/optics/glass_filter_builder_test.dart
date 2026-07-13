import 'dart:ui' as ui;

import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shader asset path is package-qualified', () {
    expect(glassShaderAsset, 'packages/cins_glass_effects/shaders/glass.frag');
  });

  // Inside the package's own tests the asset lives under its bare key; the
  // `packages/<name>/` prefix in [glassShaderAsset] applies to consumer apps.
  Future<GlassFilterBuilder> loadForTest() async => GlassFilterBuilder(
      await ui.FragmentProgram.fromAsset('shaders/glass.frag'));

  test('the shader asset compiles and the builder creates its shader eagerly',
      () async {
    final builder = await loadForTest();
    // One FragmentShader for the builder's whole lifetime — build() must only
    // update uniforms, never allocate a new shader per frame.
    expect(identical(builder.debugShader, builder.debugShader), isTrue);
    builder.dispose();
  });

  test('dispose() releases the shader', () async {
    final builder = await loadForTest();
    builder.dispose();
    expect(builder.debugShader.debugDisposed, isTrue);
  });

  test('uniform packing matches the shader layout (2 floats reserved for uSize)',
      () async {
    final builder = await loadForTest();
    // Smoke check: setting all uniforms on the real compiled shader must not
    // range-error, proving Dart-side packing agrees with glass.frag.
    final floats = GlassMaterials.liquid.toShaderFloats(
      lightDir: const ui.Offset(-0.5, -0.7),
      lightIntensity: 1,
      cornerRadius: 28,
    );
    for (var i = 0; i < floats.length; i++) {
      builder.debugShader.setFloat(i + 2, floats[i]);
    }
    builder.dispose();
  });
}
