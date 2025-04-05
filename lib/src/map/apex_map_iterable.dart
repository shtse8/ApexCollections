/// Defines Iterable<MapEntry<K, V>> methods for [ApexMapImpl].
library;

import 'apex_map_impl.dart'; // Import the concrete implementation
import 'champ_iterator.dart'; // Import the iterator

/// Extension methods providing Iterable<MapEntry<K, V>> functionality for ApexMapImpl.
extension ApexMapImplIterable<K, V> on ApexMapImpl<K, V> {
  @override
  Iterator<MapEntry<K, V>> get iterator => ChampTrieIterator<K, V>(debugRoot!);

  @override
  bool any(bool Function(MapEntry<K, V> element) test) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      if (test(MapEntry(iter.currentKey, iter.currentValue))) return true;
    }
    return false;
  }

  @override
  Iterable<T> cast<T>() => entries.cast<T>(); // Delegate to entries getter

  @override
  bool contains(Object? element) {
    if (element is! MapEntry<K, V>) return false;
    // Use efficient containsKey and direct value access (assuming [] is available)
    if (!containsKey(element.key)) return false;
    final internalValue = this[element.key]; // Assumes operator[] is available
    return internalValue == element.value;
  }

  @override
  MapEntry<K, V> elementAt(int index) {
    RangeError.checkValidIndex(index, this);
    int count = 0;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      if (count == index) {
        return MapEntry(iter.currentKey, iter.currentValue);
      }
      count++;
    }
    throw StateError('Internal error: Index out of bounds after check');
  }

  @override
  bool every(bool Function(MapEntry<K, V> element) test) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      if (!test(MapEntry(iter.currentKey, iter.currentValue))) return false;
    }
    return true;
  }

  @override
  Iterable<T> expand<T>(
    Iterable<T> Function(MapEntry<K, V> element) toElements,
  ) => entries.expand(toElements); // Delegate to entries getter

  @override
  MapEntry<K, V> get first {
    final iter = iterator as ChampTrieIterator<K, V>;
    if (!iter.moveNext()) {
      throw StateError("Cannot get first element of an empty map");
    }
    return MapEntry(iter.currentKey, iter.currentValue);
  }

  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (test(entry)) return entry;
    }
    if (orElse != null) return orElse();
    throw StateError("No element matching test found");
  }

  @override
  T fold<T>(
    T initialValue,
    T Function(T previousValue, MapEntry<K, V> element) combine,
  ) {
    var value = initialValue;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      value = combine(value, MapEntry(iter.currentKey, iter.currentValue));
    }
    return value;
  }

  @override
  Iterable<MapEntry<K, V>> followedBy(Iterable<MapEntry<K, V>> other) =>
      entries.followedBy(other); // Delegate to entries getter

  @override
  void forEach(void Function(MapEntry<K, V> element) action) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      action(MapEntry(iter.currentKey, iter.currentValue));
    }
  }

  @override
  String join([String separator = '']) {
    // This still requires toList, which should be defined here or elsewhere
    return toList(growable: false).join(separator);
  }

  @override
  MapEntry<K, V> get last {
    final iter = iterator as ChampTrieIterator<K, V>;
    if (!iter.moveNext()) {
      throw StateError("Cannot get last element of an empty map");
    }
    MapEntry<K, V> result = MapEntry(iter.currentKey, iter.currentValue);
    while (iter.moveNext()) {
      result = MapEntry(iter.currentKey, iter.currentValue);
    }
    return result;
  }

  @override
  MapEntry<K, V> lastWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) {
    MapEntry<K, V>? foundEntry;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (test(entry)) {
        foundEntry = entry;
      }
    }
    if (foundEntry != null) return foundEntry;
    if (orElse != null) return orElse();
    throw StateError("No element matching test found");
  }

  @override
  Iterable<T> map<T>(T Function(MapEntry<K, V> e) convert) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      yield convert(MapEntry(iter.currentKey, iter.currentValue));
    }
  }

  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) {
    final iter = iterator as ChampTrieIterator<K, V>;
    if (!iter.moveNext()) {
      throw StateError("Cannot reduce empty collection");
    }
    var value = MapEntry(iter.currentKey, iter.currentValue);
    while (iter.moveNext()) {
      value = combine(value, MapEntry(iter.currentKey, iter.currentValue));
    }
    return value;
  }

  @override
  MapEntry<K, V> get single {
    final iter = iterator as ChampTrieIterator<K, V>;
    if (!iter.moveNext())
      throw StateError("Cannot get single element of an empty map");
    final result = MapEntry(iter.currentKey, iter.currentValue);
    if (iter.moveNext()) throw StateError("Map contains more than one element");
    return result;
  }

  @override
  MapEntry<K, V> singleWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) {
    MapEntry<K, V>? foundEntry;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (test(entry)) {
        if (foundEntry != null)
          throw StateError("Multiple elements match test");
        foundEntry = entry;
      }
    }
    if (foundEntry != null) return foundEntry;
    if (orElse != null) return orElse();
    throw StateError("No element matching test found");
  }

  @override
  Iterable<MapEntry<K, V>> skip(int count) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    int skipped = 0;
    while (iter.moveNext()) {
      if (skipped < count) {
        skipped++;
      } else {
        yield MapEntry(iter.currentKey, iter.currentValue);
      }
    }
  }

  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    bool skipping = true;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (skipping) {
        if (!test(entry)) {
          skipping = false;
          yield entry;
        }
      } else {
        yield entry;
      }
    }
  }

  @override
  Iterable<MapEntry<K, V>> take(int count) sync* {
    if (count <= 0) return;
    final iter = iterator as ChampTrieIterator<K, V>;
    int taken = 0;
    while (iter.moveNext() && taken < count) {
      yield MapEntry(iter.currentKey, iter.currentValue);
      taken++;
    }
  }

  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (test(entry)) {
        yield entry;
      } else {
        break;
      }
    }
  }

  @override
  List<MapEntry<K, V>> toList({bool growable = true}) {
    final list = <MapEntry<K, V>>[];
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      list.add(MapEntry(iter.currentKey, iter.currentValue));
    }
    if (growable) {
      return list;
    } else {
      return List<MapEntry<K, V>>.of(list, growable: false);
    }
  }

  @override
  Set<MapEntry<K, V>> toSet() {
    final set = <MapEntry<K, V>>{};
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      set.add(MapEntry(iter.currentKey, iter.currentValue));
    }
    return set;
  }

  @override
  Iterable<MapEntry<K, V>> where(
    bool Function(MapEntry<K, V> element) test,
  ) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (test(entry)) {
        yield entry;
      }
    }
  }

  @override
  Iterable<T> whereType<T>() sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final currentEntry = MapEntry(iter.currentKey, iter.currentValue);
      if (currentEntry is T) {
        yield currentEntry as T;
      }
    }
  }
}
