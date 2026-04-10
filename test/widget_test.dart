import 'package:flutter_test/flutter_test.dart';

import 'package:web_app/main.dart';

void main() {
  testWidgets('App bootstraps', (WidgetTester tester) async {
    await tester.pumpWidget(const WebApp());
    await tester.pump();

    expect(find.byType(WebApp), findsOneWidget);
  });
}
