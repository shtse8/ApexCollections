import 'package:collection/collection.dart'; // For equality, mixins if needed
import 'apex_map_api.dart';
import 'champ_node.dart';

/// Concrete implementation of [ApexMap] using a CHAMP Trie.
class ApexMapImpl<K, V> extends ApexMap<K, V> {
  /// The root node of the CHAMP Trie. Can be ChampEmptyNode.
  final ChampNode<K, V> _root;

  /// The number of key-value pairs in the map.
  final int _length;
  // TODO: Consider caching hashCode

  /// The canonical empty instance (internal).
  static final ApexMapImpl _emptyInstance = ApexMapImpl._(
    ChampEmptyNode.instance(),
    0,
  );

  /// Public accessor for the canonical empty instance.
  static ApexMapImpl<K, V> emptyInstance<K, V>() =>
      _emptyInstance as ApexMapImpl<K, V>;

  /// Internal constructor. Not const because ChampEmptyNode.instance() isn't const.
  ApexMapImpl._(this._root, this._length);

  // --- Core Properties ---

  /// Factory constructor to create from a Map.
  factory ApexMapImpl.fromMap(Map<K, V> map) {
    if (map.isEmpty) {
      return emptyInstance<K, V>();
    }
    // Basic implementation: start with empty and repeatedly add. Inefficient.
    // TODO: Actual implementation using builder/nodes for efficiency
    ApexMap<K, V> apexMap = emptyInstance<K, V>();
    map.forEach((key, value) {
      apexMap = apexMap.add(key, value); // Uses the basic add implementation
    });
    // Need to handle length correctly based on add/update logic in 'add'
    // For now, assume length is map.length (only correct if no updates happened)
    // return ApexMapImpl._((apexMap as ApexMapImpl)._root, map.length);
    // Let's return the result of the adds, length will be wrong until 'add' is fixed.
    return apexMap as ApexMapImpl<K, V>;
  }

  @override
  int get length => _length;

  @override
  bool get isEmpty => _length == 0;

  @override
  bool get isNotEmpty => _length > 0;

  @override
  // Basic implementation using iterator. Inefficient.
  // TODO: Implement efficient keys/values iterables based on tree traversal.
  Iterable<K> get keys => entries.map((entry) => entry.key);

  @override
  // Basic implementation using iterator. Inefficient.
  // TODO: Implement efficient keys/values iterables based on tree traversal.
  Iterable<V> get values => entries.map((entry) => entry.value);

  // --- Element Access ---

  @override
  V? operator [](K key) {
    // TODO: Handle null keys if necessary based on API decision
    return _root.get(key, key.hashCode, 0);
  }

  @override
  bool containsKey(K key) {
    return this[key] != null; // Simple check, might optimize later
  }

  @override
  bool containsValue(V value) {
    // Requires iterating values - potentially expensive. Basic implementation.
    // TODO: Optimize if possible (unlikely without extra data structures).
    for (final entry in entries) {
      if (entry.value == value) {
        return true;
      }
    }
    return false;
  }

  // --- Modification Operations ---

  @override
  ApexMap<K, V> add(K key, V value) {
    // TODO: Handle null keys if necessary
    final newRoot = _root.add(key, value, key.hashCode, 0);
    if (identical(newRoot, _root)) return this; // No change

    // TODO: Need a way to track if size actually increased (add vs update).
    // The node 'add' method should ideally signal this, or we need to check containsKey first.
    // For now, we *incorrectly* assume size always increases if the root changes.
    final newLength = containsKey(key) ? _length : _length + 1; // Basic check
    return ApexMapImpl._(newRoot, newLength);
  }

  @override
  ApexMap<K, V> addAll(Map<K, V> other) {
    // Basic implementation: repeatedly call add. Inefficient.
    // TODO: Efficient bulk add, possibly using transient builder
    if (other.isEmpty) return this;
    ApexMap<K, V> current = this;
    other.forEach((key, value) {
      current = current.add(key, value);
    });
    return current;
  }

  @override
  ApexMap<K, V> remove(K key) {
    // TODO: Handle null keys if necessary
    // TODO: Need remove to signal if a change occurred for length update
    // TODO: Need remove to signal if a change occurred for length update.
    // Use a temporary flag or result object from node.remove in the future.
    bool removed = false; // Placeholder
    final currentLength = _length; // Capture length before potential removal
    final newRoot = _root.remove(key, key.hashCode, 0 /*, &removed */);

    if (identical(newRoot, _root)) return this; // No change

    // Placeholder logic for length update - assumes removal happened if root changed.
    // This is incorrect if remove modified structure without removing the key (e.g., collision node change).
    final newLength = _length - 1; // Incorrect if key wasn't actually present
    // A better check:
    // final newLength = currentLength > 0 && !containsKey(key) ? currentLength -1 : currentLength; // Check *after* supposed removal

    return ApexMapImpl._(
      newRoot,
      newLength,
    ); // Length update is likely wrong here
  }

  @override
  ApexMap<K, V> update(
    K key,
    V Function(V value) update, {
    V Function()? ifAbsent,
  }) {
    // Basic implementation using get/add. Inefficient.
    // TODO: Implement more efficiently using node operations.
    final V? currentValue = this[key];
    if (currentValue != null) {
      final newValue = update(currentValue);
      // Use add for update, relies on add handling key collision correctly
      return add(key, newValue);
    } else if (ifAbsent != null) {
      final newValue = ifAbsent();
      return add(key, newValue);
    } else {
      // Key not found and no ifAbsent provided
      return this;
    }
  }

  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) update) {
    // Basic implementation: iterate and build a new map. Inefficient.
    // TODO: Implement more efficiently using node operations or transients.
    if (isEmpty) return this;
    ApexMap<K, V> newMap = emptyInstance<K, V>();
    for (final entry in entries) {
      newMap = newMap.add(entry.key, update(entry.key, entry.value));
    }
    // Length remains the same
    return newMap;
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final existing = this[key];
    if (existing != null) {
      return existing;
    }
    // This API is awkward for immutable maps as it doesn't return the new map.
    // A real implementation might need internal state or a different API.
    // For the stub, we compute but don't modify 'this'.
    return ifAbsent();
    // throw UnimplementedError('putIfAbsent');
  }

  // --- Iterable<MapEntry<K, V>> implementations ---
  // Needs an efficient iterator over the CHAMP trie nodes.

  @override
  // Basic iterator implementation. Inefficient.
  // TODO: Implement efficient iterator based on tree traversal.
  Iterator<MapEntry<K, V>> get iterator => _ChampTrieIterator<K, V>(this); // Placeholder, needs implementation

  // Add stubs for other required Iterable methods
  @override
  bool any(bool Function(MapEntry<K, V> element) test) {
    for (final entry in entries) {
      if (test(entry)) return true;
    }
    return false;
  }

  @override
  Iterable<T> cast<T>() => entries.cast<T>(); // Delegate to entries iterable
  @override
  bool contains(Object? element) {
    if (element is! MapEntry<K, V>) return false;
    final value = this[element.key];
    return value != null && value == element.value;
  }

  @override
  MapEntry<K, V> elementAt(int index) {
    RangeError.checkValidIndex(index, this);
    // Inefficient: relies on iterator
    return entries.elementAt(index);
  }

  @override
  bool every(bool Function(MapEntry<K, V> element) test) {
    for (final entry in entries) {
      if (!test(entry)) return false;
    }
    return true;
  }

  @override
  Iterable<T> expand<T>(
    Iterable<T> Function(MapEntry<K, V> element) toElements,
  ) => entries.expand(toElements); // Delegate
  @override
  MapEntry<K, V> get first => entries.first; // Delegate
  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => entries.firstWhere(test, orElse: orElse); // Delegate
  @override
  T fold<T>(
    T initialValue,
    T Function(T previousValue, MapEntry<K, V> element) combine,
  ) => entries.fold(initialValue, combine); // Delegate
  @override
  Iterable<MapEntry<K, V>> followedBy(Iterable<MapEntry<K, V>> other) =>
      entries.followedBy(other); // Delegate
  @override
  void forEach(void Function(MapEntry<K, V> element) action) =>
      entries.forEach(action); // Delegate
  @override
  String join([String separator = '']) => entries.join(separator); // Delegate
  @override
  MapEntry<K, V> get last => entries.last; // Delegate
  @override
  MapEntry<K, V> lastWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => entries.lastWhere(test, orElse: orElse); // Delegate
  @override
  Iterable<T> map<T>(T Function(MapEntry<K, V> e) convert) =>
      entries.map(convert); // Delegate
  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) => entries.reduce(combine); // Delegate
  @override
  MapEntry<K, V> get single => entries.single; // Delegate
  @override
  MapEntry<K, V> singleWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => entries.singleWhere(test, orElse: orElse); // Delegate
  @override
  Iterable<MapEntry<K, V>> skip(int count) => entries.skip(count); // Delegate
  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => entries.skipWhile(test); // Delegate
  @override
  Iterable<MapEntry<K, V>> take(int count) => entries.take(count); // Delegate
  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => entries.takeWhile(test); // Delegate
  @override
  List<MapEntry<K, V>> toList({bool growable = true}) =>
      entries.toList(growable: growable); // Delegate
  @override
  Set<MapEntry<K, V>> toSet() => entries.toSet(); // Delegate
  @override
  Iterable<MapEntry<K, V>> where(bool Function(MapEntry<K, V> element) test) =>
      entries.where(test); // Delegate
  @override
  Iterable<T> whereType<T>() => entries.whereType<T>(); // Delegate

  // --- Added API Methods ---

  @override
  ApexMap<K, V> clear() {
    return emptyInstance<K, V>();
  }

  @override
  void forEachEntry(void Function(K key, V value) f) {
    // Basic implementation using iterator. Inefficient.
    // TODO: Implement efficient forEach based on tree traversal.
    for (final entry in entries) {
      f(entry.key, entry.value);
    }
  }

  @override
  ApexMap<K2, V2> mapEntries<K2, V2>(
    MapEntry<K2, V2> Function(K key, V value) convert,
  ) {
    // Basic implementation: iterate and build a new map. Inefficient.
    // TODO: Implement more efficiently using node operations or transients.
    if (isEmpty) return ApexMap.empty(); // Use API factory for target type
    ApexMap<K2, V2> newMap = ApexMap.empty();
    for (final entry in entries) {
      final newEntry = convert(entry.key, entry.value);
      newMap = newMap.add(newEntry.key, newEntry.value);
    }
    return newMap;
  }

  @override
  ApexMap<K, V> removeWhere(bool Function(K key, V value) predicate) {
    // Basic implementation: iterate and build a new map. Inefficient.
    // TODO: Implement more efficiently using node operations or transients.
    if (isEmpty) return this;
    ApexMap<K, V> current = this;
    List<K> keysToRemove = [];
    for (final entry in entries) {
      if (predicate(entry.key, entry.value)) {
        keysToRemove.add(entry.key);
      }
    }

    if (keysToRemove.isEmpty) return this;

    for (final key in keysToRemove) {
      current = current.remove(key);
    }
    return current;
  }

  // --- Equality and HashCode ---
  static const MapEquality _equality = MapEquality();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ApexMap<K, V>) return false;
    if (length != other.length) return false;
    if (isEmpty && other.isEmpty) return true;
    // TODO: Optimize equality check using tree comparison if possible.
    // Fallback to MapEquality using standard maps (inefficient).
    return _equality.equals(
      Map<K, V>.fromEntries(entries),
      Map<K, V>.fromEntries(other.entries),
    );
  }

  @override
  int get hashCode {
    if (isEmpty) return 0;
    // TODO: Optimize hash calculation using tree structure.
    // Fallback to MapEquality (inefficient).
    return _equality.hash(Map<K, V>.fromEntries(entries));
  }
}

// Need to link the factory constructor in the API file to this implementation
// TODO: Implement _ChampTrieIterator
class _ChampTrieIterator<K, V> implements Iterator<MapEntry<K, V>> {
  final ApexMapImpl<K, V> _map;
  // TODO: Add state for efficient tree traversal (stack, node iterators)
  Iterator<MapEntry<K, V>>? _backingIterator; // Temporary inefficient fallback
  int _count = 0;

  _ChampTrieIterator(this._map);

  void _initializeBackingIterator() {
    // Inefficient fallback: create a standard map and iterate its entries
    // This is done lazily to avoid circular dependency in constructor.
    _backingIterator ??= Map<K, V>.fromEntries(_map.entries).entries.iterator;
  }

  @override
  MapEntry<K, V> get current {
    if (_backingIterator == null) {
      // Ensure iterator is initialized if current is accessed before moveNext (though against contract)
      _initializeBackingIterator();
    }
    return _backingIterator!.current;
  }

  @override
  bool moveNext() {
    // Initialize lazily on first call
    _initializeBackingIterator();

    final result = _backingIterator!.moveNext();
    // _count isn't actually used anywhere currently, could be removed or used for validation.
    // if (result) _count++;
    return result;
  }
}
