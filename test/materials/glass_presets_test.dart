import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('liquid preset is refractive and specular', () {
    expect(GlassMaterials.liquid.refraction, greaterThan(0));
    expect(GlassMaterials.liquid.specular, greaterThan(0));
    expect(GlassMaterials.liquid.chromaticAberration, greaterThan(0));
  });
}
