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
  );

  test('value equality + copyWith', () {
    expect(m, equals(m.copyWith()));
    expect(m.copyWith(refraction: 99).refraction, 99);
    expect(m == m.copyWith(refraction: 99), isFalse);
  });

  test('lerp interpolates fields', () {
    final a = const GlassMaterial(refraction: 0);
    final b = const GlassMaterial(refraction: 10);
    expect(GlassMaterial.lerp(a, b, 0.5).refraction, closeTo(5, 1e-6));
  });

  test('toShaderFloats packs uniforms in declared order', () {
    final f = m.toShaderFloats(lightDir: const Offset(0.1, 0.2), cornerRadius: 24, yFlip: 1);
    // [lx, ly, refraction, chroma, specular, shininess, fresnel, r,g,b,a, corner, edge, yflip]
    expect(f.length, 14);
    expect(f[0], closeTo(0.1, 1e-6));   // lightDir.x  -> shader idx 2
    expect(f[1], closeTo(0.2, 1e-6));   // lightDir.y  -> idx 3
    expect(f[2], closeTo(12, 1e-6));    // refraction  -> idx 4
    expect(f[10], closeTo(0x80 / 255, 1e-6)); // tint.a -> idx 12
    expect(f[11], closeTo(24, 1e-6));   // cornerRadius-> idx 13
    expect(f[13], closeTo(1, 1e-6));    // yFlip       -> idx 15
  });
}
