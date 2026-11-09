import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/display_request.dart';
import 'src/models.dart';
import 'wallet_verifier_api_method_channel.dart';

export 'src/display_request.dart';

abstract class WalletVerifierApiPlatform extends PlatformInterface {
  /// Constructs a WalletVerifierApiPlatform.
  WalletVerifierApiPlatform() : super(token: _token);

  static final Object _token = Object();

  static WalletVerifierApiPlatform _instance = MethodChannelWalletVerifierApi();

  /// The default instance of [WalletVerifierApiPlatform] to use.
  ///
  /// Defaults to [MethodChannelWalletVerifierApi].
  static WalletVerifierApiPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WalletVerifierApiPlatform] when
  /// they register themselves.
  static set instance(WalletVerifierApiPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> isSupported() {
    throw UnimplementedError('isSupported() has not been implemented.');
  }

  Future<bool> isNationalIDCardRegionSupported(String region) {
    throw UnimplementedError(
      'isNationalIDCardRegionSupported() has not been implemented.',
    );
  }

  Future<void> prepare({String? readerToken}) {
    throw UnimplementedError('prepare() has not been implemented.');
  }

  Future<String> readerInstanceIdentifier() {
    throw UnimplementedError(
      'readerInstanceIdentifier() has not been implemented.',
    );
  }

  Future<ValidationOutcome> requestDisplay(DisplayRequest request) {
    throw UnimplementedError('requestDisplay() has not been implemented.');
  }
}
