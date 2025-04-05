import '../map/apex_map_api.dart';
import 'hamt_node.dart';
import 'hamt_iterator.dart'; // Import the iterator

/// Concrete implementation of [ApexMap] using Hash Array Mapped Tries (HAMT).
class ApexMapHamt<K, V> extends ApexMap<K, V> {
  final HamtNode<K, V> _root;
  final int _length;

  // Internal constructor for creating instances with known root and length.
  const ApexMapHamt._(this._root, this._length);

  // --- Factory Constructors ---

  /// The canonical empty instance.
  static final ApexMapHamt _emptyInstance = ApexMapHamt._(
    HamtEmptyNode.instance(),
    0,
  );

  /// Returns the canonical empty [ApexMapHamt] instance.
  static ApexMapHamt<K, V> empty<K, V>() => _emptyInstance as ApexMapHamt<K, V>;

  /// Creates an [ApexMapHamt] from an existing [Map].
  factory ApexMapHamt.from(Map<K, V> map) {
    if (map.isEmpty) {
      return empty<K, V>();
    }
    // TODO: Implement efficient bulk loading from Map
    HamtNode<K, V> root = HamtEmptyNode.instance<K, V>();
    final owner = TransientOwner(); // Use transient owner for bulk load
    int count = 0;
    for (final entry in map.entries) {
      final result = root.add(
        entry.key,
        entry.value,
        entry.key.hashCode,
        0,
        owner,
      );
      root = result.node;
      if (result.sizeChanged) {
        count++;
      }
    }
    owner.disown(); // Disown after bulk operation
    return ApexMapHamt._(root, count);
  }

  /// Creates an [ApexMapHamt] from an [Iterable] of [MapEntry].
  factory ApexMapHamt.fromEntries(Iterable<MapEntry<K, V>> entries) {
    if (entries.isEmpty) {
      return empty<K, V>();
    }
    // TODO: Implement efficient bulk loading from Iterable<MapEntry>
    HamtNode<K, V> root = HamtEmptyNode.instance<K, V>();
    final owner = TransientOwner();
    int count = 0;
    for (final entry in entries) {
      final result = root.add(
        entry.key,
        entry.value,
        entry.key.hashCode,
        0,
        owner,
      );
      root = result.node;
      if (result.sizeChanged) {
        count++;
      }
    }
    owner.disown();
    return ApexMapHamt._(root, count);
  }

  /// Creates an [ApexMapHamt] from an [Iterable] of keys and a value mapping function.
  factory ApexMapHamt.fromIterable(
    Iterable<K> keys, {
    V Function(K key)? value,
  }) {
    if (keys.isEmpty) {
      return empty<K, V>();
    }
    value ??= (K key) => key as V; // Default value mapping if not provided
    // TODO: Implement efficient bulk loading
    HamtNode<K, V> root = HamtEmptyNode.instance<K, V>();
    final owner = TransientOwner();
    int count = 0;
    for (final key in keys) {
      final val = value(key);
      final result = root.add(key, val, key.hashCode, 0, owner);
      root = result.node;
      if (result.sizeChanged) {
        count++;
      }
    }
    owner.disown();
    return ApexMapHamt._(root, count);
  }

  /// Creates an [ApexMapHamt] from two [Iterable]s: one for keys and one for values.
  factory ApexMapHamt.fromIterables(Iterable<K> keys, Iterable<V> values) {
    final keyList = keys.toList();
    final valueList = values.toList();
    if (keyList.length != valueList.length) {
      throw ArgumentError(
        'Keys and values iterables must have the same length.',
      );
    }
    if (keyList.isEmpty) {
      return empty<K, V>();
    }
    // TODO: Implement efficient bulk loading
    HamtNode<K, V> root = HamtEmptyNode.instance<K, V>();
    final owner = TransientOwner();
    int count = 0;
    for (int i = 0; i < keyList.length; i++) {
      final key = keyList[i];
      final value = valueList[i];
      final result = root.add(key, value, key.hashCode, 0, owner);
      root = result.node;
      if (result.sizeChanged) {
        count++;
      }
    }
    owner.disown();
    return ApexMapHamt._(root, count);
  }

  // --- Basic Properties ---

  @override
  bool get isEmpty => _length == 0;

  @override
  bool get isNotEmpty => _length > 0;

  @override
  int get length => _length;

  // --- Core Operations ---

  @override
  V? operator [](Object? key) {
    if (key is K) {
      return _root.get(key, key.hashCode, 0);
    }
    return null;
  }

  @override
  ApexMap<K, V> add(K key, V value) {
    final result = _root.add(
      key,
      value,
      key.hashCode,
      0,
      null,
    ); // No owner for single op
    if (!result.nodeChanged) {
      return this; // No change
    }
    final newLength = _length + (result.sizeChanged ? 1 : 0);
    return ApexMapHamt._(result.node, newLength);
  }

  @override
  ApexMap<K, V> remove(Object? key) {
    if (key is K) {
      final result = _root.remove(key, key.hashCode, 0, null); // No owner
      if (!result.nodeChanged) {
        return this; // No change
      }
      // sizeChanged is true if an element was actually removed
      final newLength = _length - (result.sizeChanged ? 1 : 0);
      return ApexMapHamt._(result.node, newLength);
    }
    return this; // Key type mismatch, no change
  }

  // --- Other Operations ---

  @override
  ApexMap<K, V> addAll(Map<K, V> other) {
    // TODO: Implement efficient addAll using transient owner
    if (other.isEmpty) return this;
    if (isEmpty) return ApexMapHamt.from(other);

    HamtNode<K, V> mutableRoot = _root;
    final owner = TransientOwner();
    int additions = 0;
    for (final entry in other.entries) {
      final result = mutableRoot.add(
        entry.key,
        entry.value,
        entry.key.hashCode,
        0,
        owner,
      );
      mutableRoot =
          result.node; // Update mutableRoot with potentially mutated node
      if (result.sizeChanged) {
        additions++;
      }
    }
    owner.disown();
    if (additions == 0 && identical(mutableRoot, _root))
      return this; // Check if anything actually changed
    return ApexMapHamt._(mutableRoot, _length + additions);
  }

  @override
  ApexMap<K, V> clear() {
    return empty<K, V>();
  }

  @override
  bool containsKey(Object? key) {
    if (key is K) {
      // Delegate to the node's containsKey method
      return _root.containsKey(key, key.hashCode, 0);
    }
    return false;
  }

  @override
  bool containsValue(Object? value) {
    // Inefficient: Requires iteration
    for (final entry in entries) {
      if (entry.value == value) {
        return true;
      }
    }
    return false;
  }

  @override
  ApexMap<RK, RV> mapEntries<RK, RV>(
    MapEntry<RK, RV> Function(K key, V value) f,
  ) {
    // TODO: Implement efficiently
    final newEntries = <MapEntry<RK, RV>>[];
    for (final entry in entries) {
      newEntries.add(f(entry.key, entry.value));
    }
    return ApexMapHamt.fromEntries(newEntries);
  }

  @override
  ApexMap<K, V> removeWhere(bool Function(K key, V value) predicate) {
    // TODO: Implement efficiently using transient owner
    if (isEmpty) return this;

    HamtNode<K, V> mutableRoot = _root;
    final owner = TransientOwner();
    int removalCount = 0;
    // Need to iterate carefully while removing
    final keysToRemove = <K>[];
    final iter = HamtIterator<K, V>(_root); // Use the specific iterator
    while (iter.moveNext()) {
      if (predicate(iter.currentKey, iter.currentValue)) {
        keysToRemove.add(iter.currentKey);
      }
    }

    if (keysToRemove.isEmpty) return this;

    for (final key in keysToRemove) {
      final result = mutableRoot.remove(key, key.hashCode, 0, owner);
      mutableRoot = result.node; // Update mutableRoot
      if (result.sizeChanged) {
        removalCount++;
      }
    }
    owner.disown();
    if (removalCount == 0)
      return this; // Should not happen if keysToRemove is not empty
    return ApexMapHamt._(mutableRoot, _length - removalCount);
  }

  @override
  ApexMap<K, V> update(
    K key,
    V Function(V value) update, {
    V Function()? ifAbsent,
  }) {
    // TODO: Implement efficiently using node-level update/ifAbsent logic
    final currentVal = this[key];
    if (currentVal != null || containsKey(key)) {
      // Handle null values
      final newValue = update(currentVal as V);
      return add(key, newValue); // Add will handle update
    } else if (ifAbsent != null) {
      return add(key, ifAbsent());
    } else {
      return this; // Key not found, no ifAbsent provided
    }
  }

  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) update) {
    // TODO: Implement efficiently using transient owner
    if (isEmpty) return this;

    HamtNode<K, V> mutableRoot = _root;
    final owner = TransientOwner();
    bool changed = false;

    // Need a way to update in place efficiently. Iterating and adding is inefficient.
    // Placeholder: inefficient implementation
    final newEntries = <MapEntry<K, V>>[];
    final iter = HamtIterator<K, V>(_root);
    while (iter.moveNext()) {
      final newValue = update(iter.currentKey, iter.currentValue);
      if (!identical(newValue, iter.currentValue)) {
        changed = true;
      }
      newEntries.add(MapEntry(iter.currentKey, newValue));
    }

    if (!changed) return this;

    // Rebuild from entries (very inefficient)
    return ApexMapHamt.fromEntries(newEntries);
  }

  @override
  Map<K, V> toMap() {
    final map = <K, V>{};
    final iter = HamtIterator<K, V>(_root);
    while (iter.moveNext()) {
      map[iter.currentKey] = iter.currentValue;
    }
    return map;
  }

  @override
  void forEachEntry(void Function(K key, V value) f) {
    final iter = HamtIterator<K, V>(_root);
    while (iter.moveNext()) {
      f(iter.currentKey, iter.currentValue);
    }
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final existingValue = this[key];
    // Need to check containsKey explicitly for null values
    if (existingValue != null || containsKey(key)) {
      return existingValue as V;
    } else {
      final newValue = ifAbsent();
      // Note: This add operation creates a new map instance internally,
      // but the original instance (this) remains unchanged, and the new
      // instance is not returned by putIfAbsent, as per the Map contract.
      // This behavior might be surprising for an immutable collection.
      // Consider if a different API (e.g., `tryAdd`) would be clearer.
      add(key, newValue); // This call doesn't update 'this' map instance
      return newValue;
    }
  }

  // --- Iteration ---

  @override
  Iterator<MapEntry<K, V>> get iterator {
    // This will create MapEntry objects, which we want to avoid if possible
    // for performance-critical iteration.
    // Consider adding keyIterator/valueIterator or a custom iterator interface.
    final hamtIter = HamtIterator<K, V>(_root);
    return _MapEntryIterator(hamtIter);
  }

  @override
  Iterable<MapEntry<K, V>> get entries => _MapEntryIterable<K, V>(this);

  @override
  Iterable<K> get keys => _KeyIterable<K, V>(this);

  @override
  Iterable<V> get values => _ValueIterable<K, V>(this);

  // --- Iterable Methods (delegated to entries) ---

  @override
  bool any(bool Function(MapEntry<K, V> element) test) => entries.any(test);

  @override
  Iterable<R> cast<R>() => entries.cast<R>();

  @override
  bool contains(Object? element) {
    if (element is MapEntry<K, V>) {
      // Check if the key exists and the value matches
      final V? value = this[element.key];
      // Use containsKey check for potential null values
      return containsKey(element.key) && value == element.value;
    }
    return false;
  }

  @override
  MapEntry<K, V> elementAt(int index) => entries.elementAt(index);

  @override
  bool every(bool Function(MapEntry<K, V> element) test) => entries.every(test);

  @override
  Iterable<T> expand<T>(
    Iterable<T> Function(MapEntry<K, V> element) toElements,
  ) => entries.expand(toElements);

  @override
  MapEntry<K, V> get first => entries.first; // Corrected getter syntax

  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => entries.firstWhere(test, orElse: orElse);

  @override
  T fold<T>(
    T initialValue,
    T Function(T previousValue, MapEntry<K, V> element) combine,
  ) => entries.fold(initialValue, combine);

  @override
  Iterable<MapEntry<K, V>> followedBy(Iterable<MapEntry<K, V>> other) =>
      entries.followedBy(other);

  @override
  void forEach(void Function(MapEntry<K, V> element) action) =>
      entries.forEach(action);

  @override
  String join([String separator = ""]) => entries.join(separator);

  @override
  MapEntry<K, V> get last => entries.last; // Corrected getter syntax

  @override
  MapEntry<K, V> lastWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => entries.lastWhere(test, orElse: orElse);

  @override
  Iterable<T> map<T>(T Function(MapEntry<K, V> element) toElement) =>
      entries.map(toElement);

  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) => entries.reduce(combine);

  @override
  MapEntry<K, V> get single => entries.single; // Corrected getter syntax

  @override
  MapEntry<K, V> singleWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => entries.singleWhere(test, orElse: orElse);

  @override
  Iterable<MapEntry<K, V>> skip(int count) => entries.skip(count);

  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => entries.skipWhile(test);

  @override
  Iterable<MapEntry<K, V>> take(int count) => entries.take(count);

  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => entries.takeWhile(test);

  @override
  List<MapEntry<K, V>> toList({bool growable = true}) =>
      entries.toList(growable: growable);

  @override
  Set<MapEntry<K, V>> toSet() => entries.toSet();

  @override
  Iterable<MapEntry<K, V>> where(bool Function(MapEntry<K, V> element) test) =>
      entries.where(test);

  @override
  Iterable<T> whereType<T>() => entries.whereType<T>();

  // --- Equality and HashCode ---

  @override
  int get hashCode => _root.hashCode ^ _length; // Simple hash combining root and length

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ApexMap<K, V>) return false; // Check against the API type
    if (other.length != length) return false;
    if (other is ApexMapHamt<K, V>) {
      // Optimization: If both are ApexMapHamt, compare roots directly
      return _root == other._root;
    }
    // Fallback: Compare entries (less efficient)
    // TODO: Implement efficient entry comparison if needed
    try {
      for (final entry in entries) {
        // Use containsKey check for null safety
        if (!other.containsKey(entry.key) || other[entry.key] != entry.value) {
          return false;
        }
      }
      return true;
    } catch (_) {
      // If other map throws on key access, they are not equal
      return false;
    }
  }
}

// --- Helper Iterables/Iterators ---

// Iterator wrapper to convert HamtIterator to Iterator<MapEntry<K,V>>
class _MapEntryIterator<K, V> implements Iterator<MapEntry<K, V>> {
  final HamtIterator<K, V> _hamtIterator;
  MapEntry<K, V>? _currentEntry;

  _MapEntryIterator(this._hamtIterator);

  @override
  MapEntry<K, V> get current {
    if (_currentEntry == null) {
      // This state should ideally not be reached if moveNext is called correctly.
      // Throwing StateError might be too strict if Dart's iterator protocol allows this.
      // Let's return a dummy or throw based on how standard iterators behave.
      // For now, rely on the HamtIterator's internal state check via currentEntry getter.
      return _hamtIterator.currentEntry;
    }
    return _currentEntry!;
  }

  @override
  bool moveNext() {
    if (_hamtIterator.moveNext()) {
      _currentEntry = _hamtIterator.currentEntry; // Creates a new MapEntry here
      return true;
    } else {
      _currentEntry = null;
      return false;
    }
  }
}

// Iterable wrapper for keys
class _KeyIterable<K, V> extends Iterable<K> {
  final ApexMapHamt<K, V> _map;
  const _KeyIterable(this._map);

  @override
  Iterator<K> get iterator => _KeyIterator<K, V>(_map);

  @override
  int get length => _map.length;
  @override
  bool get isEmpty => _map.isEmpty;
  @override
  bool get isNotEmpty => _map.isNotEmpty;
  @override
  K get first {
    // Corrected getter syntax
    final it = iterator;
    if (!it.moveNext()) throw StateError('No element');
    return it.current;
  }

  @override
  K get last {
    // Inefficient
    if (isEmpty) throw StateError('No element');
    K? lastKey;
    for (final key in this) {
      lastKey = key;
    }
    return lastKey!;
  }

  @override
  bool contains(Object? element) => _map.containsKey(element);
}

// Iterator for keys
class _KeyIterator<K, V> implements Iterator<K> {
  final HamtIterator<K, V> _hamtIterator;
  bool _hasCurrent = false;

  _KeyIterator(ApexMapHamt<K, V> map)
    : _hamtIterator = HamtIterator<K, V>(map._root);

  @override
  K get current {
    if (!_hasCurrent) throw StateError('No element');
    return _hamtIterator.currentKey;
  }

  @override
  bool moveNext() {
    _hasCurrent = _hamtIterator.moveNext();
    return _hasCurrent;
  }
}

// Iterable wrapper for values
class _ValueIterable<K, V> extends Iterable<V> {
  final ApexMapHamt<K, V> _map;
  const _ValueIterable(this._map);

  @override
  Iterator<V> get iterator => _ValueIterator<K, V>(_map);

  @override
  int get length => _map.length;
  @override
  bool get isEmpty => _map.isEmpty;
  @override
  bool get isNotEmpty => _map.isNotEmpty;
  @override
  V get first {
    // Corrected getter syntax
    final it = iterator;
    if (!it.moveNext()) throw StateError('No element');
    return it.current;
  }

  @override
  V get last {
    // Inefficient
    if (isEmpty) throw StateError('No element');
    V? lastValue;
    for (final value in this) {
      lastValue = value;
    }
    return lastValue!;
  }

  @override
  bool contains(Object? element) => _map.containsValue(element);
}

// Iterator for values
class _ValueIterator<K, V> implements Iterator<V> {
  final HamtIterator<K, V> _hamtIterator;
  bool _hasCurrent = false;

  _ValueIterator(ApexMapHamt<K, V> map)
    : _hamtIterator = HamtIterator<K, V>(map._root);

  @override
  V get current {
    if (!_hasCurrent) throw StateError('No element');
    return _hamtIterator.currentValue;
  }

  @override
  bool moveNext() {
    _hasCurrent = _hamtIterator.moveNext();
    return _hasCurrent;
  }
}

// Iterable wrapper for MapEntry using _MapEntryIterator
class _MapEntryIterable<K, V> extends Iterable<MapEntry<K, V>> {
  final ApexMapHamt<K, V> _map;
  const _MapEntryIterable(this._map);

  @override
  Iterator<MapEntry<K, V>> get iterator =>
      _MapEntryIterator<K, V>(HamtIterator<K, V>(_map._root)); // Create new iterator here

  @override
  int get length => _map.length;
  @override
  bool get isEmpty => _map.isEmpty;
  @override
  bool get isNotEmpty => _map.isNotEmpty;
  @override
  MapEntry<K, V> get first {
    // Corrected getter syntax
    final it = iterator;
    if (!it.moveNext()) throw StateError('No element');
    return it.current;
  }

  @override
  MapEntry<K, V> get last {
    // Inefficient
    if (isEmpty) throw StateError('No element');
    MapEntry<K, V>? lastEntry;
    for (final entry in this) {
      lastEntry = entry;
    }
    return lastEntry!;
  }

  // contains is inherited from Iterable
}
