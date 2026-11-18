import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nam_cinema/app/bootstrap.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Nam Cinema E2E Smoke Launch Test', (tester) async {
    await app.bootstrap();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('NAM CINEMA'), findsWidgets);
  });
}
