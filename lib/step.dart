import 'foot.dart';

class Step {
  Step(this.heelStrike, this.toeOff, this.side);

  /// Timestamp of heel contact in milliseconds
  final int heelStrike;

  /// Timestamp of toe off in milliseconds
  final int toeOff;
  final Foot side;
}
