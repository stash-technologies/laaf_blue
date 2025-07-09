import 'package:blue/step.dart';
import 'package:blue/foot.dart';

import 'package:blue/step_data_calculator.dart';
import 'package:test/test.dart';

void main() {
  const String s = "Step Data Calculator";
  test('$s calculates double leg support (% of total stepping time)', () {
    StepDataCalculator calculator = StepDataCalculator(2);

    Step oneRight = Step(0, 250, Foot.right);
    Step oneLeft = Step(100, 350, Foot.left);
    Step twoRight = Step(300, 550, Foot.right);

    calculator.addStep(oneRight);
    calculator.addStep(oneLeft);
    calculator.addStep(twoRight);

    // should be 150 / 200
    expect(calculator.lastDoubleLegSupport.value(), 150 / 200);
  });
}
