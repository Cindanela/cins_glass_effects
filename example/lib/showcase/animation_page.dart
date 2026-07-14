import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import 'controls.dart';
import 'theme.dart';

/// Animation checks: tap the glass to tween between material presets; enable
/// Drift to slide the panel side to side — grain must travel with the widget
/// (it is anchored in widget-local coords), never swim against it.
class AnimationPage extends StatelessWidget {
  const AnimationPage({
    super.key,
    required this.presetIndex,
    required this.driftEnabled,
    required this.driftRight,
    required this.onTapGlass,
    required this.onDriftToggled,
    required this.onDriftLegComplete,
  });

  final int presetIndex;
  final bool driftEnabled;
  final bool driftRight;
  final VoidCallback onTapGlass;
  final ValueChanged<bool> onDriftToggled;

  /// Called when one left↔right leg finishes; the owner flips [driftRight]
  /// while [driftEnabled] to ping-pong.
  final VoidCallback onDriftLegComplete;

  @override
  Widget build(BuildContext context) {
    final preset = showcasePresets[presetIndex];
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(ShowcaseTheme.pad),
              child: AnimatedAlign(
                alignment: !driftEnabled
                    ? Alignment.center
                    : (driftRight
                          ? Alignment.centerRight
                          : Alignment.centerLeft),
                duration: ShowcaseTheme.driftPeriod,
                onEnd: onDriftLegComplete,
                child: GestureDetector(
                  onTap: onTapGlass,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: ShowcaseTheme.animGlassSide,
                    height: ShowcaseTheme.animGlassSide,
                    child: AnimatedGlassContainer(
                      duration: ShowcaseTheme.materialTween,
                      material: preset.material,
                      shape: const GlassShape.roundedRect(32),
                      child: Center(
                        child: Text(
                          '${preset.label}\ntap to tween',
                          textAlign: TextAlign.center,
                          style: ShowcaseTheme.headerTitle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              bottom: ShowcaseTheme.pageBottomInset,
            ),
            child: FilterChip(
              label: const Text('Drift'),
              selected: driftEnabled,
              onSelected: onDriftToggled,
            ),
          ),
        ],
      ),
    );
  }
}
