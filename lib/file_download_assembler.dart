import 'dart:async';
import 'dart:typed_data';

/// Concatenates GATT file chunks into one buffer.
///
/// Native iOS and Android always report `isComplete: false`, so the transfer
/// ends only after [idleComplete] of silence or [overallTimeout]. A short BLE
/// stall must not finish the download: later chunks belong in the same buffer.
class FileDownloadAssembler {
  FileDownloadAssembler({
    this.idleComplete = const Duration(seconds: 15),
    this.overallTimeout = const Duration(minutes: 8),
    this.onFinished,
  });

  final Duration idleComplete;
  final Duration overallTimeout;

  /// Called once, when the armed download ends. Empty [bytes] means failure.
  final void Function(Uint8List bytes, {required bool success})? onFinished;

  final BytesBuilder _buffer = BytesBuilder(copy: false);
  Completer<Uint8List?>? _completer;
  Timer? _idleTimer;
  Timer? _overallTimer;
  bool _armed = false;

  /// True while a download future is still pending.
  bool get isArmed => _armed && _completer != null && !_completer!.isCompleted;

  /// Arms a new download. Returns null when one is already in progress and
  /// leaves that download untouched.
  Future<Uint8List?>? arm({Duration? idleComplete, Duration? overallTimeout}) {
    if (isArmed) return null;
    _cancelTimers();
    if (_buffer.length > 0) {
      _buffer.takeBytes();
    }
    _sessionIdle = idleComplete ?? this.idleComplete;
    _sessionOverall = overallTimeout ?? this.overallTimeout;
    _armed = true;
    final completer = Completer<Uint8List?>();
    _completer = completer;
    _overallTimer = Timer(_sessionOverall, () {
      _finish(success: _buffer.length > 0);
    });
    return completer.future;
  }

  Duration _sessionIdle = const Duration(seconds: 15);
  Duration _sessionOverall = const Duration(minutes: 8);

  /// Appends [chunk] when a download is armed. Ignored otherwise, including
  /// after the download has already completed.
  void addChunk(Uint8List chunk, {bool isComplete = false}) {
    if (!isArmed) return;
    if (_isNoiseFileHeader(chunk)) {
      _restartIdle();
      return;
    }
    if (chunk.isEmpty) return;
    _buffer.add(chunk);
    if (isComplete) {
      _finish(success: true);
      return;
    }
    _restartIdle();
  }

  /// Ends the armed download with no bytes. No-op when nothing is armed.
  void abort() {
    if (!isArmed) return;
    _finish(success: false);
  }

  void _restartIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_sessionIdle, () {
      _finish(success: _buffer.length > 0);
    });
  }

  void _finish({required bool success}) {
    if (!isArmed) return;
    _cancelTimers();
    final completer = _completer;
    final bytes = success && _buffer.length > 0 ? Uint8List.fromList(_buffer.takeBytes()) : Uint8List(0);
    _armed = false;
    _completer = null;
    onFinished?.call(bytes, success: bytes.isNotEmpty);
    if (completer != null && !completer.isCompleted) {
      completer.complete(bytes.isEmpty ? null : bytes);
    }
  }

  void _cancelTimers() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _overallTimer?.cancel();
    _overallTimer = null;
  }

  static bool _isNoiseFileHeader(Uint8List chunk) {
    return chunk.length == 9 && chunk[0] == 0x10;
  }
}
