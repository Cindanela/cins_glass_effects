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
  });

  final Widget child;
  final GlassMaterial material;
  final GlassShape shape;
  final GlassLightSource? lightSource;
  final GlassCapabilities? capabilities;

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

/// Extra blur applied on the fallback path only. Without the shader there is no
/// refraction/specular to sell the material, so the fallback leans harder on
/// blur to read as glass at the same [GlassMaterial.blurSigma].
const double _fallbackBlurBoost = 6.0;

class _GlassContainerState extends State<GlassContainer> {
  GlassFilterBuilder? _builder;
  late GlassLightSource _light;
  ManualLightSource? _ownedLight;
  late final GlassCapabilities _caps;

  @override
  void initState() {
    super.initState();
    _light = widget.lightSource ?? (_ownedLight = ManualLightSource());
    // Capabilities are fixed per engine run — detect once, not per build.
    _caps = widget.capabilities ?? GlassCapabilities.detect();
    _maybeLoadShader();
  }

  void _maybeLoadShader() {
    if (resolveGlassRenderPath(capabilities: _caps) == GlassRenderPath.shader) {
      GlassFilterBuilder.load().then((b) {
        if (mounted) {
          setState(() => _builder = b);
        } else {
          b.dispose();
        }
      });
    }
  }

  @override
  void dispose() {
    _builder?.dispose();
    _ownedLight?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clipper = GlassClipper(widget.shape);
    // The analytic shader only renders shapes it can represent exactly; any
    // other silhouette routes to the shape-accurate fallback rather than
    // drawing a wrong outline.
    final usesShader =
        resolveGlassRenderPath(capabilities: _caps) == GlassRenderPath.shader &&
            _builder != null &&
            widget.shape.shaderRepresentable;

    if (!usesShader) {
      return ClipPath(
        clipper: clipper,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: widget.material.blurSigma + _fallbackBlurBoost,
            sigmaY: widget.material.blurSigma + _fallbackBlurBoost,
          ),
          child: CustomPaint(
            foregroundPainter: GlassFallbackOverlay(
              material: widget.material,
              shape: widget.shape,
            ),
            child: widget.child,
          ),
        ),
      );
    }

    return ValueListenableBuilder<GlassLight>(
      valueListenable: _light,
      builder: (context, light, _) {
        var filter = _builder!.build(
          material: widget.material,
          light: light,
          cornerRadius: widget.shape.shaderCornerRadius,
        );
        // The optics shader refracts but doesn't blur; frost the backdrop
        // first so the shader samples an already-softened image.
        if (widget.material.blurSigma > 0) {
          filter = ui.ImageFilter.compose(
            outer: filter,
            inner: ui.ImageFilter.blur(
              sigmaX: widget.material.blurSigma,
              sigmaY: widget.material.blurSigma,
            ),
          );
        }
        return ClipPath(
          clipper: clipper,
          child: BackdropFilter(filter: filter, child: widget.child),
        );
      },
    );
  }
}
