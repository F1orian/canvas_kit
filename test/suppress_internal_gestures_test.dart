import 'package:canvas_kit/canvas_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract for the `suppressInternalGestures` flag.
///
/// canvas_kit can either own pan/zoom itself (interactive mode) or hand input
/// to the embedding app. Before this flag, the only way to suppress the
/// library's own [GestureDetector] was to pass a non-null [gestureOverlayBuilder]
/// in programmatic mode — an implicit coupling that forced callers who wanted
/// to own input from a *sibling* layer (stacked above CanvasKit) to pass an
/// empty `(_, _) => SizedBox.shrink()` builder purely to flip the switch.
///
/// `suppressInternalGestures: true` makes that intent explicit: the library
/// builds no internal pan/pinch [GestureDetector] and ignores pointer-signal
/// (wheel) zoom, regardless of [interactionMode] or [gestureOverlayBuilder].
void main() {
  Future<void> pumpCanvas(
    WidgetTester tester, {
    required CanvasKitController controller,
    required bool suppress,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: CanvasKit(
              controller: controller,
              suppressInternalGestures: suppress,
              children: const [],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'control: default CanvasKit pans on drag (proves the harness drives the gesture)',
    (tester) async {
      final controller = CanvasKitController();
      addTearDown(controller.dispose);

      await pumpCanvas(tester, controller: controller, suppress: false);
      final before = controller.transform.getTranslation().x;

      await tester.drag(find.byType(CanvasKit), const Offset(120, 0));
      await tester.pumpAndSettle();

      final after = controller.transform.getTranslation().x;
      expect(
        (after - before).abs(),
        greaterThan(1.0),
        reason: 'interactive CanvasKit must move the camera on drag, otherwise '
            'the suppression assertion below would be vacuous',
      );
    },
  );

  testWidgets(
    'suppressInternalGestures: true disables the library\'s own pan gesture',
    (tester) async {
      final controller = CanvasKitController();
      addTearDown(controller.dispose);

      await pumpCanvas(tester, controller: controller, suppress: true);
      final before = controller.transform.getTranslation().x;

      // The drag is *expected* to miss: with no internal GestureDetector there
      // is nothing in CanvasKit's subtree to claim the pointer. That is the
      // point of the flag, so the "hit test missed" warning is not a failure.
      await tester.drag(
        find.byType(CanvasKit),
        const Offset(120, 0),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final after = controller.transform.getTranslation().x;
      expect(
        (after - before).abs(),
        lessThan(0.001),
        reason: 'with internal gestures suppressed the library must not move '
            'the camera — the embedding app owns all input',
      );
    },
  );
}
