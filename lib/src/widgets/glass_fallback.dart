import 'package:flutter/widgets.dart';

import '../geometry/glass_shape.dart';
import '../materials/glass_material.dart';

/// Paints a believable glass surface when custom shaders aren't available
/// (e.g. web): a tint wash plus a Fresnel-style rim highlight. Pairs with a
/// `BackdropFilter(ImageFilter.blur)` behind it.
///
/// Both the wash and the rim are drawn from [shape]'s exact [GlassShape.clipPath]
/// silhouette, so they follow *any* outline — including the inner rim of a
/// punched hole — rather than a hardcoded rounded rectangle.
class GlassFallbackOverlay extends CustomPainter {
  GlassFallbackOverlay({required this.material, required this.shape});

  final GlassMaterial material;
  final GlassShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape.clipPath(size);
    canvas.drawPath(path, Paint()..color = material.tint);

    // Stroke the real silhouette for the edge highlight. The surrounding
    // ClipPath keeps the inner half of the stroke, leaving a hairline rim that
    // traces every edge the shape has.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * material.fresnel);
    canvas.drawPath(path, rim);
  }

  @override
  bool shouldRepaint(GlassFallbackOverlay old) =>
      old.material != material || old.shape != shape;
}
