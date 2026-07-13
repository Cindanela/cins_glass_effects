import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [BackdropFilter] whose filter is (re)built at paint time with the
/// widget's rect in device pixels.
///
/// Needed because a backdrop filter's input texture is the **whole render
/// pass** (the screen), not the widget bounds — so the glass shaders must be
/// told where the widget actually sits within it. Only paint time knows that
/// position; building the filter earlier would bake in stale geometry.
///
/// The rect assumes the backdrop pass starts at the screen origin and that no
/// ancestor rotates or scales the glass — true for typical UI (bars, panels,
/// dialogs). Glass nested inside ancestor save layers may see an offset.
class GlassBackdrop extends SingleChildRenderObjectWidget {
  const GlassBackdrop({
    super.key,
    required this.filterFactory,
    required super.child,
  });

  /// Builds the backdrop filter for the widget's current [deviceRect]
  /// (position and size on screen, in device pixels).
  final ui.ImageFilter Function(ui.Rect deviceRect) filterFactory;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderGlassBackdrop(
        filterFactory: filterFactory,
        devicePixelRatio: View.of(context).devicePixelRatio,
      );

  @override
  void updateRenderObject(BuildContext context, RenderGlassBackdrop renderObject) {
    renderObject
      ..filterFactory = filterFactory
      ..devicePixelRatio = View.of(context).devicePixelRatio;
  }
}

class RenderGlassBackdrop extends RenderProxyBox {
  RenderGlassBackdrop({
    required this._filterFactory,
    required this._devicePixelRatio,
  });

  ui.ImageFilter Function(ui.Rect) _filterFactory;
  set filterFactory(ui.ImageFilter Function(ui.Rect) value) {
    if (identical(value, _filterFactory)) return;
    _filterFactory = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    // Where this box sits on screen, in device pixels. localToGlobal handles
    // any ancestor translations (scrolling, padding, stacks).
    final origin = localToGlobal(Offset.zero) * _devicePixelRatio;
    final deviceRect = origin &
        Size(size.width * _devicePixelRatio, size.height * _devicePixelRatio);

    final backdropLayer = (layer is BackdropFilterLayer
            ? layer as BackdropFilterLayer
            : BackdropFilterLayer())
        ..filter = _filterFactory(deviceRect);
    layer = backdropLayer;
    context.pushLayer(backdropLayer, super.paint, offset);
  }
}
