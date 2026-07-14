import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

typedef ShowcasePreset = ({String label, GlassMaterial material});

const List<ShowcasePreset> showcasePresets = [
  (label: 'Liquid', material: GlassMaterials.liquid),
  (label: 'Frosted', material: GlassMaterials.frosted),
  (label: 'Clear', material: GlassMaterials.clear),
];

/// Material chips + collapsible slider drawer. Stateless: current values come
/// in, changes go out through callbacks. Values are shown numerically so good
/// numbers can be read back off the device for preset re-tuning.
class ControlsDrawer extends StatelessWidget {
  const ControlsDrawer({
    super.key,
    required this.material,
    required this.presetIndex,
    required this.expanded,
    required this.onPresetSelected,
    required this.onMaterialChanged,
    required this.onToggleExpanded,
  });

  final GlassMaterial material;
  final int presetIndex;
  final bool expanded;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<GlassMaterial> onMaterialChanged;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        ShowcaseTheme.pad, 0, ShowcaseTheme.pad, ShowcaseTheme.pad),
      padding: const EdgeInsets.all(ShowcaseTheme.gap),
      decoration: BoxDecoration(
        color: ShowcaseTheme.chromeBg,
        borderRadius: BorderRadius.circular(ShowcaseTheme.controlRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: ShowcaseTheme.gap / 2,
                  children: [
                    for (var i = 0; i < showcasePresets.length; i++)
                      ChoiceChip(
                        label: Text(showcasePresets[i].label),
                        selected: i == presetIndex,
                        onSelected: (_) => onPresetSelected(i),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(expanded ? Icons.expand_more : Icons.tune),
                color: ShowcaseTheme.chromeFg,
                tooltip: 'Optics sliders',
                onPressed: onToggleExpanded,
              ),
            ],
          ),
          if (expanded) ...[
            _slider('edge width', material.edgeWidth, 40,
                (v) => onMaterialChanged(material.copyWith(edgeWidth: v))),
            _slider('refraction', material.refraction, 30,
                (v) => onMaterialChanged(material.copyWith(refraction: v))),
            _slider('aberration', material.chromaticAberration, 8,
                (v) => onMaterialChanged(
                    material.copyWith(chromaticAberration: v))),
            _slider('blur', material.blurSigma, 20,
                (v) => onMaterialChanged(material.copyWith(blurSigma: v))),
            _slider('grain', material.grain, 1,
                (v) => onMaterialChanged(material.copyWith(grain: v))),
            _slider('tint alpha', material.tint.a, 0.4,
                (v) => onMaterialChanged(material.copyWith(
                    tint: material.tint.withValues(alpha: v)))),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    onMaterialChanged(showcasePresets[presetIndex].material),
                child: const Text('Reset'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slider(
      String label, double value, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: ShowcaseTheme.sliderLabelWidth,
          child: Text(label, style: ShowcaseTheme.controlLabel),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, max).toDouble(),
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: ShowcaseTheme.sliderValueWidth,
          child: Text(
            value.toStringAsFixed(1),
            style: ShowcaseTheme.controlLabel,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
