import 'package:common/src/shared/layout/window_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("windowShapeFor", () {
    // Expanded = width >= 840 (Material 3 expanded class) AND height >= 500
    // (guard so landscape phones and squat windows stay out of two-pane
    // layouts). Medium starts at 600.
    test("classifies phone portrait as compact", () {
      expect(windowShapeFor(const Size(400, 800)), WindowShape.compact);
      expect(windowShapeFor(const Size(390, 844)), WindowShape.compact);
      expect(windowShapeFor(const Size(599, 800)), WindowShape.compact);
    });

    test("classifies medium widths as medium", () {
      expect(windowShapeFor(const Size(600, 800)), WindowShape.medium);
      expect(windowShapeFor(const Size(768, 1024)), WindowShape.medium);
      expect(windowShapeFor(const Size(834, 1194)), WindowShape.medium);
      expect(windowShapeFor(const Size(839, 800)), WindowShape.medium);
    });

    test("keeps landscape phones out of expanded via the height guard", () {
      // iPhone 16 Pro Max landscape: wide but too short for two panes.
      expect(windowShapeFor(const Size(932, 430)), WindowShape.medium);
      expect(windowShapeFor(const Size(1200, 499)), WindowShape.medium);
    });

    test("classifies wide-and-tall-enough windows as expanded", () {
      expect(windowShapeFor(const Size(840, 500)), WindowShape.expanded);
      // iPad 2/3 Split View — wasted as single-pane before the flip.
      expect(windowShapeFor(const Size(980, 748)), WindowShape.expanded);
      expect(windowShapeFor(const Size(1024, 768)), WindowShape.expanded);
      expect(windowShapeFor(const Size(1194, 834)), WindowShape.expanded);
      expect(windowShapeFor(const Size(1366, 1024)), WindowShape.expanded);
      // Short but wide macOS window still fits two panes.
      expect(windowShapeFor(const Size(1200, 500)), WindowShape.expanded);
    });
  });

  group("windowShapeOf", () {
    testWidgets("matches windowShapeFor for the MediaQuery size", (tester) async {
      for (final size in const [Size(400, 800), Size(932, 430), Size(1024, 768)]) {
        late WindowShape shape;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(builder: (context) {
              shape = windowShapeOf(context);
              return const SizedBox();
            }),
          ),
        );
        expect(shape, windowShapeFor(size), reason: "size $size");
      }
    });
  });
}
