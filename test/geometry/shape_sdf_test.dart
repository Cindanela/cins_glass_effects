import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const half = Size(50, 50);
  const r = 10.0;

  test('center is -50 (50px inside the nearest edge)', () {
    expect(ShapeSdf.roundedRect(Offset.zero, half, r), closeTo(-50, 1e-6));
  });

  test('on the straight edge is ~0', () {
    expect(ShapeSdf.roundedRect(const Offset(50, 0), half, r), closeTo(0, 1e-6));
  });

  test('10px past the edge is +10', () {
    expect(ShapeSdf.roundedRect(const Offset(60, 0), half, r), closeTo(10, 1e-6));
  });
}
