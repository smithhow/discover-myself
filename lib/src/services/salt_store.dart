/// Platform-selected [SaltStore] factory.
///
/// On IO platforms (iOS/Android/desktop) the file-backed implementation is
/// exported; on web the no-op stub is used, keeping `dart:io` out of the web
/// build's import graph.
library;

export 'salt_store_base.dart';
export 'salt_store_stub.dart' if (dart.library.io) 'salt_store_io.dart';
