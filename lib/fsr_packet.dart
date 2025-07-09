import 'dart:typed_data';

/// The FSR packet.  Time stamp and 7 FSR values (in the 'fsrs' array).
class FSRPacket {
  FSRPacket(this.rawPacket)
      : timestamp = _getTimestamp(rawPacket.sublist(1, 7)),
        fsrs = _parseFSRData(rawPacket.sublist(7));

  final Uint8List rawPacket;

  /// Timestamp in seconds
  final num timestamp;

  // The 7 FSR values.
  final List<num> fsrs;

  static num _getTimestamp(Uint8List timestampBytes) {
    num seconds = timestampBytes.sublist(0, 4).buffer.asByteData().getInt32(0);

    num miliseconds = timestampBytes.sublist(4).buffer.asByteData().getInt16(0);

    // this 'toString()' and 'parse()' avoids getting .xx99999999x values in decimals.
    return num.parse((seconds + (miliseconds / 1000.0)).toStringAsFixed(2));
  }

  static List<num> _parseFSRData(Uint8List fsrBytes) {
    List<num> fsrs = [];

    for (int i = 0; i < 14; i += 2) {
      fsrs.add(fsrBytes.sublist(i, i + 2).buffer.asByteData().getInt16(0));
    }

    return fsrs;
  }

  static FSRPacket test() {
    return FSRPacket(Uint8List.fromList(List.filled(21, 0)));
  }

  static FSRPacket empty() {
    return FSRPacket(Uint8List.fromList(List.filled(21, 0)));
  }
  // Add the toJson method
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'fsrs': fsrs,
    };
  }
}
