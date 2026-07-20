import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Placeholder Android integration suite.
///
/// Run on a device/emulator with:
/// `flutter test integration_test/android_smoke_test.dart -d <deviceId>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration harness loads', (tester) async {
    expect(true, isTrue);
  });
}
