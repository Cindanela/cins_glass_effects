import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import 'showcase/animation_page.dart';
import 'showcase/backdrops.dart';
import 'showcase/controls.dart';
import 'showcase/nav_bar_page.dart';
import 'showcase/specimen.dart';
import 'showcase/specimen_page.dart';
import 'showcase/theme.dart';

void main() => runApp(const GlassGalleryApp());

class GlassGalleryApp extends StatelessWidget {
  const GlassGalleryApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ShowcasePage(),
  );
}

/// The gallery: a page per specimen over a switchable backdrop, with shared
/// chrome (header, page dots, material controls). Owns ALL showcase state —
/// every child is stateless (values in, callbacks out).
class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key});

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  final PageController _pages = PageController();
  final PointerLightSource _light = PointerLightSource();

  int _pageIndex = 0;
  ShowcaseBackdrop _backdrop = ShowcaseBackdrop.gradient;
  int _presetIndex = 0;
  GlassMaterial _material = showcasePresets.first.material;
  bool _drawerExpanded = false;
  bool _navBarUnion = false;
  int _animPresetIndex = 0;
  bool _driftEnabled = false;
  bool _driftRight = false;

  int get _pageCount => specimens.length + 2;
  int get _navBarPage => specimens.length;

  @override
  void dispose() {
    _pages.dispose();
    _light.dispose();
    super.dispose();
  }

  String get _title {
    if (_pageIndex < specimens.length) return specimens[_pageIndex].title;
    return _pageIndex == _navBarPage ? 'Nav bar + FAB' : 'Animation';
  }

  String get _checkNote {
    if (_pageIndex < specimens.length) return specimens[_pageIndex].checkNote;
    return _pageIndex == _navBarPage
        ? 'Separate reproduces the doubled rim + seam; Union is the one-slab candidate fix.'
        : 'Tap tweens the material. Drift: grain must travel with the glass, not swim.';
  }

  Widget _page(int index) {
    if (index < specimens.length) {
      return SpecimenPage(
        specimen: specimens[index],
        material: _material,
        pointerLight: _light,
      );
    }
    if (index == _navBarPage) {
      return NavBarPage(
        union: _navBarUnion,
        onUnionChanged: (v) => setState(() => _navBarUnion = v),
      );
    }
    return AnimationPage(
      presetIndex: _animPresetIndex,
      driftEnabled: _driftEnabled,
      driftRight: _driftRight,
      onTapGlass: () => setState(
        () =>
            _animPresetIndex = (_animPresetIndex + 1) % showcasePresets.length,
      ),
      onDriftToggled: (v) => setState(() {
        _driftEnabled = v;
        _driftRight = v;
      }),
      onDriftLegComplete: () {
        if (_driftEnabled) setState(() => _driftRight = !_driftRight);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropView(backdrop: _backdrop),
          PageView.builder(
            controller: _pages,
            itemCount: _pageCount,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (_, i) => _page(i),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  title: _title,
                  note: _checkNote,
                  backdrop: _backdrop,
                  onBackdropCycled: () =>
                      setState(() => _backdrop = _backdrop.next),
                ),
                _PageDots(count: _pageCount, index: _pageIndex),
                const Spacer(),
                ControlsDrawer(
                  material: _material,
                  presetIndex: _presetIndex,
                  expanded: _drawerExpanded,
                  onPresetSelected: (i) => setState(() {
                    _presetIndex = i;
                    _material = showcasePresets[i].material;
                  }),
                  onMaterialChanged: (m) => setState(() => _material = m),
                  onToggleExpanded: () =>
                      setState(() => _drawerExpanded = !_drawerExpanded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.note,
    required this.backdrop,
    required this.onBackdropCycled,
  });

  final String title;
  final String note;
  final ShowcaseBackdrop backdrop;
  final VoidCallback onBackdropCycled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        ShowcaseTheme.pad,
        ShowcaseTheme.pad,
        ShowcaseTheme.pad,
        0,
      ),
      padding: const EdgeInsets.all(ShowcaseTheme.gap),
      decoration: BoxDecoration(
        color: ShowcaseTheme.chromeBg,
        borderRadius: BorderRadius.circular(ShowcaseTheme.controlRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ShowcaseTheme.headerTitle),
                Text(note, style: ShowcaseTheme.controlLabel),
              ],
            ),
          ),
          IconButton(
            icon: Icon(backdrop.icon),
            color: ShowcaseTheme.chromeFg,
            tooltip: 'Backdrop: ${backdrop.label}',
            onPressed: onBackdropCycled,
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: ShowcaseTheme.gap),
      padding: const EdgeInsets.symmetric(
        horizontal: ShowcaseTheme.gap,
        vertical: ShowcaseTheme.dotGap,
      ),
      decoration: BoxDecoration(
        color: ShowcaseTheme.chromeBg,
        borderRadius: BorderRadius.circular(ShowcaseTheme.dotSize),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: ShowcaseTheme.materialTween,
              margin: const EdgeInsets.symmetric(
                horizontal: ShowcaseTheme.dotGap,
              ),
              width: i == index
                  ? ShowcaseTheme.dotActiveWidth
                  : ShowcaseTheme.dotSize,
              height: ShowcaseTheme.dotSize,
              decoration: BoxDecoration(
                color: i == index
                    ? ShowcaseTheme.dotActive
                    : ShowcaseTheme.dotInactive,
                borderRadius: BorderRadius.circular(ShowcaseTheme.dotSize / 2),
              ),
            ),
        ],
      ),
    );
  }
}
