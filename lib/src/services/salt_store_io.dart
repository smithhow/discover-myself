import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'salt_store_base.dart';

/// File-backed implementation of [SaltStore] for IO platforms.
///
/// Kept in its own file (selected via a conditional import in `salt_store.dart`)
/// so the web build never pulls in `dart:io`.
SaltStore createSaltStore() => _FileSaltStore();

class _FileSaltStore implements SaltStore {
  static const String _fileName = 'pin_salt.txt';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<List<int>?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final contents = await file.readAsString();
    if (contents.isEmpty) return null;
    return base64.decode(contents);
  }

  @override
  Future<bool> write(List<int> salt) async {
    try {
      final file = await _file();
      await file.writeAsString(base64.encode(salt), flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
