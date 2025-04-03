// For equality
import 'package:meta/meta.dart';
import 'apex_map.dart'; // Contains ApexMapImpl and its emptyInstance

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
  /// Creates an empty ApexMap.
  /// Returns the canonical empty map instance.
  factory ApexMap.empty() => ApexMapImpl.emptyInstance<K, V>();

  /// Const generative constructor for subclasses.
  const ApexMap();

  /// Creates an ApexMap from an existing map.
  factory ApexMap.from(Map<K, V> map) {
    // Delegate to the implementation's factory constructor.
    return ApexMapImpl.fromMap(map);
  }

  /// Creates an ApexMap from an iterable of map entries.
  factory ApexMap.fromEntries(Iterable<MapEntry<K, V>> entries) {
    // TODO: Implementation using a transient builder for efficiency
    // Placeholder for the actual implementation class constructor
    // return ApexMapImpl<K, V>.fromEntries(entries);
    if (entries.isEmpty) return ApexMap.empty();
    // TODO: Implement ApexMapImpl.fromEntries
    throw UnimplementedError('ApexMapImpl.fromEntries needs implementation');
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
  /// Expected O(log N) average complexity.
  V? operator [](K key);

  /// Returns `true` if this map contains the given [key].
  bool containsKey(K key);

  /// Returns `true` if this map contains the given [value].
  /// Note: This operation can be expensive (O(N)).
  bool containsValue(V value);

  // --- Modification Operations (Returning New Instances) ---

  /// Returns a new map with the [key]/[value] pair added or updated.
  /// If [key] already exists, its value is replaced.
  /// Expected O(log N) average complexity.
  ApexMap<K, V> add(K key, V value);

  /// Returns a new map with all key-value pairs from [other] added.
  /// If keys exist in both maps, the values from [other] overwrite the original values.
  ApexMap<K, V> addAll(Map<K, V> other); // Accepts standard Map

  /// Returns a new map with the entry for [key] removed, if it exists.
  /// Expected O(log N) average complexity.
  ApexMap<K, V> remove(K key);

  /// Returns a new map where the value for [key] is updated.
  /// If [key] exists, applies [update] to the existing value.
  /// If [key] does not exist, calls [ifAbsent] to get a new value and adds it.
  /// Returns a new map where the value for [key] is updated.
  /// If [key] exists, applies [update] to the existing value.
  /// If [key] does not exist and [ifAbsent] is provided, calls [ifAbsent]
  /// to get a new value and adds it. If [ifAbsent] is not provided,
  /// the map remains unchanged if the key is absent.
  /// Expected O(log N) average complexity.
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
  Iterator<MapEntry<K, V>> get iterator; // Required by Iterable

  /// Returns a new map containing all entries that satisfy the given [predicate].
  ApexMap<K, V> removeWhere(bool Function(K key, V value) predicate);

  /// Returns an empty map of the same type.
  ApexMap<K, V> clear();

  /// Applies the function [f] to each key-value pair of the map.
  void forEachEntry(void Function(K key, V value) f);

  /// Returns a new map where all entries of this map have been transformed
  /// by the given [convert] function.
  ApexMap<K2, V2> mapEntries<K2, V2>(
    MapEntry<K2, V2> Function(K key, V value) convert,
  );

  // --- Equality and HashCode ---

  /// Compares this map to [other] for equality.
  /// Two ApexMaps are equal if they have the same length and contain the same
  /// key-value pairs. Order doesn't matter.
  @override
  bool operator ==(Object other);

  /// Returns the hash code for this map.
  /// The hash code is based on the keys and values in the map.
  @override
  int get hashCode;
}

// _EmptyApexMap class removed.
