import 'dart:math' as math;
import 'dart:ui';

import 'glass_shape.dart';

/// Generators that produce shape geometry from maths rather than hand-authored
/// paths. The output is plain vertices, so it feeds straight into
/// [GlassShape.polygon] (exact SDF, fully-optical) or any `Path`.

/// Builds the vertices of a smooth organic "blob" — a **parametric harmonic
/// curve**: a circle whose radius is perturbed by a sum of sine waves
/// (a Fourier series wrapped around the centre).
///
/// The radius is guaranteed to stay within `[innerRadius, outerRadius]`: each
/// component is normalised so the combined wave can never exceed ±1 of the
/// mid-radius. Because every harmonic uses an **integer** frequency, the curve
/// closes seamlessly at 2π with no corner or visible seam, and with enough
/// [samples] it is smooth (no hard edges).
///
/// Pass a [seed] for a deterministic, reproducible shape (essential for tests);
/// omit it for a fresh random blob each call.
///
/// * [center] — centre of the blob, in the same coordinate space you'll clip in.
/// * [harmonics] — how many overlapping sine waves (more ⇒ busier outline).
/// * [minFrequency]/[maxFrequency] — integer frequency range per harmonic
///   (≥ 2 keeps the centre of mass at [center] rather than lopsiding it).
/// * [samples] — vertices around the loop (more ⇒ smoother).
List<Offset> harmonicBlob({
  required Offset center,
  double innerRadius = 6,
  double outerRadius = 15,
  int harmonics = 5,
  int minFrequency = 2,
  int maxFrequency = 7,
  int samples = 240,
  int? seed,
}) {
  assert(innerRadius > 0 && outerRadius > innerRadius, 'need 0 < inner < outer');
  assert(harmonics >= 1, 'need at least one harmonic');
  assert(maxFrequency >= minFrequency, 'frequency range is inverted');
  assert(samples >= 8, 'need enough samples for a smooth loop');

  final rng = math.Random(seed);
  final freqs = List<int>.generate(
    harmonics,
    (_) => minFrequency + rng.nextInt(maxFrequency - minFrequency + 1),
  );
  final amps = List<double>.generate(harmonics, (_) => rng.nextDouble());
  final phases = List<double>.generate(harmonics, (_) => rng.nextDouble() * 2 * math.pi);

  // Normalising by the sum of amplitudes caps the combined wave at ±1, which is
  // what keeps the radius strictly inside [innerRadius, outerRadius].
  final ampSum = amps.fold<double>(0, (a, b) => a + b);
  final mid = (innerRadius + outerRadius) / 2;
  final span = (outerRadius - innerRadius) / 2;

  final verts = <Offset>[];
  for (var i = 0; i < samples; i++) {
    final theta = (i / samples) * 2 * math.pi;
    var wave = 0.0;
    for (var k = 0; k < harmonics; k++) {
      wave += amps[k] * math.sin(freqs[k] * theta + phases[k]);
    }
    final norm = ampSum == 0 ? 0.0 : wave / ampSum; // in [-1, 1]
    final r = mid + span * norm; // in [innerRadius, outerRadius]
    verts.add(center + Offset(math.cos(theta), math.sin(theta)) * r);
  }
  return verts;
}

/// A [GlassShape] built from [harmonicBlob] — organic glass with an exact edge,
/// ready to drop into a `GlassContainer`. See [harmonicBlob] for the parameters.
GlassShape harmonicBlobShape({
  required Offset center,
  double innerRadius = 6,
  double outerRadius = 15,
  int harmonics = 5,
  int minFrequency = 2,
  int maxFrequency = 7,
  int samples = 240,
  int? seed,
}) {
  return GlassShape.polygon(harmonicBlob(
    center: center,
    innerRadius: innerRadius,
    outerRadius: outerRadius,
    harmonics: harmonics,
    minFrequency: minFrequency,
    maxFrequency: maxFrequency,
    samples: samples,
    seed: seed,
  ));
}
