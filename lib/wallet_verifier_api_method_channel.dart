import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/models.dart';
import 'wallet_verifier_api_platform_interface.dart';

/// An implementation of [WalletVerifierApiPlatform] that uses method channels.
class MethodChannelWalletVerifierApi extends WalletVerifierApiPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wallet_verifier_api');

  @override
  Future<bool> isSupported() async {
    return await _invoke<bool>('isSupported') ?? false;
  }

  @override
  Future<bool> isNationalIDCardRegionSupported(String region) async {
    return await _invoke<bool>('isNationalIDCardRegionSupported', {
          'region': region,
        }) ??
        false;
  }

  @override
  Future<void> prepare({String? readerToken}) =>
      _invoke<void>('prepare', {'readerToken': ?readerToken});

  @override
  Future<String> readerInstanceIdentifier() async {
    final identifier = await _invoke<String>('readerInstanceIdentifier');
    if (identifier == null) {
      throw const WalletVerifierException(
        WalletVerifierErrorCode.invalidResponse,
        'Missing reader instance identifier',
      );
    }
    return identifier;
  }

  @override
  Future<ValidationOutcome> requestDisplay(DisplayRequest request) async {
    final outcome = await _invoke<String>('requestDisplay', request.toMap());
    return ValidationOutcome.values.firstWhere(
      (value) => value.name == outcome,
      orElse: () => throw WalletVerifierException(
        WalletVerifierErrorCode.invalidResponse,
        'Unexpected validation outcome: $outcome',
      ),
    );
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw WalletVerifierException(
        WalletVerifierErrorCode.fromCode(e.code),
        e.message,
      );
    }
  }
}
