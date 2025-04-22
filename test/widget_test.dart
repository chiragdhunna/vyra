import 'package:flutter_test/flutter_test.dart';

import 'package:vyra/main.dart';

void main() {
  testWidgets('MyApp renders correct environment title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(env: Environment.dev));

    // Check for the AppBar title or body text
    expect(find.text('Vyra - dev'), findsOneWidget);
    expect(find.text('Running in dev mode'), findsOneWidget);
  });
}
