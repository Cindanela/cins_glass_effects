import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quality exposes sample/blur budgets ascending', () {
    expect(GlassQuality.low.refractionSamples, lessThan(GlassQuality.high.refractionSamples));
    expect(GlassQuality.high.blurPasses, 3);
  });
}
