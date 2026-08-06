import 'package:flutter_test/flutter_test.dart';

import 'package:rideality_app/main.dart';

void main() {
  testWidgets('Rideality welcome screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const RidealityApp());
    expect(find.text('Rideality'), findsWidgets);
    expect(find.text('Get started'), findsOneWidget);
  });
}
