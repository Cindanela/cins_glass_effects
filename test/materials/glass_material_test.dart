import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const m = GlassMaterial(
    refraction: 12,
    chromaticAberration: 3,
    specular: 0.5,
    shininess: 32,
    fresnel: 0.6,
    tint: Color(0x80112233),
    blurSigma: 2,
    edgeWidth: 18,
    grain: 0.4,
  );

  test('grain defaults to 0 and participates in copyWith/lerp/equality', () {
    expect(const GlassMaterial().grain, 0);
    expect(m.copyWith(grain: 0.8).grain, 0.8);
    expect(m == m.copyWith(grain: 0.8), isFalse);
    final mid = GlassMaterial.lerp(const GlassMaterial(), m, 0.5);
    expect(mid.grain, closeTo(0.2, 1e-6));
  });

  test('value equality + copyWith', () {
    expect(m, equals(m.copyWith()));
    expect(m.copyWith(refraction: 99).refraction, 99);
    expect(m == m.copyWith(refraction: 99), isFalse);
  });

  test('lerp interpolates fields', () {
    const a = GlassMaterial(
      refraction: 0,
      tint: Color(0x00000000),
      edgeWidth: 10,
    );
    const b = GlassMaterial(
      refraction: 10,
      tint: Color(0xFFFFFFFF),
      edgeWidth: 20,
    );
    final mid = GlassMaterial.lerp(a, b, 0.5);
    expect(mid.refraction, closeTo(5, 1e-6));
    expect(mid.edgeWidth, closeTo(15, 1e-6));
    expect(mid.tint, Color.lerp(const Color(0x00000000), const Color(0xFFFFFFFF), 0.5));
  });

  test('toShaderFloats packs uniforms in declared order', () {
    final f = m.toShaderFloats(
      lightDir: const Offset(0.1, 0.2),
      lightIntensity: 0.75,
      cornerRadius: 24,
    );
    // [lx, ly, refraction, chroma, specular, shininess, fresnel, r,g,b,a,
    //  corner, edge, intensity, grain]
    expect(f.length, 15);
    expect(f[0], closeTo(0.1, 1e-6));   // lightDir.x  -> shader idx 2
    expect(f[1], closeTo(0.2, 1e-6));   // lightDir.y  -> idx 3
    expect(f[2], closeTo(12, 1e-6));    // refraction  -> idx 4
    expect(f[10], closeTo(0x80 / 255, 1e-6)); // tint.a -> idx 12
    expect(f[11], closeTo(24, 1e-6));   // cornerRadius-> idx 13
    expect(f[12], closeTo(18, 1e-6));   // edgeWidth   -> idx 14
    expect(f[13], closeTo(0.75, 1e-6)); // intensity   -> idx 15
    expect(f[14], closeTo(0.4, 1e-6));  // grain       -> idx 16
  });

  test('toSdfShaderFloats packs uniforms for the baked-SDF shader', () {
    final f = m.toSdfShaderFloats(
      lightDir: const Offset(0.1, 0.2),
      lightIntensity: 0.75,
      sdfRangePx: 96,
    );
    // [lx, ly, refraction, chroma, specular, shininess, fresnel, r,g,b,a,
    //  edgeWidth, intensity, sdfRange, grain] — no cornerRadius (shape lives
    //  in the texture), sdfRange decodes the baked distance back to pixels.
    expect(f.length, 15);
    expect(f[0], closeTo(0.1, 1e-6));   // lightDir.x -> shader idx 2
    expect(f[2], closeTo(12, 1e-6));    // refraction -> idx 4
    expect(f[10], closeTo(0x80 / 255, 1e-6)); // tint.a -> idx 12
    expect(f[11], closeTo(18, 1e-6));   // edgeWidth  -> idx 13
    expect(f[12], closeTo(0.75, 1e-6)); // intensity  -> idx 14
    expect(f[13], closeTo(96, 1e-6));   // sdfRangePx -> idx 15
    expect(f[14], closeTo(0.4, 1e-6));  // grain      -> idx 16
  });
}
