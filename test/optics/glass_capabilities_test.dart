import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit capabilities are honoured', () {
    expect(const GlassCapabilities(shaderFiltersSupported: false).shaderFiltersSupported, isFalse);
    expect(const GlassCapabilities(shaderFiltersSupported: true).shaderFiltersSupported, isTrue);
  });

  test('detect() returns a value without throwing', () {
    expect(GlassCapabilities.detect().shaderFiltersSupported, isA<bool>());
  });
}
