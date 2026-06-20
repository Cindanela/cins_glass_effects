import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../geometry/glass_shape.dart';
import '../light/glass_light.dart';
import '../materials/glass_material.dart';
import '../materials/glass_presets.dart';
import '../optics/glass_capabilities.dart';
import '../optics/glass_filter_builder.dart';
import '../optics/glass_render_path.dart';
import 'glass_fallback.dart';

/// Turns [child] into glass. Uses the shader path on Impeller and a blur+tint
/// fallback elsewhere.
class GlassContainer extends StatefulWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.material = GlassMaterials.liquid,
    this.shape = const GlassShape.roundedRect(28),
    this.lightSource,
    this.capabilities,
    this.flipY = false,
  });

  final Widget child;
  final GlassMaterial material;
  final GlassShape shape;
  final GlassLightSource? lightSource;
  final GlassCapabilities? capabilities;

  /// Set true if the backdrop renders vertically flipped (some Android-GLES).
  final bool flipY;

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  GlassFilterBuilder? _builder;
  late GlassLightSource _light;
  ManualLightSource? _ownedLight;

  @override
  void initState() {
    super.initState();
    _light = widget.lightSource ?? (_ownedLight = ManualLightSource());
    _maybeLoadShader();
  }

  GlassCapabilities get _caps => widget.capabilities ?? GlassCapabilities.detect();

  void _maybeLoadShader() {
    if (resolveGlassRenderPath(capabilities: _caps) == GlassRenderPath.shader) {
      GlassFilterBuilder.load().then((b) {
        if (mounted) setState(() => _builder = b);
      });
    }
  }

  @override
  void dispose() {
    _ownedLight?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clipper = GlassClipper(widget.shape);
    final usesShader =
        resolveGlassRenderPath(capabilities: _caps) == GlassRenderPath.shader && _builder != null;

    if (!usesShader) {
      return ClipPath(
        clipper: clipper,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: widget.material.blurSigma + 6,
            sigmaY: widget.material.blurSigma + 6,
          ),
          child: CustomPaint(
            foregroundPainter: GlassFallbackOverlay(
              material: widget.material,
              cornerRadius: widget.shape.cornerRadius,
            ),
            child: widget.child,
          ),
        ),
      );
    }

    return ValueListenableBuilder<GlassLight>(
      valueListenable: _light,
      builder: (context, light, _) {
        final filter = _builder!.build(
          material: widget.material,
          lightDir: light.direction,
          cornerRadius: widget.shape.cornerRadius,
          glesYFlip: widget.flipY,
        );
        return ClipPath(
          clipper: clipper,
          child: BackdropFilter(filter: filter, child: widget.child),
        );
      },
    );
  }
}
