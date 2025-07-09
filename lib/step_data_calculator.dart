import 'capped_queue.dart';

import 'step.dart';
import 'observable.dart';

/// Calculates values that require data from the right and left liners.
class StepDataCalculator {
  StepDataCalculator(this.n) {
    _steps = CappedQueue(n + 2);
  }

  /// the number of steps to consider when calculating the averages of these
  /// values. (that is "complete" steps, meaning you need n + 2 steps to actually
  /// calculate the average. )
  final int n;

  // steps is a queue with a max value of n + 2
  // (this 100 gets imediately replaced)
  late CappedQueue<Step> _steps;

  /// Ratio of time within step where both legs are on ground / total time
  Observable<double> lastDoubleLegSupport = Observable(0.5);
  // average for the last 'n' steps
  Observable<double> averageDoubleLegSupport = Observable(0.5);

  /// Ratio of time within step where only one leg was on ground / total time
  Observable<double> lastSingleLegSupport = Observable(0.5);
  Observable<double> averageSingleLegSupport = Observable(0.5);

  /// Returns 'true' if enough steps were collected to generate data for the
  /// previous step (it's the previous step because you can only calculate
  /// data for the middle step of three)
  bool addStep(Step newStep) {
    // verify that the steps are alternating

    if (_steps.length() == 0 || _steps.getLast()!.side == newStep.side) {
      _steps.clear();
    }

    // verify that the new step is within the time constriant (1.5 seconds)
    if (_steps.length() > 0 &&
        newStep.heelStrike - _steps.getLast()!.heelStrike >= 1500) {
      _steps.clear();
    }

    _steps.add(newStep);
    // if you have enough steps, calculate the values for the previous step
    // (for example, with steps [a, b, c], calculate values for step 'b')
    if (_steps.length() >= 3) {
      List<Step> lastThreeSteps = getLastThree(_steps);

      int doubleLegSupportTime =
          lastThreeSteps[0].toeOff - lastThreeSteps[1].heelStrike;

      if (doubleLegSupportTime < 0) {
        doubleLegSupportTime = 0;
      }

      int totalTime =
          lastThreeSteps[2].heelStrike - lastThreeSteps[1].heelStrike;

      // avoiding -Infinity, and other values caused by 0 timestamp anomaly
      if (totalTime == 0) {
        _steps.clear();
        return false;
      }
      // catching contact time anomalies (heelstrike before toe off on same foot)
      if (doubleLegSupportTime > totalTime) {
        _steps.clear();
        return false;
      }

      double doubleLegSupport = doubleLegSupportTime / totalTime;

      lastDoubleLegSupport.update(doubleLegSupport);

      averageDoubleLegSupport.update(
          ((averageDoubleLegSupport.value() * 9) + doubleLegSupport) / 10);

      int singleLegSupportTime = totalTime - doubleLegSupportTime;

      double singleLegSupport = singleLegSupportTime / totalTime;

      lastSingleLegSupport.update(singleLegSupport);

      averageSingleLegSupport.update(
          ((averageSingleLegSupport.value() * 9) + singleLegSupport) / 10);

      return true;
    }

    return false;
  }

  void reset() {
    _steps.clear();
    lastDoubleLegSupport.update(0.5);
    lastSingleLegSupport.update(0.5);
    averageSingleLegSupport.update(0.5);
    averageDoubleLegSupport.update(0.5);
  }

  num addSteps(List<Step> newSteps) {
    return -1;
  }

  List<Step> getLastThree(CappedQueue<Step> data) {
    return data.sublist(data.length() - 3, data.length());
  }
}
