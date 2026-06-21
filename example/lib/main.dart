import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter/material.dart';

import 'glass_nav_bar.dart';

void main() => runApp(const GlassGalleryApp());

class GlassGalleryApp extends StatelessWidget {
  const GlassGalleryApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GlassDemoPage(),
  );
}

class GlassDemoPage extends StatefulWidget {
  const GlassDemoPage({super.key});

  @override
  State<GlassDemoPage> createState() => _GlassDemoPageState();
}

class _GlassDemoPageState extends State<GlassDemoPage> {
  final _light = PointerLightSource();
  int _navIndex = 0;

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Colourful, high-frequency backdrop so refraction is obvious.
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF0080),
                  Color(0xFF7928CA),
                  Color(0xFF00D4FF),
                ],
              ),
            ),
            child: GridView.count(
              crossAxisCount: 6,
              children: List.generate(
                60,
                (i) => Icon(
                  Icons.star,
                  color: Colors.white.withValues(alpha: 0.18),
                  size: 40,
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 260,
              height: 160,
              child: MouseRegion(
                onHover: (e) =>
                    _light.update(e.localPosition, const Size(260, 160)),
                child: GlassContainer(
                  material: GlassMaterials.liquid,
                  shape: const GlassShape.roundedRect(32),
                  lightSource: _light,
                  child: const Center(
                    child: Text(
                      'Liquid Glass',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // A custom-shape demo: a glass nav bar with an oversized centred FAB
          // dropped into a hole the shape model punches mathematically.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: GlassNavBar(
                  currentIndex: _navIndex,
                  onTap: (i) => setState(() => _navIndex = i),
                  onAdd: () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
