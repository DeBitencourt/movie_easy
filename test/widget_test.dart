import 'package:flutter_test/flutter_test.dart';
import 'package:movie_easy/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MovieEasyApp());
    expect(find.byType(MovieEasyApp), findsOneWidget);
  });
}
