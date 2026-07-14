import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/widgets.dart';

import 'specimen.dart';
import 'theme.dart';

/// One specimen, centred and big, over whatever backdrop the chrome chose.
/// Dragging a finger (or hovering a mouse) over the glass moves the light.
class SpecimenPage extends StatelessWidget {
  const SpecimenPage({
    super.key,
    required this.specimen,
    required this.material,
    this.pointerLight,
  });

  final Specimen specimen;
  final GlassMaterial material;
  final PointerLightSource? pointerLight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            constraints.biggest.shortestSide * ShowcaseTheme.specimenFraction;
        final size = Size(side, side);
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: Listener(
              onPointerHover: (e) => pointerLight?.update(e.localPosition, size),
              onPointerMove: (e) => pointerLight?.update(e.localPosition, size),
              child: GlassContainer(
                material: material,
                shape: specimen.shape(size),
                lightSource: pointerLight,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}
