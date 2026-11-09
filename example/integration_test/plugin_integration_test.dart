// Runs against the real iOS plugin. Display requests need an entitled app,
// a supported iPhone and someone to present an ID, so only the calls that
// return without user interaction are covered here.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:wallet_verifier_api/wallet_verifier_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final plugin = WalletVerifierApi();

  testWidgets('isSupported answers', (tester) async {
    expect(await plugin.isSupported(), isA<bool>());
  });

  testWidgets('isNationalIDCardRegionSupported answers', (tester) async {
    expect(await plugin.isNationalIDCardRegionSupported('JP'), isA<bool>());
  });

  testWidgets('invalid region is rejected', (tester) async {
    await expectLater(
      plugin.displayNationalIDCard(region: '', elements: [DisplayElement.age]),
      throwsA(isA<WalletVerifierException>()),
    );
  });
}
