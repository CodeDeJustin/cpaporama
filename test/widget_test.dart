import 'package:flutter_test/flutter_test.dart';

import 'package:cpaporama/app/cpaporama_app.dart';

void main() {
  testWidgets('L’app démarre', (WidgetTester tester) async {
    await tester.pumpWidget(const CpapOramaApp());

    // Smoke test: si ça rend sans exception, c’est déjà une victoire.
    expect(find.byType(CpapOramaApp), findsOneWidget);
  });
}