import 'logger.dart';

/// 'Observable' objects call their 'observer' functions when their data is updated.
/// Other parts of the app that want to know when and how the data of these objects
/// changes, can observe and respond to those changes by registering an id
/// with a callback (through the 'Observable.observe' method).  They must also
/// remove themselves at the end of their lifecycle with one of the remove functions.
/// Preferable 'removeAllRelevantObservers(num id)'.
class Observable<T> {
  /// the value of this Observable.
  late T _data;

  /// Meant for logging and debugging purposes.
  String name;

  Observable(T initialValue, [this.name = ""]) {
    this._data = initialValue;
  }

  @override
  String toString() {
    return "$name : $_data / observers : ${_observers.length}";
  }

  final List<Observer> _observers = List.empty(growable: true);

  /// Register an 'id' and an 'observer' function, which will be called
  /// when the data of this Observable is updated. 'observer' functions
  /// should accept a single parameter, the new data.
  void observeChanges(int id, void Function(T) observer) {
    observer(_data);
    _observers.add(Observer<T>(id, observer));
  }
  // TODO => should you also be able to observe these anonymously? (sans key)

  /// Returns the current value of this Observable.
  T value() {
    return _data;
  }

  /// Update the value of this Observable, notifying all 'observers' of the new
  /// value.
  void update(T newValue, [shouldLog = false]) {
    List observersToRemove = List.empty();

    if (shouldLog) {
      Logger.log("'$name': $newValue", tag: "obs");
    }

    for (Observer o in _observers) {
      try {
        o = o as Observer<T>;
        o.function(newValue);
      } on Exception {
        if (shouldLog) {
          Logger.log("removing observer ${o.id}", tag: "obs-err");
        }
        observersToRemove.add(o);
      }
    }

    _data = newValue;

    if (observersToRemove.isNotEmpty) {
      _observers.removeWhere((o) => observersToRemove.contains(o));
    }
  }

  bool hasObservers() {
    return _observers.isNotEmpty;
  }

  /// Removes all observers associated with the given 'id'.
  void removeObserverById(int id) {
    _observers.removeWhere((o) => o.id == id);
  }

  /// Removes all observers that utilize the given 'function'.
  void removeObserver(Function(T) function) {
    _observers.removeWhere((o) => o.function == function);
  }

  /// Removes all observers of this Observable associated with the given 'id'.
  void removeRelevantObservers(num id) {
    _observers.removeWhere((o) => o.id == id);
  }

  /// Removes all observers of this Observable.
  void removeAllObservers() {
    _observers.removeRange(0, _observers.length);
  }
}

class Observer<T> {
  Observer(this.id, this.function);

  final num id;
  final void Function(T) function;
}
