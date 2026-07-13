import 'dart:ui';

import 'package:cins_glass_effects/cins_glass_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bakes a texture for the shape and reports readiness',
      (tester) async {
    final cache = SdfTextureCache();
    addTearDown(cache.dispose);
    var ready = 0;

    await tester.runAsync(() async {
      cache.ensure(const GlassShape.circle(), const Size(120, 60),
          onReady: () => ready++);
      await tester.binding.delayed(Duration.zero);
      while (ready == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });

    expect(ready, 1);
    final image = cache.textureFor(const GlassShape.circle(), const Size(120, 60));
    expect(image, isNotNull);
    expect(image!.width, greaterThan(0));
  });

  testWidgets('bakes at ~2 texels per logical pixel so curves stay smooth',
      (tester) async {
    final cache = SdfTextureCache();
    addTearDown(cache.dispose);
    var ready = 0;

    await tester.runAsync(() async {
      cache.ensure(const GlassShape.circle(), const Size(300, 150),
          onReady: () => ready++);
      while (ready == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });

    final image = cache.textureFor(const GlassShape.circle(), const Size(300, 150));
    // 300 logical px longest side × 2 = 600, capped at 512.
    expect(image!.width, 512);
    expect(image.height, 256);
  });

  testWidgets('a fresh bake is not re-run for the same shape and size',
      (tester) async {
    final cache = SdfTextureCache();
    addTearDown(cache.dispose);
    var ready = 0;

    await tester.runAsync(() async {
      cache.ensure(const GlassShape.circle(), const Size(80, 80),
          onReady: () => ready++);
      while (ready == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final first = cache.textureFor(const GlassShape.circle(), const Size(80, 80));
      // Same key again: no new bake, identical texture instance.
      cache.ensure(const GlassShape.circle(), const Size(80, 80),
          onReady: () => ready++);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(ready, 1);
      expect(
        identical(
            first, cache.textureFor(const GlassShape.circle(), const Size(80, 80))),
        isTrue,
      );
    });
  });

  testWidgets('a newer request supersedes an in-flight bake', (tester) async {
    final cache = SdfTextureCache();
    addTearDown(cache.dispose);
    var ready = 0;

    await tester.runAsync(() async {
      cache.ensure(const GlassShape.circle(), const Size(64, 64),
          onReady: () => ready++);
      cache.ensure(const GlassShape.roundedRect(12), const Size(64, 64),
          onReady: () => ready++);
      while (cache.textureFor(const GlassShape.roundedRect(12), const Size(64, 64)) ==
          null) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });

    // The superseded circle bake never became the cached texture.
    expect(cache.textureFor(const GlassShape.circle(), const Size(64, 64)), isNull);
    expect(
      cache.textureFor(const GlassShape.roundedRect(12), const Size(64, 64)),
      isNotNull,
    );
  });

  testWidgets('stale texture stays available while a rebake runs',
      (tester) async {
    final cache = SdfTextureCache();
    addTearDown(cache.dispose);
    var ready = 0;

    await tester.runAsync(() async {
      cache.ensure(const GlassShape.circle(), const Size(64, 64),
          onReady: () => ready++);
      while (ready == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      // Resize: exact texture is gone, but the previous one is still offered
      // so the widget never flashes back to the fallback.
      cache.ensure(const GlassShape.circle(), const Size(200, 100),
          onReady: () => ready++);
      expect(cache.textureFor(const GlassShape.circle(), const Size(200, 100)),
          isNull);
      expect(cache.latestTexture, isNotNull);
    });
  });
}
