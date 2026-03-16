import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:datagym/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // ProviderScope is necessary for Riverpod.
    await tester.pumpWidget(const ProviderScope(child: DataGymApp()));
    
    // Pump instead of pumpAndSettle if there are persistent animations (like loading spinners)
    await tester.pump(const Duration(seconds: 1));

    // Verify that our app shows the DataGym title in the home screen
    // Using find.text('DataGym') which is present in AppBar
    expect(find.text('DataGym'), findsWidgets);
    
    // Verify that we have the bottom navigation bar
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
