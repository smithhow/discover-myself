import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:discover_self/src/services/pin_service.dart';
import 'package:discover_self/src/services/salt_store.dart';

/// A [FlutterSecureStorage] whose read/write always throw, simulating a device
/// where the platform channel is unavailable or misbehaving.
class _ThrowingStorage extends FlutterSecureStorage {
  const _ThrowingStorage();

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      throw Exception('secure storage unavailable');

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      throw Exception('secure storage unavailable');
}

/// In-memory stand-in for the file-based secondary salt store.
class _MemorySaltStore implements SaltStore {
  List<int>? value;
  int reads = 0;
  int writes = 0;

  @override
  Future<List<int>?> read() async {
    reads++;
    return value;
  }

  @override
  Future<void> write(List<int> salt) async {
    writes++;
    value = List<int>.from(salt);
  }
}

/// Secondary store that always fails.
class _ThrowingSaltStore implements SaltStore {
  @override
  Future<List<int>?> read() async => throw Exception('file unavailable');

  @override
  Future<void> write(List<int> salt) async => throw Exception('file unavailable');
}

void main() {
  test('useSecureStorage:false returns a stable 16-byte salt with no platform channel',
      () async {
    final service =
        PinService(storage: const _ThrowingStorage(), useSecureStorage: false);
    final first = await service.salt();
    final second = await service.salt();
    expect(first.length, 16);
    expect(second, equals(first));
  });

  test('deriveKeyFor returns a 32-byte key', () async {
    final service = PinService(useSecureStorage: false);
    final key = await service.deriveKeyFor('1234');
    expect(key.length, 32);
  });

  test('salt persists to the file fallback when secure storage fails, and is '
      'stable across instances (no lockout)', () async {
    final store = _MemorySaltStore();
    final first = await PinService(
      storage: const _ThrowingStorage(),
      saltFallback: store,
    ).salt();
    expect(first.length, 16);
    expect(store.writes, greaterThan(0));

    final second = await PinService(
      storage: const _ThrowingStorage(),
      saltFallback: store,
    ).salt();
    expect(second, equals(first));
  });

  test('salt falls back to in-memory only when secure storage and file both '
      'fail', () async {
    final service = PinService(
      storage: const _ThrowingStorage(),
      saltFallback: _ThrowingSaltStore(),
    );
    final first = await service.salt();
    final second = await service.salt();
    expect(first.length, 16);
    expect(second, equals(first));
  });
}
