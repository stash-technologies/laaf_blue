/// Elements are added to the queue, and if it exceeds the 'maxSize', then
/// the oldest elements are discarded.  The oldest element is always at index
/// 0).
class CappedQueue<T> {
  /// TODO => make this use a linked list instead of a list
  /// (shouldn't matter for small datasets)
  CappedQueue(this.maxSize);

  List<T> _data = [];
  final int maxSize;

  int length() {
    return _data.length;
  }

  List<T> getAll() {
    return List.from(_data);
  }

  T? getLast() {
    if (_data.isNotEmpty) {
      return _data[_data.length - 1];
    } else {
      return null;
    }
  }

  /// start is inclusive, end id exclusive
  List<T> sublist(int start, int end) {
    return _data.sublist(start, end);
  }

  T? getAt(int index) {
    if (_data.length > index) {
      return _data[index];
    } else {
      return null;
    }
  }

  void add(T element) {
    if (_data.length < maxSize) {
      _data.add(element);
      return;
    }

    if (_data.length == maxSize) {
      // shuffle everything over one
      List<T> temp = List.from(_data);

      for (int i = 0; i < maxSize - 1; i++) {
        temp[i] = _data[i + 1];
      }

      temp[maxSize - 1] = element;

      _data = temp;
    }
  }

  void clear() {
    _data = [];
  }

  // I don't need to remove anything...
}
