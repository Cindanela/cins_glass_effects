import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../geometry/glass_shape.dart';
import '../light/glass_light.dart';
import '../materials/glass_material.dart';
import '../materials/glass_presets.dart';
import '../optics/glass_capabilities.dart';
import '../optics/glass_filter_builder.dart';
import '../optics/glass_render_path.dart';
import '../optics/sdf_texture_cache.dart';
import 'glass_backdrop.dart';
import 'glass_fallback.dart';

/// Turns [child] into glass. On Impeller every shape gets full shader optics:
/// rounded rects render analytically, any other silhouette with an SDF is
/// baked into a distance-field texture for the baked-SDF shader. Elsewhere
/// (and for [GlassShape.path] without an `sdfFn`) a blur+tint fallback keeps
/// the exact silhouette.
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
  GlassSdfFilterBuilder? _sdfBuilder;
  bool _loadingBuilder = false;
  bool _loadingSdfBuilder = false;
  final SdfTextureCache _sdfCache = SdfTextureCache();
  bool _bakeScheduled = false;
  late GlassLightSource _light;
  ManualLightSource? _ownedLight;
  late final GlassCapabilities _caps;

  @override
  void initState() {
    super.initState();
    _light = widget.lightSource ?? (_ownedLight = ManualLightSource());
    // Capabilities are fixed per engine run — detect once, not per build.
    _caps = widget.capabilities ?? GlassCapabilities.detect();
    _maybeLoadShaders();
  }

  @override
  void didUpdateWidget(GlassContainer old) {
    super.didUpdateWidget(old);
    if (old.lightSource != widget.lightSource) {
      _ownedLight?.dispose();
      _ownedLight = null;
      _light = widget.lightSource ?? (_ownedLight = ManualLightSource());
    }
    if (old.shape != widget.shape) {
      _maybeLoadShaders(); // the new shape may need the other shader variant
    }
  }

  bool get _onShaderPath =>
      resolveGlassRenderPath(capabilities: _caps) == GlassRenderPath.shader;

  void _maybeLoadShaders() {
    if (!_onShaderPath) return;
    if (widget.shape.shaderRepresentable) {
      if (_builder == null && !_loadingBuilder) {
        _loadingBuilder = true;
        GlassFilterBuilder.load().then((b) {
          if (mounted) {
            setState(() => _builder = b);
          } else {
            b.dispose();
          }
        });
      }
    } else if (widget.shape.hasSdf) {
      if (_sdfBuilder == null && !_loadingSdfBuilder) {
        _loadingSdfBuilder = true;
        GlassSdfFilterBuilder.load().then((b) {
          if (mounted) {
            setState(() => _sdfBuilder = b);
          } else {
            b.dispose();
          }
        });
      }
    }
  }

  /// After this frame lays out, bake (or re-bake) the SDF texture at the
  /// widget's real size. Idempotent: the cache no-ops when already fresh.
  void _scheduleBake() {
    if (_bakeScheduled) return;
    _bakeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bakeScheduled = false;
      if (!mounted) return;
      final size = context.size;
      if (size == null || size.isEmpty) return;
      _sdfCache.ensure(widget.shape, size, onReady: () {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _builder?.dispose();
    _sdfBuilder?.dispose();
    _sdfCache.dispose();
    _ownedLight?.dispose();
    super.dispose();
  }

  ui.ImageFilter _withFrost(ui.ImageFilter optics) {
    // The optics shaders refract but don't blur; frost the backdrop first so
    // the shader samples an already-softened image.
    if (widget.material.blurSigma <= 0) return optics;
    return ui.ImageFilter.compose(
      outer: optics,
      inner: ui.ImageFilter.blur(
        sigmaX: widget.material.blurSigma,
        sigmaY: widget.material.blurSigma,
      ),
    );
  }

  Widget _glass(
    GlassClipper clipper,
    ui.ImageFilter Function(GlassLight light, ui.Rect deviceRect) filter,
  ) {
    return ValueListenableBuilder<GlassLight>(
      valueListenable: _light,
      builder: (context, light, _) => ClipPath(
        clipper: clipper,
        // GlassBackdrop rebuilds the filter at paint time with the widget's
        // on-screen rect — the backdrop texture is the whole screen, so the
        // shader must be told where the glass is.
        child: GlassBackdrop(
          filterFactory: (deviceRect) => _withFrost(filter(light, deviceRect)),
          child: widget.child,
        ),
      ),
    );
  }

  Widget _fallback(GlassClipper clipper) {
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

  @override
  Widget build(BuildContext context) {
    final clipper = GlassClipper(widget.shape);

    // Route 1 — analytic shader: the rounded rect the shader represents exactly.
    if (_onShaderPath && widget.shape.shaderRepresentable) {
      if (_builder == null) return _fallback(clipper); // still loading
      return _glass(
        clipper,
        (light, deviceRect) => _builder!.build(
          material: widget.material,
          light: light,
          cornerRadius: widget.shape.shaderCornerRadius,
          deviceRect: deviceRect,
        ),
      );
    }

    // Route 2 — baked-SDF shader: any other silhouette with distance maths.
    if (_onShaderPath && widget.shape.hasSdf) {
      // LayoutBuilder so constraint changes re-run this and re-measure.
      return LayoutBuilder(builder: (context, _) {
        _scheduleBake();
        final texture = _sdfCache.latestTexture; // stale > flashing fallback
        if (_sdfBuilder == null || texture == null) return _fallback(clipper);
        final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ??
            View.of(context).devicePixelRatio;
        return _glass(
          clipper,
          (light, deviceRect) => _sdfBuilder!.build(
            material: widget.material,
            light: light,
            sdfTexture: texture,
            sdfRangePx: _sdfCache.sdfRangePx(dpr),
            deviceRect: deviceRect,
          ),
        );
      });
    }

    // Route 3 — fallback: no shader support, or a path shape without an SDF.
    return _fallback(clipper);
  }
}
