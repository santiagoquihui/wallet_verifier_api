import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wallet_verifier_api_example/main.dart';

void main() {
  const channel = MethodChannel('wallet_verifier_api');
  var nfcStatus = 'enabled';
  final methods = <String>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return switch (call.method) {
            'isSupported' => true,
            'isAndroidReaderSupported' => true,
            'requestAndroidReaderPermissions' => true,
            'getNfcStatus' => nfcStatus,
            'openNfcSettings' => true,
            'requestDisplay' => 'approved',
            _ => null,
          };
        });
  });

  tearDown(() {
    nfcStatus = 'enabled';
    methods.clear();
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
    expect(find.text('NFC: enabled'), findsOneWidget);
    expect(find.text('Tap phone (NFC)'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Android asks to turn NFC on before a tap read', (tester) async {
    nfcStatus = 'disabled';
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('NFC: disabled'), findsOneWidget);
    await tester.tap(find.text('Tap phone (NFC)'));
    await tester.pumpAndSettle();

    expect(find.text('NFC is off'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(methods, contains('openNfcSettings'));
    expect(methods, isNot(contains('readMdlFromNfc')));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
