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
    // Setting every uniform (material + widget rect) on the real compiled
    // shader must not range-error, proving Dart-side packing agrees with
    // glass.frag. The rect is needed because the backdrop input texture is
    // the whole render pass, not the widget bounds.
    builder.debugSetUniforms(
      material: GlassMaterials.liquid,
      light: GlassLight.topLeft,
      cornerRadius: 28,
      deviceRect: const ui.Rect.fromLTWH(90, 150, 360, 240),
    );
    builder.dispose();
  });

  group('GlassSdfFilterBuilder', () {
    Future<GlassSdfFilterBuilder> loadSdfForTest() async => GlassSdfFilterBuilder(
        await ui.FragmentProgram.fromAsset('shaders/glass_sdf.frag'));

    test('asset path is package-qualified', () {
      expect(glassSdfShaderAsset,
          'packages/cins_glass_effects/shaders/glass_sdf.frag');
    });

    testWidgets('the SDF shader compiles and accepts uniforms + texture',
        (tester) async {
      final builder = await tester.runAsync(loadSdfForTest);
      final field = SdfField.sample(const GlassShape.circle(), const ui.Size(64, 64));
      final texture = (await tester.runAsync(field.toImage))!;
      addTearDown(texture.dispose);

      // Sets all floats and binds the baked field as sampler 1 (sampler 0 is
      // the backdrop, engine-bound at filter time). Must not range-error.
      builder!.debugSetUniforms(
        material: GlassMaterials.liquid,
        light: GlassLight.topLeft,
        sdfTexture: texture,
        sdfRangePx: field.spread * 2,
        deviceRect: const ui.Rect.fromLTWH(90, 150, 360, 240),
      );
      builder.dispose();
      expect(builder.debugShader.debugDisposed, isTrue);
    });
  });
}
