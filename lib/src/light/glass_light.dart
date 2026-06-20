import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A light striking the glass: a 2D incoming direction and an intensity.
@immutable
class GlassLight {
  const GlassLight({required this.direction, this.intensity = 1.0});

  final Offset direction;
  final double intensity;

  static const GlassLight topLeft = GlassLight(direction: Offset(-0.5, -0.7));

  @override
  bool operator ==(Object other) =>
      other is GlassLight && other.direction == direction && other.intensity == intensity;

  @override
  int get hashCode => Object.hash(direction, intensity);
}

/// The contract glass widgets consume. Implementations are [Listenable].
typedef GlassLightSource = ValueListenable<GlassLight>;

/// App-controlled light (default, zero dependencies).
class ManualLightSource extends ValueNotifier<GlassLight> {
  ManualLightSource([super.value = GlassLight.topLeft]);
}

/// Opt-in adaptor: pipe any stream (e.g. `sensors_plus` gyroscope, mapped to a
/// [GlassLight]) into the glass without the package depending on sensors.
class StreamLightSource extends ValueNotifier<GlassLight> {
  StreamLightSource(Stream<GlassLight> stream, {GlassLight initial = GlassLight.topLeft})
      : super(initial) {
    _sub = stream.listen((light) => value = light);
  }

  late final StreamSubscription<GlassLight> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Light that follows a pointer. Centre of the surface = head-on (zero) light.
class PointerLightSource extends ValueNotifier<GlassLight> {
  PointerLightSource() : super(GlassLight.topLeft);

  void update(Offset localPosition, Size size) {
    final dx = (localPosition.dx / size.width) * 2 - 1;
    final dy = (localPosition.dy / size.height) * 2 - 1;
    value = GlassLight(direction: Offset(dx, dy));
  }
}
