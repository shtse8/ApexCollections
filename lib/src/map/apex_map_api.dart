// Remove unused: import 'package:meta/meta.dart';
import 'apex_map.dart'; // Contains ApexMapImpl and its emptyInstance
// Remove unused import: 'champ_node.dart' as champ;

/// An immutable, persistent map implementation based on Compressed Hash-Array Mapped Prefix Tries (CHAMP).
///
/// `ApexMap` provides efficient operations for immutable maps, suitable for
/// functional programming patterns and state management. It aims for high
/// performance, especially for bulk operations and iteration, compared to
/// standard [Map] or other immutable map implementations.
///
/// Key performance characteristics (asymptotic complexity):
/// - Access (`[]`), Insert/Update (`add`), Removal (`remove`): Expected O(log N), worst case O(N) with hash collisions.
/// - Iteration: O(N)
///
/// It implements the standard Dart [Iterable] interface for its entries.
// @immutable // Temporarily removed due to transient nodes
abstract class ApexMap<K, V> implements Iterable<MapEntry<K, V>> {
  /// Creates an empty `ApexMap`.
  ///
  /// Returns the canonical empty map instance, ensuring efficiency.
  ///
  /// ```dart
  /// final emptyMap = ApexMap<String, int>.empty();
  /// print(emptyMap.isEmpty); // true
  /// ```
  factory ApexMap.empty() => ApexMapImpl.emptyInstance<K, V>();

  /// Const generative constructor for subclasses.
  ///
  /// **Note:** This constructor is typically not used directly. Use factories like
  /// [ApexMap.empty], [ApexMap.from], or [ApexMap.fromEntries].
  const ApexMap();

  /// Creates an `ApexMap` from an existing [Map].
  ///
  /// The key-value pairs from the source map are copied into the new `ApexMap`.
  ///
  /// **Note:** The current bulk-loading implementation (`ApexMapImpl.fromMap`)
  /// has a **severe performance issue** and is much slower than expected
  /// (significantly worse than O(N)). It requires profiling and fixing.
  /// The intended complexity is O(N).
  ///
  /// ```dart
  /// final sourceMap = {'a': 1, 'b': 2};
  /// final apexMap = ApexMap.from(sourceMap);
  /// print(apexMap['a']); // 1
  /// ```
  factory ApexMap.from(Map<K, V> map) {
    // Delegate to the implementation's factory constructor.
    return ApexMapImpl.fromMap(map);
  }

  /// Creates an `ApexMap` from an iterable of [MapEntry] instances.
  ///
  /// If the iterable contains multiple entries with the same key, the last
  /// occurrence overwrites previous ones.
  ///
  /// ```dart
  /// final entries = [MapEntry('x', 10), MapEntry('y', 20)];
  /// final apexMap = ApexMap.fromEntries(entries);
  /// print(apexMap['y']); // 20
  /// ```
  factory ApexMap.fromEntries(Iterable<MapEntry<K, V>> entries) {
    // Implementation uses transient building for efficiency.
    // Delegate to the implementation's factory constructor.
    // Note: ApexMapImpl.fromEntries is not explicitly defined.
    // This implementation creates an intermediate Map, which might not be optimal.
    // It also inherits the performance issue from ApexMap.fromMap.
    return ApexMapImpl.fromMap(Map.fromEntries(entries));
  }

  // --- Core Properties ---

  /// Returns the number of key-value pairs in the map.
  ///
  /// Accessing length is an O(1) operation.
  @override
  int get length;

  /// Returns `true` if the map contains no key-value pairs.
  ///
  /// Accessing isEmpty is an O(1) operation.
  @override
  bool get isEmpty;

  /// Returns `true` if the map contains at least one key-value pair.
  ///
  /// Accessing isNotEmpty is an O(1) operation.
  @override
  bool get isNotEmpty;

  /// Returns an iterable of the keys in the map.
  ///
  /// The order of keys is not guaranteed.
  /// Iterating the keys has O(N) complexity.
  Iterable<K> get keys;

  /// Returns an iterable of the values in the map.
  ///
  /// The order of values corresponds to the iteration order of the keys.
  /// Values can contain duplicates if multiple keys map to the same value.
  /// Iterating the values has O(N) complexity.
  Iterable<V> get values;

  /// Returns an iterable of the key-value pairs (entries) in the map.
  ///
  /// The order of entries is not guaranteed.
  /// Iterating the entries has O(N) complexity.
  /// This `ApexMap` itself is the `Iterable<MapEntry<K, V>>`.
  // No @override needed as it fulfills the Iterable interface contract
  Iterable<MapEntry<K, V>> get entries => this;

  // --- Element Access ---

  /// Returns the value for the given [key] or `null` if [key] is not in the map.
  ///
  /// Expected O(log N) average complexity.
  ///
  /// ```dart
  /// final map = ApexMap.from({'a': 1, 'b': 2});
  /// print(map['a']); // 1
  /// print(map['c']); // null
  /// ```
  V? operator [](K key);

  /// Returns `true` if this map contains the given [key].
  ///
  /// Expected O(log N) average complexity.
  ///
  /// ```dart
  /// final map = ApexMap.from({'a': 1});
  /// print(map.containsKey('a')); // true
  /// print(map.containsKey('b')); // false
  /// ```
  bool containsKey(K key);

  /// Returns `true` if this map contains the given [value].
  ///
  /// **Warning:** This operation requires iterating through all entries and
  /// can be expensive (O(N) complexity).
  ///
  /// ```dart
  /// final map = ApexMap.from({'a': 1, 'b': 2});
  /// print(map.containsValue(2)); // true
  /// print(map.containsValue(3)); // false
  /// ```
  bool containsValue(V value);

  // --- Modification Operations (Returning New Instances) ---

  /// Returns a new map with the [key]/[value] pair added or updated.
  ///
  /// If [key] already exists, its associated value is replaced with the new [value].
  /// If [key] does not exist, the new key-value pair is added.
  /// Expected O(log N) average complexity.
  ///
  /// ```dart
  /// final map1 = ApexMap<String, int>.empty();
  /// final map2 = map1.add('a', 1); // {'a': 1}
  /// final map3 = map2.add('b', 2); // {'a': 1, 'b': 2}
  /// final map4 = map3.add('a', 10); // {'a': 10, 'b': 2}
  /// ```
  ApexMap<K, V> add(K key, V value);

  /// Returns a new map containing all key-value pairs from [other] added to this map.
  ///
  /// If keys exist in both maps, the values from [other] overwrite the values
  /// in this map.
  /// Uses efficient transient operations internally. Complexity depends on the
  /// size of [other] and the overlap with this map.
  ///
  /// ```dart
  /// final map1 = ApexMap.from({'a': 1, 'b': 2});
  /// final map2 = {'b': 20, 'c': 3};
  /// final map3 = map1.addAll(map2);
  /// print(map3); // ApexMap(a: 1, b: 20, c: 3)
  /// ```
  ApexMap<K, V> addAll(Map<K, V> other); // Accepts standard Map

  /// Returns a new map with the entry for [key] removed, if it exists.
  ///
  /// If [key] is not in the map, returns the original map instance.
  /// Expected O(log N) average complexity.
  ///
  /// ```dart
  /// final map1 = ApexMap.from({'a': 1, 'b': 2});
  /// final map2 = map1.remove('a');
  /// print(map2); // ApexMap(b: 2)
  /// final map3 = map2.remove('c'); // Key 'c' not present
  /// print(identical(map2, map3)); // true
  /// ```
  ApexMap<K, V> remove(K key);

  /// Returns a new map where the value for [key] is updated.
  ///
  /// - If [key] is present in the map, the [update] function is called with the
  ///   current value, and its return value replaces the existing value.
  /// - If [key] is not present and [ifAbsent] is provided, [ifAbsent] is called
  ///   and its return value is inserted into the map associated with [key].
  /// - If [key] is not present and [ifAbsent] is *not* provided, the map
  ///   remains unchanged.
  ///
  /// Expected O(log N) average complexity.
  ///
  /// ```dart
  /// final map1 = ApexMap.from({'a': 1, 'b': 2});
  /// // Update existing key 'a'
  /// final map2 = map1.update('a', (v) => v + 10); // ApexMap(a: 11, b: 2)
  /// // Try to update non-existent key 'c', add if absent
  /// final map3 = map2.update('c', (v) => v * 2, ifAbsent: () => 3); // ApexMap(a: 11, b: 2, c: 3)
  /// // Try to update non-existent key 'd', no ifAbsent (no change)
  /// final map4 = map3.update('d', (v) => v);
  /// print(identical(map3, map4)); // true
  /// ```
  ApexMap<K, V> update(
    K key,
    V Function(V value) update, {
    V Function()? ifAbsent,
  });

  /// Returns a new map with the values for all keys updated.
  ///
  /// Applies the [update] function to each key-value pair in the map.
  /// Uses efficient transient operations internally. Complexity is O(N).
  ///
  /// ```dart
  /// final map1 = ApexMap.from({'a': 1, 'b': 2});
  /// final map2 = map1.updateAll((key, value) => value * 10);
  /// print(map2); // ApexMap(a: 10, b: 20)
  /// ```
  ApexMap<K, V> updateAll(V Function(K key, V value) update);

  /// Looks up the value for the given [key], or adds a new value if it isn't there.
  ///
  /// Returns the value associated with [key]. If the key is present, returns
  /// the existing value. If the key is not present, calls [ifAbsent] to get
  /// a new value, adds the key-value pair to the map, and returns the new value.
  ///
  /// **Important:** This method returns the *value*, not the potentially modified map.
  /// The map instance itself only changes if a new key-value pair was added.
  /// To get the potentially updated map, use the [update] method with an `ifAbsent` callback.
  ///
  /// ```dart
  /// final map = ApexMap<String, int>.empty().add('a', 1);
  /// final valueA = map.putIfAbsent('a', () => 10); // Key 'a' exists
  /// print(valueA); // 1
  /// print(map);    // ApexMap(a: 1)
  ///
  /// final valueB = map.putIfAbsent('b', () => 2); // Key 'b' does not exist
  /// print(valueB); // 2
  /// // NOTE: 'map' instance itself is unchanged here because it's immutable.
  /// // To get the map with 'b' added, use update():
  /// final mapWithB = map.update('b', (v) => v, ifAbsent: () => 2);
  /// print(mapWithB); // ApexMap(a: 1, b: 2)
  /// ```
  V putIfAbsent(K key, V Function() ifAbsent);
  // TODO: Consider a `tryPutIfAbsent` that returns the new map?

  // --- Iterable Overrides & Common Methods ---
  // ApexMap implements Iterable<MapEntry<K, V>>

  /// Returns a new lazy [Iterator] that allows iterating the entries of this map.
  ///
  /// The order of iteration is not guaranteed.
  @override
  Iterator<MapEntry<K, V>> get iterator; // Required by Iterable

  /// Returns a new map containing all entries that satisfy the given [predicate].
  ///
  /// Uses efficient transient operations internally. Complexity is O(N).
  ///
  /// ```dart
  /// final map1 = ApexMap.from({'a': 1, 'b': 2, 'c': 3});
  /// final map2 = map1.removeWhere((key, value) => value.isEven);
  /// print(map2); // ApexMap(a: 1, c: 3)
  /// ```
  ApexMap<K, V> removeWhere(bool Function(K key, V value) predicate);

  /// Returns an empty map of the same type.
  ///
  /// Equivalent to calling `ApexMap.empty()`.
  ///
  /// ```dart
  /// final map = ApexMap.from({'a': 1});
  /// final emptyMap = map.clear();
  /// print(emptyMap.isEmpty); // true
  /// ```
  ApexMap<K, V> clear();

  /// Returns a standard Dart [Map] containing the key-value pairs from this
  /// `ApexMap`.
  ///
  /// The returned map is a mutable copy. The order of entries in the returned
  /// map is not guaranteed.
  /// Complexity is O(N).
  ///
  /// ```dart
  /// final apexMap = ApexMap.from({'a': 1, 'b': 2});
  /// final nativeMap = apexMap.toMap();
  /// print(nativeMap); // {a: 1, b: 2}
  /// print(nativeMap is Map<String, int>); // true
  /// ```
  Map<K, V> toMap();

  /// Applies the function [f] to each key-value pair of the map.
  ///
  /// Iteration order is not guaranteed.
  ///
  /// ```dart
  /// final map = ApexMap.from({'a': 1, 'b': 2});
  /// map.forEachEntry((key, value) {
  ///   print('Key: $key, Value: $value');
  /// });
  /// ```
  void forEachEntry(void Function(K key, V value) f);

  /// Returns a new map where all entries of this map have been transformed
  /// by the given [convert] function.
  ///
  /// The resulting map's key-value types ([K2], [V2]) are determined by the
  /// return type of the [convert] function.
  /// Uses efficient transient operations internally. Complexity is O(N).
  ///
  /// ```dart
  /// final map1 = ApexMap.from({'a': 1, 'b': 2});
  /// final map2 = map1.mapEntries((key, value) => MapEntry(key.toUpperCase(), value * 10));
  /// print(map2); // ApexMap(A: 10, B: 20)
  /// ```
  ApexMap<K2, V2> mapEntries<K2, V2>(
    MapEntry<K2, V2> Function(K key, V value) convert,
  );

  // --- Equality and HashCode ---

  /// Compares this map to [other] for equality.
  ///
  /// Two `ApexMap` instances are considered equal if they have the same length
  /// and contain the same key-value pairs. The order of entries does not matter.
  ///
  /// The comparison is efficient, typically O(N) in the worst case.
  @override
  bool operator ==(Object other);

  /// Returns the hash code for this map.
  ///
  /// The hash code is calculated based on the keys and values in the map,
  /// ensuring that equal maps have the same hash code. The order of entries
  /// does not affect the hash code.
  @override
  int get hashCode;

  // Note: Other standard Iterable<MapEntry<K,V>> methods (any, every, map, where, etc.)
  // are available because ApexMap implements Iterable, but they operate on the
  // entries and return standard Iterables, not new ApexMap instances.
}

// _EmptyApexMap class removed.
