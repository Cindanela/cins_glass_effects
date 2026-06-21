import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import '../geometry/glass_shape.dart';

/// A baked signed-distance field for a [GlassShape].
///
/// This is the bridge that removes the GPU's only shape limitation. A fragment
/// shader can't evaluate an arbitrary Dart SDF, but it *can* sample a texture —
/// so we sample the shape's exact [GlassShape.sdf] into a grid once on the CPU
/// and hand the GPU an image of it. The shader then reads `d` (and, via finite
/// differences, the gradient) from the texture, and every optical effect that
/// today only works for rounded rectangles works for *any* shape.
///
/// Distances are stored raw (logical px, negative inside). For upload they are
/// normalised into `[0, 1]` around [spread]: only the band within ±[spread] of
/// an edge needs precision (that's where refraction/Fresnel live); everything
/// deeper just reads as "fully inside/outside".
class SdfField {
  const SdfField({
    required this.width,
    required this.height,
    required this.spread,
    required this.distances,
  });

  /// Grid resolution.
  final int width;
  final int height;

  /// Half the signed-distance range (px) mapped onto the `[0, 1]` encoding.
  final double spread;

  /// Raw signed distances per texel, row-major, length `width * height`.
  final Float32List distances;

  /// Raw signed distance at grid cell ([x], [y]).
  double distanceAt(int x, int y) => distances[y * width + x];

  /// Samples [shape]'s SDF over a grid covering [size]. [resolution] is the
  /// longer side's texel count; the shorter side scales to keep texels square.
  static SdfField sample(
    GlassShape shape,
    Size size, {
    int resolution = 128,
    double spread = 32,
  }) {
    assert(resolution >= 2, 'need at least a 2-texel grid');
    assert(spread > 0, 'spread must be positive');
    final aspect = size.width / size.height;
    final int w;
    final int h;
    if (aspect >= 1) {
      w = resolution;
      h = (resolution / aspect).round().clamp(1, resolution);
    } else {
      h = resolution;
      w = (resolution * aspect).round().clamp(1, resolution);
    }

    final data = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      final py = (y + 0.5) / h * size.height; // texel centre in logical coords
      for (var x = 0; x < w; x++) {
        final px = (x + 0.5) / w * size.width;
        data[y * w + x] = shape.sdf(Offset(px, py), size);
      }
    }
    return SdfField(width: w, height: h, spread: spread, distances: data);
  }

  /// Normalised distance `[0, 1]` at cell ([x], [y]) — `0.5` is the edge,
  /// `< 0.5` inside, `> 0.5` outside, saturating at ±[spread].
  double normalizedAt(int x, int y) =>
      (0.5 + 0.5 * (distanceAt(x, y) / spread)).clamp(0.0, 1.0);

  /// Encodes the field as RGBA8 pixels (the normalised distance in every
  /// channel; opaque alpha). Ready for [decodeImageFromPixels].
  Uint8List toRgba8() {
    final bytes = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final v = (normalizedAt(x, y) * 255.0).round();
        final o = (y * width + x) * 4;
        bytes[o] = v;
        bytes[o + 1] = v;
        bytes[o + 2] = v;
        bytes[o + 3] = 255;
      }
    }
    return bytes;
  }

  /// Inverse of the channel encoding: a stored byte back to signed distance.
  double decodeByte(int channel) => (channel / 255.0 * 2 - 1) * spread;

  /// Uploads the field as a GPU-samplable [Image] (RGBA8).
  Future<Image> toImage() {
    final completer = Completer<Image>();
    decodeImageFromPixels(
      toRgba8(),
      width,
      height,
      PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
