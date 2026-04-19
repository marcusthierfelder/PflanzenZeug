import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pflanzen_zeug/main.dart';

void main() {
  testWidgets('App starts and shows loading', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PflanzenZeugApp()),
    );
    // App should render without crashing
    expect(find.byType(PflanzenZeugApp), findsOneWidget);
  });
}
