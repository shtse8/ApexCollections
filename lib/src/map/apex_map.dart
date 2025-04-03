import 'package:collection/collection.dart'; // For equality, mixins if needed
import 'apex_map_api.dart';
import 'champ_node.dart';

/// Concrete implementation of [ApexMap] using a CHAMP Trie.
class ApexMapImpl<K, V> extends ApexMap<K, V> {
  final ChampNode<K, V> _root;
  final int _length;
  // TODO: Consider caching hashCode

  /// Internal constructor. Use factories like ApexMap.empty() or ApexMap.from().
  const ApexMapImpl._(this._root, this._length);

  // --- Core Properties ---

  /// Factory constructor to create from a Map.
  factory ApexMapImpl.fromMap(Map<K, V> map) {
    if (map.isEmpty) {
      // Cannot return ApexMap.empty() directly from here yet.
      throw UnimplementedError('Cannot return empty map from impl factory yet');
    }
    // TODO: Actual implementation using builder/nodes
    throw UnimplementedError('ApexMapImpl.fromMap');
  }

  @override
  int get length => _length;

  @override
  bool get isEmpty => _length == 0;

  @override
  bool get isNotEmpty => _length > 0;

  @override
  Iterable<K> get keys => throw UnimplementedError('keys iterable');

  @override
  Iterable<V> get values => throw UnimplementedError('values iterable');

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
    // Requires iterating values - potentially expensive
    throw UnimplementedError('containsValue');
  }

  // --- Modification Operations ---

  @override
  ApexMap<K, V> add(K key, V value) {
    // TODO: Handle null keys if necessary
    final newRoot = _root.add(key, value, key.hashCode, 0);
    if (identical(newRoot, _root)) return this;
    // TODO: Need a way to track if size actually increased (add vs update)
    // This requires the node 'add' method to return more info or
    // perform a size check/lookup before adding.
    // Assuming for now size increases if root changes (simplification).
    return ApexMapImpl._(newRoot, _length + 1); // Incorrect length if update
    // throw UnimplementedError('add - needs size tracking');
  }

  @override
  ApexMap<K, V> addAll(Map<K, V> other) {
    // TODO: Efficient bulk add, possibly using transient builder
    throw UnimplementedError('addAll');
  }

  @override
  ApexMap<K, V> remove(K key) {
    // TODO: Handle null keys if necessary
    // TODO: Need remove to signal if a change occurred for length update
    final newRoot = _root.remove(key, key.hashCode, 0 /*, removedFlag */);
    if (identical(newRoot, _root)) return this;
    // Assume size decreased (simplification)
    return ApexMapImpl._(newRoot, _length - 1);
    // throw UnimplementedError('remove - needs size tracking');
  }

  @override
  ApexMap<K, V> update(
    K key,
    V Function(V value) update, {
    V Function()? ifAbsent,
  }) {
    // TODO: Implement logic using get/add
    throw UnimplementedError('update');
  }

  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) update) {
    // TODO: Implement by iterating and building a new map
    throw UnimplementedError('updateAll');
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
  Iterator<MapEntry<K, V>> get iterator => throw UnimplementedError('iterator');

  // Add stubs for other required Iterable methods
  @override
  bool any(bool Function(MapEntry<K, V> element) test) =>
      throw UnimplementedError('any');
  @override
  Iterable<T> cast<T>() => throw UnimplementedError('cast');
  @override
  bool contains(Object? element) => throw UnimplementedError('contains'); // Note: element is MapEntry
  @override
  MapEntry<K, V> elementAt(int index) => throw UnimplementedError('elementAt');
  @override
  bool every(bool Function(MapEntry<K, V> element) test) =>
      throw UnimplementedError('every');
  @override
  Iterable<T> expand<T>(
    Iterable<T> Function(MapEntry<K, V> element) toElements,
  ) => throw UnimplementedError('expand');
  @override
  MapEntry<K, V> get first => throw UnimplementedError('first');
  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => throw UnimplementedError('firstWhere');
  @override
  T fold<T>(
    T initialValue,
    T Function(T previousValue, MapEntry<K, V> element) combine,
  ) => throw UnimplementedError('fold');
  @override
  Iterable<MapEntry<K, V>> followedBy(Iterable<MapEntry<K, V>> other) =>
      throw UnimplementedError('followedBy');
  @override
  void forEach(void Function(MapEntry<K, V> element) action) =>
      throw UnimplementedError('forEach');
  @override
  String join([String separator = '']) => throw UnimplementedError('join');
  @override
  MapEntry<K, V> get last => throw UnimplementedError('last');
  @override
  MapEntry<K, V> lastWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => throw UnimplementedError('lastWhere');
  @override
  Iterable<T> map<T>(T Function(MapEntry<K, V> e) convert) =>
      throw UnimplementedError('map');
  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) => throw UnimplementedError('reduce');
  @override
  MapEntry<K, V> get single => throw UnimplementedError('single');
  @override
  MapEntry<K, V> singleWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => throw UnimplementedError('singleWhere');
  @override
  Iterable<MapEntry<K, V>> skip(int count) => throw UnimplementedError('skip');
  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => throw UnimplementedError('skipWhile');
  @override
  Iterable<MapEntry<K, V>> take(int count) => throw UnimplementedError('take');
  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => throw UnimplementedError('takeWhile');
  @override
  List<MapEntry<K, V>> toList({bool growable = true}) =>
      throw UnimplementedError('toList');
  @override
  Set<MapEntry<K, V>> toSet() => throw UnimplementedError('toSet');
  @override
  Iterable<MapEntry<K, V>> where(bool Function(MapEntry<K, V> element) test) =>
      throw UnimplementedError('where');
  @override
  Iterable<T> whereType<T>() => throw UnimplementedError('whereType');

  // TODO: Implement == and hashCode based on structural equality.
  @override
  bool operator ==(Object other) => throw UnimplementedError('operator ==');

  @override
  int get hashCode => throw UnimplementedError('hashCode');
}

// Need to link the factory constructor in the API file to this implementation
// This requires modifying apex_map_api.dart slightly.
