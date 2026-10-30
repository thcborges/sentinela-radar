import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/main.dart';

void main() {
  testWidgets('SentinelaApp deve inicializar com MaterialApp e tema Material 3', (tester) async {
    await tester.pumpWidget(const SentinelaApp(useInMemoryDb: true));
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
    expect(materialApp.theme?.brightness, equals(Brightness.dark));
    expect(find.text('SENTINELA'), findsOneWidget);
  });
}
