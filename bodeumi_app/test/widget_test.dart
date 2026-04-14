import 'package:flutter_test/flutter_test.dart';

import 'package:bodeumi/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const BodeumiApp());
    expect(find.text('보드미'), findsOneWidget);
  });
}
