import 'package:flutter/widgets.dart';

import '../materials/glass_material.dart';

/// Paints a believable glass surface when custom shaders aren't available
/// (e.g. web): a tint wash plus a Fresnel-style rim highlight. Pairs with a
/// `BackdropFilter(ImageFilter.blur)` behind it.
class GlassFallbackOverlay extends CustomPainter {
  GlassFallbackOverlay({required this.material, required this.cornerRadius});

  final GlassMaterial material;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cornerRadius));
    canvas.drawRRect(rrect, Paint()..color = material.tint);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * material.fresnel);
    canvas.drawRRect(rrect.deflate(0.75), rim);
  }

  @override
  bool shouldRepaint(GlassFallbackOverlay old) =>
      old.material != material || old.cornerRadius != cornerRadius;
}
