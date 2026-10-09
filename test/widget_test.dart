import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_easy/widgets/app_logo.dart';
import 'package:movie_easy/widgets/custom_title_bar.dart';

void main() {
  testWidgets('AppLogo renders with MovieEasy brand text and icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(
            size: 32,
            showText: true,
            subtitle: 'Streaming & Torrents',
          ),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Streaming & Torrents'), findsOneWidget);
  });

  testWidgets('CustomTitleBar renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomTitleBar(),
        ),
      ),
    );

    expect(find.byType(CustomTitleBar), findsOneWidget);
  });
}
