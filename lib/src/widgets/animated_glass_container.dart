import 'package:flutter/widgets.dart';

import '../geometry/glass_shape.dart';
import '../light/glass_light.dart';
import '../materials/glass_material.dart';
import '../materials/glass_presets.dart';
import '../optics/glass_capabilities.dart';
import 'glass_container.dart';

/// A [Tween] over [GlassMaterial], interpolating every optical parameter.
class GlassMaterialTween extends Tween<GlassMaterial> {
  GlassMaterialTween({super.begin, super.end});

  @override
  GlassMaterial lerp(double t) => GlassMaterial.lerp(begin!, end!, t);
}

/// A [GlassContainer] that animates smoothly to a new [material] — e.g.
/// `clear` at rest, `liquid` on focus. The shape is not tweened; it applies
/// immediately.
class AnimatedGlassContainer extends ImplicitlyAnimatedWidget {
  const AnimatedGlassContainer({
    super.key,
    required this.child,
    this.material = GlassMaterials.liquid,
    this.shape = const GlassShape.roundedRect(28),
    this.lightSource,
    this.capabilities,
    required super.duration,
    super.curve,
    super.onEnd,
  });

  final Widget child;
  final GlassMaterial material;
  final GlassShape shape;
  final GlassLightSource? lightSource;
  final GlassCapabilities? capabilities;

  @override
  AnimatedWidgetBaseState<AnimatedGlassContainer> createState() =>
      _AnimatedGlassContainerState();
}

class _AnimatedGlassContainerState
    extends AnimatedWidgetBaseState<AnimatedGlassContainer> {
  GlassMaterialTween? _material;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _material = visitor(
      _material,
      widget.material,
      (value) => GlassMaterialTween(begin: value as GlassMaterial),
    ) as GlassMaterialTween?;
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      material: _material?.evaluate(animation) ?? widget.material,
      shape: widget.shape,
      lightSource: widget.lightSource,
      capabilities: widget.capabilities,
      child: widget.child,
    );
  }
}
