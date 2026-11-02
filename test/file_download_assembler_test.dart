import 'dart:typed_data';

import 'package:blue/file_download_assembler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const idle = Duration(seconds: 15);
  const overall = Duration(minutes: 8);

  FileDownloadAssembler assembler() {
    return FileDownloadAssembler(idleComplete: idle, overallTimeout: overall);
  }

  Uint8List bytes(List<int> values) => Uint8List.fromList(values);

  test('a 4 second gap stays in the same buffer', () {
    fakeAsync((async) {
      final download = assembler();
      final pending = download.arm();
      Uint8List? result;
      pending!.then((value) => result = value);

      download.addChunk(bytes([1, 2]));
      async.elapse(const Duration(seconds: 4));
      expect(download.isArmed, isTrue);

      download.addChunk(bytes([3, 4]));
      async.elapse(const Duration(seconds: 14));
      expect(download.isArmed, isTrue);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(result, bytes([1, 2, 3, 4]));
      expect(download.isArmed, isFalse);
    });
  });

  test('15 seconds of silence completes the download', () {
    fakeAsync((async) {
      final download = assembler();
      final pending = download.arm();
      Uint8List? result;
      pending!.then((value) => result = value);

      download.addChunk(bytes([9]));
      async.elapse(const Duration(seconds: 14));
      expect(result, isNull);
      expect(download.isArmed, isTrue);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(result, bytes([9]));
    });
  });

  test('a chunk after completion is dropped', () {
    fakeAsync((async) {
      final download = assembler();
      final pending = download.arm();
      Uint8List? result;
      pending!.then((value) => result = value);

      download.addChunk(bytes([1]));
      async.elapse(idle);
      async.flushMicrotasks();
      expect(result, bytes([1]));

      download.addChunk(bytes([2, 3]));
      expect(download.isArmed, isFalse);

      final again = download.arm();
      Uint8List? second;
      again!.then((value) => second = value);
      download.addChunk(bytes([8]));
      async.elapse(idle);
      async.flushMicrotasks();
      expect(second, bytes([8]));
    });
  });

  test('a second arm leaves the in-progress download running', () {
    fakeAsync((async) {
      final download = assembler();
      final first = download.arm();
      Uint8List? result;
      first!.then((value) => result = value);

      download.addChunk(bytes([4, 5, 6]));
      expect(download.arm(), isNull);
      expect(download.isArmed, isTrue);

      async.elapse(idle);
      async.flushMicrotasks();
      expect(result, bytes([4, 5, 6]));
    });
  });

  test('overall timeout returns the bytes received so far', () {
    fakeAsync((async) {
      final download = FileDownloadAssembler(
        idleComplete: const Duration(minutes: 1),
        overallTimeout: const Duration(seconds: 10),
      );
      final pending = download.arm();
      Uint8List? result;
      pending!.then((value) => result = value);

      download.addChunk(bytes([7, 8]));
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();
      expect(result, bytes([7, 8]));
      expect(download.isArmed, isFalse);
    });
  });
}
