import 'package:flutter_test/flutter_test.dart';
import 'package:z8_portal/app/app.dart';

void main() {
  testWidgets('opens the Z8 Card Manager login page', (tester) async {
    await tester.pumpWidget(const Z8App());

    expect(find.text('Z8 Card Manager'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
