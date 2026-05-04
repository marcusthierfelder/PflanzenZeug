import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pflanzenwart/main.dart';

void main() {
  testWidgets('App starts and shows loading', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PflanzenwartApp()),
    );
    // App should render without crashing
    expect(find.byType(PflanzenwartApp), findsOneWidget);
  });
}
