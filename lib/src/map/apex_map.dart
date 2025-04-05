// Remove unused: import 'package:collection/collection.dart'
//     as collection; // For equality, mixins, bitCount
// Keep apex_map_api import
import 'apex_map_api.dart';
// Keep one champ_node import (exports everything else) with prefix
import 'champ_node.dart' as champ; // Use prefix for clarity and constants
// Keep one champ_iterator import
import 'champ_iterator.dart'; // Import the extracted iterator
// Remove duplicate imports

/// Concrete implementation of [ApexMap] using a CHAMP Trie.
class ApexMapImpl<K, V> extends ApexMap<K, V> {
  /// The root node of the CHAMP Trie. Can be ChampEmptyNode.
  final champ.ChampNode<K, V> _root;

  /// The number of key-value pairs in the map.
  final int _length;

  /// Cached hash code. Computed lazily.
  int? _cachedHashCode;

  /// The canonical empty instance (internal). Use Never for type safety.
  // Changed from const to final static because ChampEmptyNode is no longer const.
  static final ApexMapImpl<Never, Never> _emptyInstance = ApexMapImpl._(
    champ.ChampEmptyNode(), // Cannot be const anymore
    0,
  );

  /// Public accessor for the canonical empty instance. 
  static ApexMapImpl<K, V> emptyInstance<K, V>() {
    // If the requested types are Never, return the canonical singleton directly.
    if (K == Never && V == Never) {
      return _emptyInstance as ApexMapImpl<K, V>;
    }
    // Otherwise, return a new instance with the correct generic types,
    // but still using the singleton ChampEmptyNode internally.
    // This avoids type errors when calling methods like 'add' on an empty map
    // that was created with specific non-Never types.
    return ApexMapImpl<K, V>._(champ.ChampEmptyNode(), 0);
  }

  /// Internal constructor. Cannot be const due to mutable _cachedHashCode.
  ApexMapImpl._(this._root, this._length) : _cachedHashCode = null;

  /// Factory constructor to create an immutable [ApexMap] from a standard Dart [Map].
  ///
  /// Uses an O(N) bulk loading algorithm (`_buildNode`) that leverages transient
  /// mutation internally. While theoretically efficient, current benchmarks show
  /// performance (~8174us for 10k) is slower than competitors like FIC, and
  /// optimization attempts have been reverted. Further optimization is deferred.
  /// The resulting map is fully immutable. If the input [map] is empty, the
  /// canonical empty instance is returned.
  factory ApexMapImpl.fromMap(Map<K, V> map) {
    if (map.isEmpty) {
      return emptyInstance<K, V>();
    }

    // Convert map entries to a list for processing
    final entries = map.entries.toList();
    final owner = champ.TransientOwner();

    // Build the CHAMP trie recursively using the efficient bulk loading strategy
    final rootNode = _buildNode(entries, 0, owner);

    // Freeze the potentially transient root node
    final frozenRoot = rootNode.freeze(owner);

    // Return the new ApexMapImpl instance
    // The count is simply the number of unique entries from the original map
    // Note: This assumes the input map doesn't have duplicate keys,
    // which is guaranteed by the Map contract.
    return ApexMapImpl._(frozenRoot, map.length);
  }

  /// Recursive helper function for efficient bulk loading (O(N)) using a two-pass strategy.
  /// Builds a CHAMP node (potentially transient) from a list of entries at a given shift level.
  ///
  /// 1. **First Pass:** Partitions entries based on hash fragments and determines the
  ///    structure (data vs. node entries) for the current node level.
  /// 2. **Second Pass:** Populates the node's content array, recursively calling
  ///    `_buildNode` for partitions that require sub-nodes.
  ///
  /// Uses a [TransientOwner] to allow for in-place mutation during the build process,
  /// which is then frozen into an immutable structure.
  static champ.ChampNode<K, V> _buildNode<K, V>(
    List<MapEntry<K, V>> entries,
    int shift,
    champ.TransientOwner owner,
  ) {
    // --- Original Two-Pass Build Strategy ---
    if (entries.isEmpty) {
      return champ.ChampEmptyNode<K, V>();
    }

    if (entries.length == 1) {
      final entry = entries.first;
      // Data nodes are always immutable, no owner needed
      return champ.ChampDataNode<K, V>(
        entry.key.hashCode,
        entry.key,
        entry.value,
      );
    }

    // Check for hash collisions among all entries at this level
    final firstHash = entries.first.key.hashCode;
    bool allSameHash = true;
    for (int i = 1; i < entries.length; i++) {
      if (entries[i].key.hashCode != firstHash) {
        allSameHash = false;
        break;
      }
    }

    // If all entries have the same hash and we are at max depth, create CollisionNode
    if (allSameHash && shift >= champ.kMaxDepth * champ.kBitPartitionSize) {
      // Collision nodes can be transient
      return champ.ChampCollisionNode<K, V>(firstHash, entries, owner);
    }

    // 1. First Pass: Partition and calculate final maps
    final List<List<MapEntry<K, V>>> partitions = List.generate(
      1 << champ.kBitPartitionSize,
      (_) => [],
      growable: false, // Partitions list itself doesn't need to grow
    );
    int dataMap = 0;
    int nodeMap = 0;
    for (final entry in entries) {
      final frag = champ.indexFragment(shift, entry.key.hashCode);
      partitions[frag].add(entry); // Add entry to its partition
    }
    // Determine final dataMap and nodeMap based on partition lengths
    for (int i = 0; i < partitions.length; i++) {
      final partitionLength = partitions[i].length;
      if (partitionLength == 1) {
        dataMap |= (1 << i);
      } else if (partitionLength > 1) {
        nodeMap |= (1 << i);
      }
    }

    // 2. Calculate Size & Allocate final content list
    final dataCount = champ.bitCount(dataMap);
    final nodeCount = champ.bitCount(nodeMap);
    final contentSize = (dataCount * 2) + nodeCount;
    // Allocate the list directly. Use `null` as placeholder, assuming ChampInternalNode handles it.
    // Make it growable: true as ChampInternalNode constructor expects it for transient nodes.
    final List<Object?> finalContent = List.filled(
      contentSize,
      null,
      growable: true,
    );

    // 3. Second Pass: Populate the final content list directly
    // 3. Second Pass (Optimized): Populate finalContent directly using running indices
    int currentDataIndex = 0; // Tracks index within the conceptual data array
    int currentNodeIndex =
        0; // Tracks index within the conceptual reversed node array

    for (int frag = 0; frag < partitions.length; frag++) {
      final bitpos = 1 << frag;

      if ((dataMap & bitpos) != 0) {
        // Place data entry
        final payloadIndex = currentDataIndex * 2;
        final entry = partitions[frag].first;
        finalContent[payloadIndex] = entry.key;
        finalContent[payloadIndex + 1] = entry.value;
        currentDataIndex++;
      } else if ((nodeMap & bitpos) != 0) {
        // Build and place sub-node
        final actualNodeIndex = finalContent.length - 1 - currentNodeIndex;
        final partition = partitions[frag];
        final subNode = _buildNode(
          partition,
          shift + champ.kBitPartitionSize,
          owner,
        );
        finalContent[actualNodeIndex] = subNode;
        currentNodeIndex++;
      }
      // If neither dataMap nor nodeMap has the bit, partitions[frag] must be empty.
    }
    assert(currentDataIndex == dataCount);
    assert(currentNodeIndex == nodeCount);

    // 4. Create and return the correct transient node type based on count
    final childCount = dataCount + nodeCount;
    if (childCount <= champ.kSparseNodeThreshold) {
      return champ.ChampSparseNode<K, V>(dataMap, nodeMap, finalContent, owner);
    } else {
      return champ.ChampArrayNode<K, V>(dataMap, nodeMap, finalContent, owner);
    }
    // Removed extraneous lines from previous diff
  }

  @override
  int get length => _length;

  @override
  bool get isEmpty => _length == 0; // Can also check _root.isEmptyNode

  @override
  bool get isNotEmpty => _length > 0;

  @override
  // Use the efficient iterator directly
  Iterable<K> get keys sync* {
    // *** UPDATED TO USE PUBLIC ITERATOR ***
    final iterator = ChampTrieIterator<K, V>(_root);
    while (iterator.moveNext()) {
      yield iterator.current.key;
    }
  }

  @override
  // Use the efficient iterator directly
  Iterable<V> get values sync* {
    // *** UPDATED TO USE PUBLIC ITERATOR ***
    final iterator = ChampTrieIterator<K, V>(_root);
    while (iterator.moveNext()) {
      yield iterator.current.value;
    }
  }

  @override
  // Return 'this' as ApexMap itself is the iterable of entries
  Iterable<MapEntry<K, V>> get entries => this;

  // --- Element Access ---

  @override
  V? operator [](K key) {
    // TODO: Handle null keys if necessary based on API decision
    // Explicitly handle empty case to avoid type issues with Never node
    if (isEmpty) return null;
    return _root.get(key, key.hashCode, 0);
  }

  @override
  bool containsKey(K key) {
    if (isEmpty) return false; // Optimization for empty map
    // Delegate to the root node's containsKey method
    return _root.containsKey(key, key.hashCode, 0);
  }

  @override
  bool containsValue(V value) {
    if (isEmpty) return false;
    // Requires iterating values - potentially expensive.
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      if (iter.currentValue == value) { // Use currentValue
        return true;
      }
    }
    return false;
  }

  // --- Modification Operations ---

  @override
  ApexMap<K, V> add(K key, V value) {
    // ~6.25us (10k) - Slower than Native/FIC
    // TODO: Handle null keys if necessary
    // *** FIX: Handle empty case directly by checking identity with singleton ***
    if (identical(_root, champ.ChampEmptyNode())) {
      // Check identity with singleton
      // Create the first DataNode with the correct types K, V
      final newNode = champ.ChampDataNode<K, V>(key.hashCode, key, value);
      // Return a new ApexMapImpl instance directly
      return ApexMapImpl._(newNode, 1);
    }
    // If not empty, proceed with the node's add method
    // Pass null owner for immutable operation on non-empty root
    final addResult = _root.add(key, value, key.hashCode, 0, null);

    // If no actual addition occurred (key existed and value was identical),
    // the node operation returns didAdd: false. In this case, return 'this'.
    // Otherwise, always create a new ApexMapImpl with the result node.
    // The 'identical' check was potentially problematic and redundant for immutable ops.
    if (!addResult.didAdd && identical(addResult.node, _root)) {
      // Only return 'this' if nothing changed *at all*.
      // If only the value changed, addResult.node might be a new DataNode instance,
      // so we still need to create a new ApexMapImpl below.
      return this;
    }

    // Calculate the new length based on whether an actual insertion occurred.
    final newLength = _length + (addResult.didAdd ? 1 : 0);

    return ApexMapImpl._(addResult.node, newLength);
  }

  /// Returns a new map containing all key-value pairs from this map and all
  /// key-value pairs from the [other] map. If a key exists in both maps,
  /// the value from the [other] map is used.
  ///
  /// This operation leverages transient mutation internally for efficiency,
  /// especially when adding multiple entries. Performance is excellent (~31.60us for 10k).
  /// The resulting map is immutable.
  @override
  ApexMap<K, V> addAll(Map<K, V> other) {
    if (other.isEmpty) return this;

    // Special case: Adding to an empty map
    if (isEmpty) {
      return ApexMapImpl<K, V>.fromMap(other); // Use efficient factory
    }

    // Use transient building for efficiency
    final owner = champ.TransientOwner();
    // Get a mutable version of the current root node
    // Need to handle different root types for _ensureMutable
    champ.ChampNode<K, V> mutableRoot;
    if (_root is champ.ChampBitmapNode<K, V>) {
      mutableRoot = _root.ensureMutable(owner);
    } else if (_root is champ.ChampCollisionNode<K, V>) {
      mutableRoot = _root.ensureMutable(owner);
    } else {
      // Empty and Data nodes are immutable, start transient op from them
      mutableRoot = _root;
    }

    int additions = 0;

    other.forEach((key, value) {
      // Pass owner to mutate the root node structure
      final result = mutableRoot.add(key, value, key.hashCode, 0, owner);
      // Update reference ONLY IF the node identity changes (e.g., ensureMutable created a copy, or add returned a new node type)
      if (!identical(mutableRoot, result.node)) {
        mutableRoot = result.node;
      }
      if (result.didAdd) {
        additions++;
      }
    });

    // If no additions occurred and the root reference never changed (meaning _ensureMutable returned 'this' or root was immutable leaf),
    // then nothing actually changed structurally.
    if (additions == 0 && identical(mutableRoot, _root)) {
      return this;
    }

    // Freeze the final potentially mutable root node
    final frozenRoot = mutableRoot.freeze(owner);
    final newCount = _length + additions;

    // Return new instance with the frozen root and updated count
    return ApexMapImpl._(frozenRoot, newCount);
  }

  @override
  ApexMap<K, V> remove(K key) {
    // ~3.72us (10k) - Faster than FIC
    // TODO: Handle null keys if necessary
    if (isEmpty) return this; // Cannot remove from empty

    // Pass null owner for immutable operation
    final removeResult = _root.remove(key, key.hashCode, 0, null);

    // If the node itself didn't change, return the original map.
    if (identical(removeResult.node, _root)) return this;

    // Calculate the new length based on whether a removal actually occurred.
    final newLength = removeResult.didRemove ? _length - 1 : _length;

    // Ensure length doesn't go negative (shouldn't happen if didRemove is correct)
    assert(newLength >= 0);

    // If the new root is empty, return the canonical empty instance
    if (removeResult.node.isEmptyNode) {
      return emptyInstance<K, V>();
    }

    return ApexMapImpl._(removeResult.node, newLength);
  }

  @override
  ApexMap<K, V> update(
    K key,
    V Function(V value) updateFn, {
    V Function()? ifAbsent, // ~8.91us (10k) - Faster than FIC
  }) {
    final champ.ChampUpdateResult<K, V> updateResult;
    if (_root.isEmptyNode) {
      // Handle empty case directly
      if (ifAbsent != null) {
        final newValue = ifAbsent();
        // DataNode creation doesn't need owner
        final newNode = champ.ChampDataNode<K, V>(key.hashCode, key, newValue);
        updateResult = (node: newNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsent, no change
        // Return the correctly typed empty instance
        return emptyInstance<K, V>();
      }
    } else {
      // Delegate to the root node's update method.
      // Pass null owner for immutable operation
      updateResult = _root.update(
        key,
        key.hashCode,
        0, // Initial shift
        updateFn,
        ifAbsentFn: ifAbsent, // Pass ifAbsent callback
        owner: null,
      );
    }

    // If the node didn't change, return the original map.
    if (identical(updateResult.node, _root)) {
      return this;
    }

    // Calculate new length based on whether the size changed (insertion happened).
    final newLength = updateResult.sizeChanged ? _length + 1 : _length;

    // If the new root is empty, return the canonical empty instance
    if (updateResult.node.isEmptyNode) {
      return emptyInstance<K, V>();
    }

    return ApexMapImpl._(updateResult.node, newLength);
  }

  /// Returns a new map where each value is replaced by the result of applying
  /// the [updateFn] to its key and value.
  ///
  /// This operation leverages transient mutation internally for efficiency.
  /// The resulting map is immutable. Performance is generally good due to transient updates.
  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) updateFn) {
    if (isEmpty) return this;

    // Use transient building for efficiency
    final owner = champ.TransientOwner();
    // Get a mutable version of the current root node
    champ.ChampNode<K, V> mutableRoot;
    if (_root is champ.ChampBitmapNode<K, V>) {
      mutableRoot = _root.ensureMutable(owner);
    } else if (_root is champ.ChampCollisionNode<K, V>) {
      mutableRoot = _root.ensureMutable(owner);
    } else {
      // Empty and Data nodes are immutable, start transient op from them
      mutableRoot = _root;
    }

    bool changed = false;

    // Iterate through existing entries and apply updateFn using node's update
    // We iterate the original entries, but update the mutableRoot
    for (final entry in entries) {
      // Iterate original entries
      final key = entry.key;
      final currentValue = entry.value;
      final newValue = updateFn(key, currentValue);

      // Only update if the value actually changed
      if (!identical(newValue, currentValue)) {
        // Pass owner to mutate the root node structure
        // Since key exists, ifAbsentFn is not needed, sizeChanged should be false.
        final updateResult = mutableRoot.update(
          key,
          key.hashCode,
          0,
          (_) => newValue,
          owner: owner,
        );
        // Update reference ONLY IF the node identity changes
        if (!identical(mutableRoot, updateResult.node)) {
          mutableRoot = updateResult.node;
        }
        // Mark changed even if identity is same, as value was updated in place
        changed = true;
      }
    }

    // If nothing changed structurally or value-wise, return original
    if (!changed) {
      // We might have mutated a copy, ensure we return 'this' if the root is identical
      if (identical(mutableRoot, _root)) return this;
      // If mutableRoot is not identical, it means ensureMutable created a copy,
      // but no values changed. Freeze the copy and return it.
      final frozenRoot = mutableRoot.freeze(owner);
      return ApexMapImpl._(frozenRoot, _length);
    }

    // Freeze the final potentially mutable root node
    final frozenRoot = mutableRoot.freeze(owner);
    // Length doesn't change during updateAll
    return ApexMapImpl._(frozenRoot, _length);
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final existing = this[key]; // Uses efficient operator []
    if (existing != null) {
      return existing;
    }
    // This API is awkward for immutable maps as it doesn't return the new map.
    // We compute the value but cannot modify 'this'.
    return ifAbsent();
  }

  // --- Iterable<MapEntry<K, V>> implementations ---

  @override
  // *** UPDATED TO USE PUBLIC ITERATOR ***
  // Iteration uses the efficient ChampTrieIterator, but overall iteration
  // performance is currently slow (~2794us for 10k entries).
  Iterator<MapEntry<K, V>> get iterator => ChampTrieIterator<K, V>(_root);

  // Add stubs for other required Iterable methods
  @override
  bool any(bool Function(MapEntry<K, V> element) test) {
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      // Create entry only if test passes (or avoid if test uses key/value)
      // Assuming test needs MapEntry for now
      if (test(MapEntry(iter.currentKey, iter.currentValue))) return true;
    }
    return false;
  }

  @override
  Iterable<T> cast<T>() => entries.cast<T>(); // Delegate to entries iterable
  @override
  bool contains(Object? element) {
    if (element is! MapEntry<K, V>) return false;
    // Use efficient containsKey and direct value access
    if (!containsKey(element.key)) return false;
    final internalValue = this[element.key]; // Uses efficient operator []
    return internalValue == element.value;
  }

  @override
  MapEntry<K, V> elementAt(int index) {
    RangeError.checkValidIndex(index, this);
    // Inefficient: relies on iterator
    // Inefficient: still relies on iterator.elementAt or manual iteration
    // Manual iteration to avoid creating intermediate list/iterator
    int count = 0;
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      if (count == index) {
        return MapEntry(iter.currentKey, iter.currentValue); // Create entry at the end
      }
      count++;
    }
    // Should not be reached due to RangeError check, but needed for return type
    throw StateError('Internal error: Index out of bounds after check');
  }

  @override
  bool every(bool Function(MapEntry<K, V> element) test) {
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      // Create entry only if test fails (or avoid if test uses key/value)
      // Assuming test needs MapEntry for now
      if (!test(MapEntry(iter.currentKey, iter.currentValue))) return false;
    }
    return true;
  }

  @override
  Iterable<T> expand<T>(
    Iterable<T> Function(MapEntry<K, V> element) toElements,
  ) => entries.expand(toElements); // Delegate
  @override
  MapEntry<K, V> get first {
    // Use iterator directly to avoid recursion with entries getter
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    if (!iter.moveNext()) {
      throw StateError("Cannot get first element of an empty map");
    }
    return MapEntry(iter.currentKey, iter.currentValue); // Create entry at the end
  }

  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) {
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue); // Create entry for test
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
    // Explicit implementation using iterator
    var value = initialValue;
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      value = combine(value, MapEntry(iter.currentKey, iter.currentValue)); // Create entry for combine
    }
    return value;
  }

  @override
  Iterable<MapEntry<K, V>> followedBy(Iterable<MapEntry<K, V>> other) =>
      // Explicit implementation to potentially optimize later if needed
      return entries.followedBy(other);
  @override
  void forEach(void Function(MapEntry<K, V> element) action) =>
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      action(MapEntry(iter.currentKey, iter.currentValue)); // Create entry for action
    }
  @override
  String join([String separator = '']) {
     // Inefficient: requires creating all entries first.
     // Consider if a direct string build is better if performance critical.
     return toList(growable: false).join(separator);
  }
  @override
  MapEntry<K, V> get last {
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
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
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
     while (iter.moveNext()) {
       final entry = MapEntry(iter.currentKey, iter.currentValue); // Create entry for test
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
    // Explicit implementation using iterator
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      yield convert(MapEntry(iter.currentKey, iter.currentValue)); // Create entry for convert
    }
  }

  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) {
    // Explicit implementation using iterator
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    if (!iter.moveNext()) {
      throw StateError("Cannot reduce empty collection");
    }
    // Use currentKey/Value for initial value, but still need MapEntry for combine's type
    var value = MapEntry(iter.currentKey, iter.currentValue);
    while (iter.moveNext()) {
      value = combine(value, MapEntry(iter.currentKey, iter.currentValue)); // Create entry for combine
    }
    return value;
  }

  @override
  MapEntry<K, V> get single {
     final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
     if (!iter.moveNext()) throw StateError("Cannot get single element of an empty map");
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
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue); // Create entry for test
      if (test(entry)) {
        if (foundEntry != null) throw StateError("Multiple elements match test");
        foundEntry = entry;
      }
    }
    if (foundEntry != null) return foundEntry;
    if (orElse != null) return orElse();
    throw StateError("No element matching test found");
  }
  @override
  Iterable<MapEntry<K, V>> skip(int count) sync* {
    // Explicit implementation using iterator
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    int skipped = 0;
    while (iter.moveNext()) {
      if (skipped < count) {
        skipped++;
      } else {
        yield MapEntry(iter.currentKey, iter.currentValue); // Create entry to yield
      }
    }
  }

  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) sync* {
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    bool skipping = true;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue); // Create entry for test
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
    // Explicit implementation using iterator
    if (count <= 0) return;
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    int taken = 0;
    while (iter.moveNext() && taken < count) {
      yield MapEntry(iter.currentKey, iter.currentValue); // Create entry to yield
      taken++;
    }
  }

  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) sync* {
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
       final entry = MapEntry(iter.currentKey, iter.currentValue); // Create entry for test
       if (test(entry)) {
         yield entry;
       } else {
         break;
       }
    }
  }
  @override
  List<MapEntry<K, V>> toList({bool growable = true}) {
    // Explicit implementation using iterator
    final list = <MapEntry<K, V>>[];
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      list.add(MapEntry(iter.currentKey, iter.currentValue)); // Create entry to add
    }
    if (growable) {
      return list;
    } else {
      // If non-growable requested, copy to fixed-length list
      return List<MapEntry<K, V>>.of(list, growable: false);
    }
  }

  @override
  Set<MapEntry<K, V>> toSet() {
    // Explicit implementation using iterator to avoid potential recursion
    final set = <MapEntry<K, V>>{};
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      set.add(MapEntry(iter.currentKey, iter.currentValue)); // Create entry to add
    }
    return set;
  }

  @override
  Iterable<MapEntry<K, V>> where(
    bool Function(MapEntry<K, V> element) test,
  ) sync* {
    // Explicit implementation using iterator
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue); // Create entry for test
      if (test(entry)) {
        yield entry;
      }
    }
  }

  @override
  Iterable<T> whereType<T>() sync* {
    // Explicit implementation using iterator
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      // Need to check the type of the entry itself, not just yield
      // Need to create the entry to check its type
      final currentEntry = MapEntry(iter.currentKey, iter.currentValue);
      if (currentEntry is T) {
        yield currentEntry as T;
      }
    }
  }

  @override
  Map<K, V> toMap() {
    // Performance currently slow (~8736us for 10k)
    // Create a standard mutable map
    final map = <K, V>{};
    // Use the efficient iterator
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      map[iter.currentKey] = iter.currentValue; // Use direct key/value
    }
    return map;
  }

  // --- Added API Methods ---

  @override
  ApexMap<K, V> clear() {
    // Return a new empty instance via the factory
    return ApexMap<K, V>.empty();
  }

  @override
  void forEachEntry(void Function(K key, V value) f) {
    // Uses the efficient iterator implicitly via 'entries'
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      f(iter.currentKey, iter.currentValue); // Use direct key/value
    }
  }

  @override
  ApexMap<K2, V2> mapEntries<K2, V2>(
    MapEntry<K2, V2> Function(K key, V value) convert,
  ) {
    if (isEmpty) return ApexMap<K2, V2>.empty();

    // Use transient building for efficiency
    final owner = champ.TransientOwner();
    // Start with null root, create the first node on the first iteration.
    champ.ChampNode<K2, V2>? mutableNewRoot;
    int newCount = 0;

    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      // Iterate original entries using direct key/value
      final newEntry = convert(iter.currentKey, iter.currentValue);
      final K2 newKey = newEntry.key;
      final V2 newValue = newEntry.value;
      final int newKeyHash = newKey.hashCode;

      if (mutableNewRoot == null) {
        // First element: create the initial DataNode directly
        mutableNewRoot = champ.ChampDataNode<K2, V2>(
          newKeyHash,
          newKey,
          newValue,
        );
        newCount = 1; // Initialize count
      } else {
        // Subsequent elements: add to the existing root using transient owner
        final result = mutableNewRoot.add(
          newKey,
          newValue,
          newKeyHash,
          0,
          owner,
        );
        mutableNewRoot = result.node; // Update root reference
        if (result.didAdd) {
          newCount++;
        }
      }
    }

    // If the original map was empty or convert resulted in no entries, return empty.
    if (mutableNewRoot == null) {
      return ApexMap<K2, V2>.empty();
    }

    // If the resulting map is empty, return the canonical empty instance.
    if (newCount == 0) return ApexMap<K2, V2>.empty();

    // Freeze the final potentially mutable root node
    final frozenNewRoot = mutableNewRoot.freeze(owner);

    // Return the newly built map
    return ApexMapImpl<K2, V2>._(frozenNewRoot, newCount);
  }

  /// Returns a new map containing only the key-value pairs for which the
  /// [predicate] function returns `false`.
  ///
  /// This operation leverages transient mutation internally for efficiency.
  /// The resulting map is immutable.
  @override
  ApexMap<K, V> removeWhere(bool Function(K key, V value) predicate) {
    if (isEmpty) return this;

    // Use transient building for efficiency
    final owner = champ.TransientOwner();
    // Get a mutable version of the current root node
    champ.ChampNode<K, V> mutableRoot;
    if (_root is champ.ChampBitmapNode<K, V>) {
      mutableRoot = _root.ensureMutable(owner);
    } else if (_root is champ.ChampCollisionNode<K, V>) {
      mutableRoot = _root.ensureMutable(owner);
    } else {
      // Empty and Data nodes are immutable, start transient op from them
      mutableRoot = _root;
    }

    int removalCount = 0;
    // Need to collect keys to remove first, as modifying during iteration is problematic
    final keysToRemove = <K>[];
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      // Iterate original entries using direct key/value
      if (predicate(iter.currentKey, iter.currentValue)) {
        keysToRemove.add(iter.currentKey);
      }
    }

    if (keysToRemove.isEmpty) {
      // No elements matched the predicate, return the original instance.
      // Even if ensureMutable created a copy, no logical change occurred.
      return this;
    }

    // Perform removals on the mutable root
    for (final key in keysToRemove) {
      final removeResult = mutableRoot.remove(key, key.hashCode, 0, owner);
      // Update reference ONLY IF the node identity changes
      if (!identical(mutableRoot, removeResult.node)) {
        mutableRoot = removeResult.node;
      }
      if (removeResult.didRemove) {
        removalCount++;
      }
    }

    // Freeze the final potentially mutable root node
    final frozenRoot = mutableRoot.freeze(owner);

    // If all elements were removed, return a new empty instance via factory
    final newCount = _length - removalCount;
    if (newCount == 0) {
      return ApexMap<K, V>.empty();
    }

    // Return new instance with the frozen root and updated count
    return ApexMapImpl._(frozenRoot, newCount);
  }

  // --- Equality and HashCode ---

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is ApexMap<K, V>) {
      // Check specific type first
      if (length != other.length) return false;
      if (isEmpty) return true; // Both empty and same length

      // Compare content (original logic)
      // TODO: Optimize equality check using tree comparison if possible.
      // Current implementation iterates and checks key/value pairs.
      final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
      while (iter.moveNext()) {
        final key = iter.currentKey;
        final value = iter.currentValue;
        // Use other[key] which should be efficient (O(logN))
        // Need to handle the case where the key exists but value is null in 'other'
        if (!other.containsKey(key)) return false;
        if (other[key] != value) return false;
      }
      return true; // All entries matched
    }
    // If not identical and not an ApexMap<K, V> with same content, return false
    return false;
  }

  @override
  int get hashCode {
    // Return cached hash code if available
    if (_cachedHashCode != null) return _cachedHashCode!;

    // Compute hash code if not cached
    // Based on the standard Jenkins hash combination used in MapEquality/Objects.hash
    // Needs to be order-independent, so XOR hash codes of entries.
    if (isEmpty) {
      _cachedHashCode = 0; // Consistent hash for empty
      return _cachedHashCode!;
    }

    int result = 0;
    final iter = iterator as ChampTrieIterator<K, V>; // Cast iterator
    while (iter.moveNext()) {
      // Combine key and value hash codes for the entry's hash
      int entryHash = iter.currentKey.hashCode ^ iter.currentValue.hashCode;
      result = result ^ entryHash; // XOR combine entry hashes (order-independent)
    }
    // Apply final avalanche step (similar to Objects.hash)
    result = 0x1fffffff & (result + ((0x03ffffff & result) << 3));
    result = result ^ (result >> 11);
    result = 0x1fffffff & (result + ((0x00003fff & result) << 15));

    // Cache and return the computed hash code
    _cachedHashCode = result;
    return _cachedHashCode!;
  }
} // <<< Closing brace for ApexMapImpl

// *** REMOVED _ChampTrieIterator CLASS DEFINITION ***
