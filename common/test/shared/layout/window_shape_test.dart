import 'package:common/src/shared/layout/window_shape.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group("windowShapeFor", () {
    // Transitional rule (until the breakpoint-flip stage): expanded keeps the
    // legacy tablet threshold (width > 1000) so layouts render identically
    // while screens migrate onto WindowShape. Medium starts at 600.
    test("classifies phone portrait as compact", () {
      expect(windowShapeFor(const Size(400, 800)), WindowShape.compact);
      expect(windowShapeFor(const Size(390, 844)), WindowShape.compact);
      expect(windowShapeFor(const Size(599, 800)), WindowShape.compact);
    });

    test("classifies medium widths as medium", () {
      expect(windowShapeFor(const Size(600, 800)), WindowShape.medium);
      expect(windowShapeFor(const Size(768, 1024)), WindowShape.medium);
      expect(windowShapeFor(const Size(834, 1194)), WindowShape.medium);
    });

    test("classifies landscape phone as medium, not expanded", () {
      // iPhone 16 Pro Max landscape: wide but too short for two panes.
      expect(windowShapeFor(const Size(932, 430)), WindowShape.medium);
    });

    test("keeps legacy >1000 threshold for expanded until the flip", () {
      expect(windowShapeFor(const Size(1000, 700)), WindowShape.medium);
      expect(windowShapeFor(const Size(1001, 700)), WindowShape.expanded);
      // iPad 2/3 Split View stays medium until the breakpoint flip.
      expect(windowShapeFor(const Size(980, 748)), WindowShape.medium);
    });

    test("classifies iPad landscape as expanded", () {
      expect(windowShapeFor(const Size(1024, 768)), WindowShape.expanded);
      expect(windowShapeFor(const Size(1366, 1024)), WindowShape.expanded);
      expect(windowShapeFor(const Size(1194, 834)), WindowShape.expanded);
    });
  });

  group("windowShapeOf", () {
    Future<void> pumpAt(WidgetTester tester, Size size, void Function(BuildContext) probe) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: Builder(builder: (context) {
            probe(context);
            return const SizedBox();
          }),
        ),
      );
    }

    testWidgets("matches windowShapeFor for the MediaQuery size", (tester) async {
      for (final size in const [Size(400, 800), Size(932, 430), Size(1024, 768)]) {
        late WindowShape shape;
        await pumpAt(tester, size, (context) => shape = windowShapeOf(context));
        expect(shape, windowShapeFor(size), reason: "size $size");
      }
    });
  });

  group("isTabletMode legacy delegate", () {
    // Pins the pre-existing behavior: strictly wider than 1000 counts as
    // tablet, regardless of height. Deleted with the delegate in cleanup.
    testWidgets("keeps the legacy strict >1000 width rule", (tester) async {
      Future<bool> tabletAt(Size size) async {
        late bool result;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: Builder(builder: (context) {
              result = isTabletMode(context);
              return const SizedBox();
            }),
          ),
        );
        return result;
      }

      expect(await tabletAt(const Size(1001, 700)), isTrue);
      expect(await tabletAt(const Size(1000, 700)), isFalse);
      expect(await tabletAt(const Size(400, 800)), isFalse);
    });
  });
}
