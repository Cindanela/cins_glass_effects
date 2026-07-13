import 'dart:ui' as ui;

import 'package:cins_glass_effects/src/widgets/glass_backdrop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filter factory receives the widget rect in device pixels',
      (tester) async {
    final rects = <ui.Rect>[];
    ui.ImageFilter record(ui.Rect deviceRect) {
      rects.add(deviceRect);
      return ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1); // any valid filter
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              left: 30,
              top: 50,
              width: 120,
              height: 80,
              child: GlassBackdrop(
                filterFactory: record,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );

    final dpr = tester.view.devicePixelRatio;
    expect(rects, isNotEmpty);
    expect(
      rects.last,
      ui.Rect.fromLTWH(30 * dpr, 50 * dpr, 120 * dpr, 80 * dpr),
    );
  });

  testWidgets('repaint after a position change reports the new rect',
      (tester) async {
    final rects = <ui.Rect>[];
    ui.ImageFilter record(ui.Rect deviceRect) {
      rects.add(deviceRect);
      return ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
    }

    Widget at(double left) => Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: 0,
                width: 100,
                height: 40,
                child: GlassBackdrop(
                  filterFactory: record,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        );

    await tester.pumpWidget(at(0));
    await tester.pumpWidget(at(60));

    final dpr = tester.view.devicePixelRatio;
    expect(rects.last, ui.Rect.fromLTWH(60 * dpr, 0, 100 * dpr, 40 * dpr));
  });
}
