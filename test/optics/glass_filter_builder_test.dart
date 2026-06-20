import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shader asset path is package-qualified', () {
    expect(glassShaderAsset, 'packages/cins_glass_effects/shaders/glass.frag');
  });
}
