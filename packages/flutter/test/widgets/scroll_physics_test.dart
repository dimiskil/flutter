// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestScrollPhysics extends ScrollPhysics {
  const TestScrollPhysics({
    required this.name,
    ScrollPhysics? parent,
  }) : super(parent: parent);
  final String name;

  @override
  TestScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return TestScrollPhysics(
      name: name,
      parent: parent?.applyTo(ancestor) ?? ancestor!,
    );
  }

  TestScrollPhysics get namedParent => parent! as TestScrollPhysics;
  String get names => parent == null ? name : '$name ${namedParent.names}';

  @override
  String toString() {
    if (parent == null)
      return '${objectRuntimeType(this, 'TestScrollPhysics')}($name)';
    return '${objectRuntimeType(this, 'TestScrollPhysics')}($name) -> $parent';
  }
}


void main() {
  test('ScrollPhysics applyTo()', () {
    const TestScrollPhysics a = TestScrollPhysics(name: 'a');
    const TestScrollPhysics b = TestScrollPhysics(name: 'b');
    const TestScrollPhysics c = TestScrollPhysics(name: 'c');
    const TestScrollPhysics d = TestScrollPhysics(name: 'd');
    const TestScrollPhysics e = TestScrollPhysics(name: 'e');

    expect(a.parent, null);
    expect(b.parent, null);
    expect(c.parent, null);

    final TestScrollPhysics ab = a.applyTo(b);
    expect(ab.names, 'a b');

    final TestScrollPhysics abc = ab.applyTo(c);
    expect(abc.names, 'a b c');

    final TestScrollPhysics de = d.applyTo(e);
    expect(de.names, 'd e');

    final TestScrollPhysics abcde = abc.applyTo(de);
    expect(abcde.names, 'a b c d e');
  });

  test('ScrollPhysics subclasses applyTo()', () {
    const ScrollPhysics bounce = BouncingScrollPhysics();
    const ScrollPhysics clamp = ClampingScrollPhysics();
    const ScrollPhysics never = NeverScrollableScrollPhysics();
    const ScrollPhysics always = AlwaysScrollableScrollPhysics();
    const ScrollPhysics page = PageScrollPhysics();

    String types(ScrollPhysics? value) => value!.parent == null ? '${value.runtimeType}' : '${value.runtimeType} ${types(value.parent)}';

    expect(
      types(bounce.applyTo(clamp.applyTo(never.applyTo(always.applyTo(page))))),
      'BouncingScrollPhysics ClampingScrollPhysics NeverScrollableScrollPhysics AlwaysScrollableScrollPhysics PageScrollPhysics',
    );

    expect(
      types(clamp.applyTo(never.applyTo(always.applyTo(page.applyTo(bounce))))),
      'ClampingScrollPhysics NeverScrollableScrollPhysics AlwaysScrollableScrollPhysics PageScrollPhysics BouncingScrollPhysics',
    );

    expect(
      types(never.applyTo(always.applyTo(page.applyTo(bounce.applyTo(clamp))))),
      'NeverScrollableScrollPhysics AlwaysScrollableScrollPhysics PageScrollPhysics BouncingScrollPhysics ClampingScrollPhysics',
    );

    expect(
      types(always.applyTo(page.applyTo(bounce.applyTo(clamp.applyTo(never))))),
      'AlwaysScrollableScrollPhysics PageScrollPhysics BouncingScrollPhysics ClampingScrollPhysics NeverScrollableScrollPhysics',
    );

    expect(
      types(page.applyTo(bounce.applyTo(clamp.applyTo(never.applyTo(always))))),
      'PageScrollPhysics BouncingScrollPhysics ClampingScrollPhysics NeverScrollableScrollPhysics AlwaysScrollableScrollPhysics',
    );
  });

  test('ScrollPhysics scrolling subclasses - initial velocity when creating the simulation', () {
    final ScrollMetrics position = FixedScrollMetrics(
      minScrollExtent: 0.0,
      maxScrollExtent: 100.0,
      pixels: 20.0,
      viewportDimension: 500.0,
      axisDirection: AxisDirection.down,
    );

    const BouncingScrollPhysics bounce = BouncingScrollPhysics();
    const ClampingScrollPhysics clamp = ClampingScrollPhysics();

    // Verify creating these simulations doesn't alter the velocity for time 0.
    //
    // Calls to createBallisticSimulation may happen on every frame (i.e. when the maxScrollExtent changes)
    // Changing velocity for time 0 may cause a sudden, unwanted damping/speedup effect.
    expect(bounce.createBallisticSimulation(position, 1000)!.dx(0), 1000);
    expect(clamp.createBallisticSimulation(position, 1000)!.dx(0), 1000);

    // Contrary to the other two scroll physics, PageScrollPhysics do intentionally produce
    // a bigger velocity than supplied to them, but they won't suffer from this, because the simulation
    // velocity depends on a ratio of velocity / pageDelta, and because they are not affected by
    // https://github.com/flutter/flutter/issues/11599

    // TODO(nt4f04uNd): remove this test, because it is artificial, in favor of a real one.
    // Scroll simulations surely should be allowed to modify the speed they receive in whatever way they want.
    // The proper fix for the original bug https://github.com/flutter/flutter/issues/24715
    // would be to ensure this is not called too often https://github.com/flutter/flutter/issues/11599
    // Proper test(s) should ensure the animations of the physics have the same duration
    // for same fling conditions within different layouts.
  });

  group('BouncingScrollPhysics test', () {
    late BouncingScrollPhysics physicsUnderTest;

    setUp(() {
      physicsUnderTest = const BouncingScrollPhysics();
    });

    test('overscroll is progressively harder', () {
      final ScrollMetrics lessOverscrolledPosition = FixedScrollMetrics(
          minScrollExtent: 0.0,
          maxScrollExtent: 1000.0,
          pixels: -20.0,
          viewportDimension: 100.0,
          axisDirection: AxisDirection.down,
      );

      final ScrollMetrics moreOverscrolledPosition = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        pixels: -40.0,
        viewportDimension: 100.0,
        axisDirection: AxisDirection.down,
      );

      final double lessOverscrollApplied =
          physicsUnderTest.applyPhysicsToUserOffset(lessOverscrolledPosition, 10.0);

      final double moreOverscrollApplied =
          physicsUnderTest.applyPhysicsToUserOffset(moreOverscrolledPosition, 10.0);

      expect(lessOverscrollApplied, greaterThan(1.0));
      expect(lessOverscrollApplied, lessThan(20.0));

      expect(moreOverscrollApplied, greaterThan(1.0));
      expect(moreOverscrollApplied, lessThan(20.0));

      // Scrolling from a more overscrolled position meets more resistance.
      expect(
        lessOverscrollApplied.abs(),
        greaterThan(moreOverscrollApplied.abs()),
      );
    });

    test('easing an overscroll still has resistance', () {
      final ScrollMetrics overscrolledPosition = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        pixels: -20.0,
        viewportDimension: 100.0,
        axisDirection: AxisDirection.down,
      );

      final double easingApplied =
          physicsUnderTest.applyPhysicsToUserOffset(overscrolledPosition, -10.0);

      expect(easingApplied, lessThan(-1.0));
      expect(easingApplied, greaterThan(-10.0));
    });

    test('no resistance when not overscrolled', () {
      final ScrollMetrics scrollPosition = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        pixels: 300.0,
        viewportDimension: 100.0,
        axisDirection: AxisDirection.down,
      );

      expect(
        physicsUnderTest.applyPhysicsToUserOffset(scrollPosition, 10.0),
        10.0,
      );
      expect(
        physicsUnderTest.applyPhysicsToUserOffset(scrollPosition, -10.0),
        -10.0,
      );
    });

    test('easing an overscroll meets less resistance than tensioning', () {
      final ScrollMetrics overscrolledPosition = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        pixels: -20.0,
        viewportDimension: 100.0,
        axisDirection: AxisDirection.down,
      );

      final double easingApplied =
          physicsUnderTest.applyPhysicsToUserOffset(overscrolledPosition, -10.0);
      final double tensioningApplied =
          physicsUnderTest.applyPhysicsToUserOffset(overscrolledPosition, 10.0);

      expect(easingApplied.abs(), greaterThan(tensioningApplied.abs()));
    });

    test('overscroll a small list and a big list works the same way', () {
      final ScrollMetrics smallListOverscrolledPosition = FixedScrollMetrics(
          minScrollExtent: 0.0,
          maxScrollExtent: 10.0,
          pixels: -20.0,
          viewportDimension: 100.0,
          axisDirection: AxisDirection.down,
      );

      final ScrollMetrics bigListOverscrolledPosition = FixedScrollMetrics(
        minScrollExtent: 0.0,
        maxScrollExtent: 1000.0,
        pixels: -20.0,
        viewportDimension: 100.0,
        axisDirection: AxisDirection.down,
      );

      final double smallListOverscrollApplied =
          physicsUnderTest.applyPhysicsToUserOffset(smallListOverscrolledPosition, 10.0);

      final double bigListOverscrollApplied =
          physicsUnderTest.applyPhysicsToUserOffset(bigListOverscrolledPosition, 10.0);

      expect(smallListOverscrollApplied, equals(bigListOverscrollApplied));

      expect(smallListOverscrollApplied, greaterThan(1.0));
      expect(smallListOverscrollApplied, lessThan(20.0));
    });
  });

  test('ClampingScrollPhysics assertion test', () {
    const ClampingScrollPhysics physics = ClampingScrollPhysics();
    const double pixels = 500;
    final ScrollMetrics position = FixedScrollMetrics(
      pixels: pixels,
      minScrollExtent: 0,
      maxScrollExtent: 1000,
      viewportDimension: 0,
      axisDirection: AxisDirection.down,
    );
    expect(position.pixels, pixels);
    late FlutterError error;
    try {
      physics.applyBoundaryConditions(position, pixels);
    } on FlutterError catch (e) {
      error = e;
    } finally {
      expect(error, isNotNull);
      expect(error.diagnostics.length, 4);
      expect(error.diagnostics[2], isA<DiagnosticsProperty<ScrollPhysics>>());
      expect(error.diagnostics[2].style, DiagnosticsTreeStyle.errorProperty);
      expect(error.diagnostics[2].value, physics);
      expect(error.diagnostics[3], isA<DiagnosticsProperty<ScrollMetrics>>());
      expect(error.diagnostics[3].style, DiagnosticsTreeStyle.errorProperty);
      expect(error.diagnostics[3].value, position);
      // RegExp matcher is required here due to flutter web and flutter mobile generating
      // slightly different floating point numbers
      // in Flutter web 0.0 sometimes just appears as 0. or 0
      expect(
        error.toStringDeep(),
        matches(RegExp(
          r'''
FlutterError
   ClampingScrollPhysics\.applyBoundaryConditions\(\) was called
   redundantly\.
   The proposed new position\, 500(\.\d*)?, is exactly equal to the current
   position of the given FixedScrollMetrics, 500(\.\d*)?\.
   The applyBoundaryConditions method should only be called when the
   value is going to actually change the pixels, otherwise it is
   redundant\.
   The physics object in question was\:
     ClampingScrollPhysics
   The position object in question was\:
     FixedScrollMetrics\(500(\.\d*)?..\[0(\.\d*)?\]..500(\.\d*)?\)
''',
          multiLine: true,
        )),
      );
    }
  });

  testWidgets('PageScrollPhysics work with NestedScrollView', (WidgetTester tester) async {
    // Regression test for: https://github.com/flutter/flutter/issues/47850
    await tester.pumpWidget(Material(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: NestedScrollView(
          physics: const PageScrollPhysics(),
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverToBoxAdapter(child: Container(height: 300, color: Colors.blue)),
            ];
          },
          body: ListView.builder(
            itemBuilder: (BuildContext context, int index) {
              return Text('Index $index');
            },
            itemCount: 100,
          ),
        ),
      ),
    ));
    await tester.fling(find.text('Index 2'), const Offset(0.0, -300.0), 10000.0);
  });
}
