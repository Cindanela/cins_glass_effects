import 'package:flutter/widgets.dart';

/// The geometry of a glass surface. Phase 1 supports a uniform-radius
/// rounded rectangle; arbitrary `Path` shapes arrive in a later phase.
@immutable
class GlassShape {
  const GlassShape.roundedRect(this.cornerRadius);

  final double cornerRadius;

  Path clipPath(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cornerRadius)));

  @override
  bool operator ==(Object other) =>
      other is GlassShape && other.cornerRadius == cornerRadius;

  @override
  int get hashCode => cornerRadius.hashCode;
}

/// Clips a child to a [GlassShape].
class GlassClipper extends CustomClipper<Path> {
  const GlassClipper(this.shape);

  final GlassShape shape;

  @override
  Path getClip(Size size) => shape.clipPath(size);

  @override
  bool shouldReclip(GlassClipper oldClipper) => oldClipper.shape != shape;
}
