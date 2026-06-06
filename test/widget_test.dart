import 'package:flutter_test/flutter_test.dart';

import 'package:esignal/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ESignalApp());
    expect(find.byType(ESignalApp), findsOneWidget);
  });
}
