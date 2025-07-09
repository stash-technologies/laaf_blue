import 'package:test/test.dart';
import 'package:blue/capped_queue.dart';

void main() {
  test('queue resets on max size', () {
    CappedQueue<int> queue = CappedQueue(3);

    for (int j = 0; j < 10; j++) {
      queue.add(j);
    }

    expect(queue.getAll(), [7, 8, 9]);
  });

  test('queue resets on small overage', () {
    CappedQueue<int> queue = CappedQueue(3);

    for (int j = 0; j < 4; j++) {
      queue.add(j);
    }

    expect(queue.getAll(), [1, 2, 3]);
  });
}
