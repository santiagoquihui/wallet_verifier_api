import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wallet_verifier_api_example/main.dart';

void main() {
  const channel = MethodChannel('wallet_verifier_api');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'isSupported' => true,
            'isAndroidReaderSupported' => true,
            'requestDisplay' => 'approved',
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows support status and request outcome', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Supported on this device: true'), findsOneWidget);

    await tester.tap(find.text('Check driver’s license (iOS 17+)'));
    await tester.pumpAndSettle();

    expect(find.text('Driver’s license, age 21+: approved'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android shows the mDL reader', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('mDL reader (Android)'), findsOneWidget);
    expect(find.text('Reader supported: true'), findsOneWidget);
    expect(find.text('Scan wallet QR code'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
