import 'package:collection/collection.dart'; // For equality
import 'package:meta/meta.dart';

/// Abstract definition for an immutable, persistent map based on CHAMP Tries.
///
/// Provides efficient key lookups, insertions, updates, and removals (O(log N)
/// expected average, worst case O(N) with hash collisions). Features efficient
/// iteration and structural equality checks due to canonical representation.
@immutable
abstract class ApexMap<K, V> implements Iterable<MapEntry<K, V>> {
  /// Creates an empty ApexMap.
  ///
  /// This should be a const constructor pointing to a shared empty instance.
  const factory ApexMap.empty() = _EmptyApexMap<K, V>; // Implementation detail

  /// Const generative constructor for subclasses.
  const ApexMap();

  /// Creates an ApexMap from an existing map.
  factory ApexMap.from(Map<K, V> map) {
    // TODO: Implementation using a transient builder for efficiency
    if (map.isEmpty) return ApexMap.empty();
    throw UnimplementedError('ApexMap.from');
  }

  /// Creates an ApexMap from an iterable of map entries.
  factory ApexMap.fromEntries(Iterable<MapEntry<K, V>> entries) {
    // TODO: Implementation using a transient builder for efficiency
    if (entries.isEmpty) return ApexMap.empty();
    throw UnimplementedError('ApexMap.fromEntries');
  }

  // --- Core Properties ---

  /// Returns the number of key-value pairs in the map.
  @override
  int get length;

  /// Returns `true` if the map contains no key-value pairs.
  @override
  bool get isEmpty;

  /// Returns `true` if the map contains key-value pairs.
  @override
  bool get isNotEmpty;

  /// Returns an iterable of the keys in the map.
  Iterable<K> get keys;

  /// Returns an iterable of the values in the map.
  Iterable<V> get values;

  /// Returns an iterable of the key-value pairs (entries) in the map.
  Iterable<MapEntry<K, V>> get entries =>
      this; // Implements Iterable<MapEntry<K,V>>

  // --- Element Access ---

  /// Returns the value for the given [key] or `null` if [key] is not in the map.
  V? operator [](K key);

  /// Returns `true` if this map contains the given [key].
  bool containsKey(K key);

  /// Returns `true` if this map contains the given [value].
  /// Note: This operation can be expensive (O(N)).
  bool containsValue(V value);

  // --- Modification Operations (Returning New Instances) ---

  /// Returns a new map with the [key]/[value] pair added or updated.
  /// If [key] already exists, its value is replaced.
  ApexMap<K, V> add(K key, V value);

  /// Returns a new map with all key-value pairs from [other] added.
  /// If keys exist in both maps, the values from [other] overwrite the original values.
  ApexMap<K, V> addAll(Map<K, V> other); // Accepts standard Map

  /// Returns a new map with the entry for [key] removed, if it exists.
  ApexMap<K, V> remove(K key);

  /// Returns a new map where the value for [key] is updated.
  /// If [key] exists, applies [update] to the existing value.
  /// If [key] does not exist, calls [ifAbsent] to get a new value and adds it.
  ApexMap<K, V> update(
    K key,
    V Function(V value) update, {
    V Function()? ifAbsent,
  });

  /// Returns a new map where the values for all keys are updated.
  /// Applies the [update] function to each key-value pair.
  ApexMap<K, V> updateAll(V Function(K key, V value) update);

  /// Returns the value for [key] if it exists, otherwise computes and adds
  /// the value returned by [ifAbsent] and returns the new value.
  /// This operation conceptually performs a lookup and potentially an add.
  /// The returned map instance will be different only if a new value was added.
  /// Note: The return type is V, but the map itself might change.
  /// A separate method might be needed if returning the potentially new map is desired.
  V putIfAbsent(K key, V Function() ifAbsent);
  // TODO: Consider a `tryPutIfAbsent` that returns the new map?

  // --- Iterable Overrides & Common Methods ---

  @override
  Iterator<MapEntry<K, V>> get iterator;

  // TODO: Consider equality (operator ==) and hashCode implementation details.
  // TODO: Consider other common Map/Iterable methods (map, where, etc.)
}

// Concrete implementation for the empty map singleton
class _EmptyApexMap<K, V> extends ApexMap<K, V> {
  const _EmptyApexMap();

  @override
  int get length => 0;

  @override
  bool get isEmpty => true;

  @override
  bool get isNotEmpty => false;

  @override
  Iterable<K> get keys => const Iterable.empty();

  @override
  Iterable<V> get values => const Iterable.empty();

  @override
  V? operator [](K key) => null;

  @override
  bool containsKey(K key) => false;

  @override
  bool containsValue(V value) => false;

  @override
  ApexMap<K, V> add(K key, V value) {
    // TODO: Return a concrete ApexMap implementation with one entry
    throw UnimplementedError('Add on empty map should create a new map');
  }

  @override
  ApexMap<K, V> addAll(Map<K, V> other) => ApexMap.from(other);

  @override
  ApexMap<K, V> remove(K key) => this;

  @override
  ApexMap<K, V> update(
    K key,
    V Function(V value) update, {
    V Function()? ifAbsent,
  }) {
    if (ifAbsent != null) {
      return add(key, ifAbsent());
    }
    return this; // Key doesn't exist, nothing to update
  }

  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) update) => this; // No entries to update

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    // This implementation is tricky for an immutable empty map.
    // It conceptually needs to return the *value* but the operation
    // implies a potential *modification* (returning a new map).
    // A real implementation would likely handle this within its structure.
    // For the empty map, it always adds.
    // We cannot return the new map instance here based on the signature.
    // This highlights a potential API design challenge for putIfAbsent.
    // Let's return the computed value, acknowledging the map itself isn't returned.
    return ifAbsent();
    // throw UnimplementedError('putIfAbsent on empty map needs careful API design');
  }

  // --- Iterable implementations ---
  @override
  Iterator<MapEntry<K, V>> get iterator => const <Never>[].iterator;

  // Default implementations for other Iterable methods (any, every, etc.)
  // can often be derived from iterator and length, potentially via a mixin
  // if needed later, but let's keep it explicit for now for clarity.

  @override
  bool any(bool Function(MapEntry<K, V> element) test) => false;

  @override
  Iterable<T> cast<T>() => <T>[]; // Or ApexMap<RK, RV>.empty() if K,V match T? Needs thought.

  @override
  bool contains(Object? element) => false;

  @override
  MapEntry<K, V> elementAt(int index) => throw RangeError.index(index, this);

  @override
  bool every(bool Function(MapEntry<K, V> element) test) => true;

  @override
  Iterable<T> expand<T>(
    Iterable<T> Function(MapEntry<K, V> element) toElements,
  ) => const [];

  @override
  MapEntry<K, V> get first => throw StateError('No element');

  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) {
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  T fold<T>(
    T initialValue,
    T Function(T previousValue, MapEntry<K, V> element) combine,
  ) => initialValue;

  @override
  Iterable<MapEntry<K, V>> followedBy(Iterable<MapEntry<K, V>> other) => other;

  @override
  void forEach(void Function(MapEntry<K, V> element) action) {}

  @override
  String join([String separator = '']) => '';

  @override
  MapEntry<K, V> get last => throw StateError('No element');

  @override
  MapEntry<K, V> lastWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) {
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<T> map<T>(T Function(MapEntry<K, V> e) convert) => const [];

  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) => throw StateError('No element');

  @override
  MapEntry<K, V> get single => throw StateError('No element');

  @override
  MapEntry<K, V> singleWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) {
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<MapEntry<K, V>> skip(int count) {
    RangeError.checkNotNegative(count, 'count');
    return const [];
  }

  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => const [];

  @override
  Iterable<MapEntry<K, V>> take(int count) {
    RangeError.checkNotNegative(count, 'count');
    return const [];
  }

  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => const [];

  @override
  List<MapEntry<K, V>> toList({bool growable = true}) => [];

  @override
  Set<MapEntry<K, V>> toSet() => {};

  @override
  Iterable<MapEntry<K, V>> where(bool Function(MapEntry<K, V> element) test) =>
      const [];

  @override
  Iterable<T> whereType<T>() => const [];

  // --- Equality and HashCode ---
  @override
  bool operator ==(Object other) => other is ApexMap && other.isEmpty;

  @override
  int get hashCode => 0; // Consistent hash code for empty map
}
