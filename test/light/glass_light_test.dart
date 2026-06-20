import 'dart:async';
import 'dart:ui';
import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual source notifies on change', () {
    final src = ManualLightSource(const GlassLight(direction: Offset(0, -1)));
    var notified = 0;
    src.addListener(() => notified++);
    src.value = const GlassLight(direction: Offset(1, 0));
    expect(notified, 1);
    expect(src.value.direction, const Offset(1, 0));
  });

  test('stream source tracks the latest event', () async {
    final ctrl = StreamController<GlassLight>();
    final src = StreamLightSource(ctrl.stream);
    ctrl.add(const GlassLight(direction: Offset(0.3, 0.4)));
    await Future<void>.delayed(Duration.zero);
    expect(src.value.direction, const Offset(0.3, 0.4));
    await ctrl.close();
    src.dispose();
  });

  test('pointer source maps centre to zero direction', () {
    final src = PointerLightSource();
    src.update(const Offset(50, 50), const Size(100, 100));
    expect(src.value.direction.dx, closeTo(0, 1e-6));
    expect(src.value.direction.dy, closeTo(0, 1e-6));
  });
}
