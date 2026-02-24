import 'package:flutter_test/flutter_test.dart';
import 'package:attandance_manager/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CampXAttendanceApp());

    // Verify that app loads
    expect(find.text('Loading...'), findsOneWidget);
  });
}
