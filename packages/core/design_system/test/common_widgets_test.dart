import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppScaffold renders title and body', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScaffold(
          title: 'Demo',
          body: Text('Hello world'),
        ),
      ),
    );

    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('LoadingOverlay shows spinner while loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoadingOverlay(
          loading: true,
          child: const Text('Loaded content'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loaded content'), findsOneWidget);
  });
}
