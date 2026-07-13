import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../geometry/glass_shape.dart';
import 'sdf_field.dart';

/// Owns the baked SDF texture for one glass surface.
///
/// Baking (CPU-sample the shape's SDF, upload as an image) is asynchronous and
/// costs a few milliseconds, so it must never happen per frame. This cache
/// bakes once per (shape, size) and answers synchronously from then on:
///
///  * [textureFor] — the exact texture for the current shape and size, or null.
///  * [latestTexture] — the most recent successful bake even if stale (e.g.
///    mid-resize), so the widget can keep rendering glass instead of flashing
///    back to the fallback while the rebake runs.
///  * [ensure] — starts a bake if the requested key isn't baked or in flight;
///    a newer request supersedes an older unfinished one.
class SdfTextureCache {
  ui.Image? _image;
  _BakeKey? _imageKey;
  _BakeKey? _pendingKey;
  int _generation = 0;

  /// Distance band (logical px) encoded around the edge. Optics only need the
  /// band where refraction/Fresnel live; deeper just reads fully inside/out.
  final double spread;

  SdfTextureCache({this.spread = 32});

  /// The pixel span the texture's `[0,1]` encoding maps onto (2 × [spread]),
  /// scaled by [devicePixelRatio] to match the shader's fragment coordinates.
  double sdfRangePx(double devicePixelRatio) => 2 * spread * devicePixelRatio;

  /// The baked texture for exactly ([shape], [size]), or null if not (yet) baked.
  ui.Image? textureFor(GlassShape shape, ui.Size size) =>
      _imageKey == _keyFor(shape, size) ? _image : null;

  /// The most recent successful bake, possibly for an older shape/size.
  ui.Image? get latestTexture => _image;

  /// Ensures a texture for ([shape], [size]) exists or is being baked.
  /// [onReady] fires (once) when a bake completes and is still the newest
  /// request — call `setState` there. No-op if already baked or in flight.
  void ensure(GlassShape shape, ui.Size size, {required VoidCallback onReady}) {
    if (size.isEmpty) return;
    final key = _keyFor(shape, size);
    if (_imageKey == key || _pendingKey == key) return;
    _pendingKey = key;
    final generation = ++_generation;
    final field =
        SdfField.sample(shape, size, resolution: key.resolution, spread: spread);
    field.toImage().then((image) {
      if (generation != _generation) {
        image.dispose(); // superseded by a newer request (or disposed)
        return;
      }
      _image?.dispose();
      _image = image;
      _imageKey = key;
      _pendingKey = null;
      onReady();
    });
  }

  void dispose() {
    _generation++; // orphan any in-flight bake so its image gets dropped
    _image?.dispose();
    _image = null;
    _imageKey = null;
    _pendingKey = null;
  }

  _BakeKey _keyFor(GlassShape shape, ui.Size size) => _BakeKey(
        shape,
        size,
        // Texel density tracks the surface so big panels don't go soft;
        // clamped so tiny widgets still resolve and huge ones stay cheap.
        size.longestSide.clamp(64, 256).round(),
      );
}

@immutable
class _BakeKey {
  const _BakeKey(this.shape, this.size, this.resolution);

  final GlassShape shape;
  final ui.Size size;
  final int resolution;

  @override
  bool operator ==(Object other) =>
      other is _BakeKey &&
      other.shape == shape &&
      other.size == size &&
      other.resolution == resolution;

  @override
  int get hashCode => Object.hash(shape, size, resolution);
}
