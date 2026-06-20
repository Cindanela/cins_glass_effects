import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clip path covers the size and contains the centre', () {
    const shape = GlassShape.roundedRect(16);
    final path = shape.clipPath(const Size(200, 100));
    expect(path.getBounds().width, closeTo(200, 1e-3));
    expect(path.contains(const Offset(100, 50)), isTrue);
    expect(path.contains(const Offset(-5, -5)), isFalse);
  });
}
