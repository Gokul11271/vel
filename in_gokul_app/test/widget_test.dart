import 'package:flutter_test/flutter_test.dart';
import 'package:in_gokul_app/main.dart';

void main() {
  testWidgets('App loads test', (WidgetTester tester) async {
    await tester.pumpWidget(const IndoorNavigationApp());
    await tester.pumpAndSettle();
    expect(find.text('Indoor Navigator'), findsOneWidget);
  });
}
