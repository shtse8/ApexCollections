import 'package:collection/collection.dart'
    as collection; // For equality, mixins, bitCount
import 'apex_map_api.dart';
import 'champ_node.dart' as champ; // Use prefix for clarity and constants
import 'champ_iterator.dart'; // Import the extracted iterator

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
  /// Uses an efficient O(N) bulk loading algorithm (`_buildNode`) that leverages
  /// transient mutation internally for performance. The resulting map is fully immutable.
  /// If the input [map] is empty, the canonical empty instance is returned.
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
    int dataPayloadIndex = 0; // Tracks current index for data [k, v, k, v...]
    int nodeContentIndex =
        dataCount * 2; // Tracks current index for nodes [...]

    for (int frag = 0; frag < partitions.length; frag++) {
      final partition = partitions[frag];
      if (partition.isEmpty) continue;

      final bitpos = 1 << frag;
      if ((dataMap & bitpos) != 0) {
        // Single entry -> Place directly into data section
        final entry = partition.first;
        finalContent[dataPayloadIndex++] = entry.key;
        finalContent[dataPayloadIndex++] = entry.value;
      } else {
        // Multiple entries -> Recursively build sub-node and place in node section
        final subNode = _buildNode(
          partition,
          shift + champ.kBitPartitionSize,
          owner,
        );
        finalContent[nodeContentIndex++] = subNode;
      }
    }

    // 4. Create and return the transient internal node
    return champ.ChampInternalNode<K, V>(
      dataMap,
      nodeMap,
      finalContent, // Pass the directly populated list
      owner, // Pass owner for transient creation
    );
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
    for (final entry in entries) {
      // Uses efficient iterator
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
  /// especially when adding multiple entries. The resulting map is immutable.
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
    if (_root is champ.ChampInternalNode<K, V>) {
      mutableRoot = (_root as champ.ChampInternalNode<K, V>).ensureMutable(
        owner,
      );
    } else if (_root is champ.ChampCollisionNode<K, V>) {
      mutableRoot = (_root as champ.ChampCollisionNode<K, V>).ensureMutable(
        owner,
      );
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
    V Function()? ifAbsent,
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
  /// The resulting map is immutable.
  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) updateFn) {
    if (isEmpty) return this;

    // Use transient building for efficiency
    final owner = champ.TransientOwner();
    // Get a mutable version of the current root node
    champ.ChampNode<K, V> mutableRoot;
    if (_root is champ.ChampInternalNode<K, V>) {
      mutableRoot = (_root as champ.ChampInternalNode<K, V>).ensureMutable(
        owner,
      );
    } else if (_root is champ.ChampCollisionNode<K, V>) {
      mutableRoot = (_root as champ.ChampCollisionNode<K, V>).ensureMutable(
        owner,
      );
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
  Iterator<MapEntry<K, V>> get iterator => ChampTrieIterator<K, V>(_root);

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
  MapEntry<K, V> get first {
    // Use iterator directly to avoid recursion with entries getter
    final iter = iterator;
    if (!iter.moveNext()) {
      throw StateError("Cannot get first element of an empty map");
    }
    return iter.current;
  }

  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => entries.firstWhere(test, orElse: orElse); // Delegate
  @override
  T fold<T>(
    T initialValue,
    T Function(T previousValue, MapEntry<K, V> element) combine,
  ) {
    // Explicit implementation using iterator
    var value = initialValue;
    final iter = iterator;
    while (iter.moveNext()) {
      value = combine(value, iter.current);
    }
    return value;
  }

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
  Iterable<T> map<T>(T Function(MapEntry<K, V> e) convert) sync* {
    // Explicit implementation using iterator
    final iter = iterator;
    while (iter.moveNext()) {
      yield convert(iter.current);
    }
  }

  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) {
    // Explicit implementation using iterator
    final iter = iterator;
    if (!iter.moveNext()) {
      throw StateError("Cannot reduce empty collection");
    }
    var value = iter.current;
    while (iter.moveNext()) {
      value = combine(value, iter.current);
    }
    return value;
  }

  @override
  MapEntry<K, V> get single => entries.single; // Delegate
  @override
  MapEntry<K, V> singleWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => entries.singleWhere(test, orElse: orElse); // Delegate
  @override
  Iterable<MapEntry<K, V>> skip(int count) sync* {
    // Explicit implementation using iterator
    final iter = iterator;
    int skipped = 0;
    while (iter.moveNext()) {
      if (skipped < count) {
        skipped++;
      } else {
        yield iter.current;
      }
    }
  }

  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => entries.skipWhile(test); // Delegate
  @override
  Iterable<MapEntry<K, V>> take(int count) sync* {
    // Explicit implementation using iterator
    if (count <= 0) return;
    final iter = iterator;
    int taken = 0;
    while (iter.moveNext() && taken < count) {
      yield iter.current;
      taken++;
    }
  }

  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => entries.takeWhile(test); // Delegate
  @override
  List<MapEntry<K, V>> toList({bool growable = true}) {
    // Explicit implementation using iterator
    final list = <MapEntry<K, V>>[];
    final iter = iterator; // Uses updated getter
    while (iter.moveNext()) {
      list.add(iter.current);
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
    final iter = iterator; // Uses updated getter
    while (iter.moveNext()) {
      set.add(iter.current);
    }
    return set;
  }

  @override
  Iterable<MapEntry<K, V>> where(
    bool Function(MapEntry<K, V> element) test,
  ) sync* {
    // Explicit implementation using iterator
    final iter = iterator; // Uses updated getter
    while (iter.moveNext()) {
      if (test(iter.current)) {
        yield iter.current;
      }
    }
  }

  @override
  Iterable<T> whereType<T>() sync* {
    // Explicit implementation using iterator
    final iter = iterator; // Uses updated getter
    while (iter.moveNext()) {
      // Need to check the type of the entry itself, not just yield
      final current = iter.current;
      if (current is T) {
        yield current as T; // Add cast
      }
    }
  }

  @override
  Map<K, V> toMap() {
    // Create a standard mutable map
    final map = <K, V>{};
    // Use the efficient iterator
    final iter = iterator; // Uses updated getter
    while (iter.moveNext()) {
      map[iter.current.key] = iter.current.value;
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
    for (final entry in entries) {
      f(entry.key, entry.value);
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

    for (final entry in entries) {
      // Iterate original entries
      final newEntry = convert(entry.key, entry.value);
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
    if (_root is champ.ChampInternalNode<K, V>) {
      mutableRoot = (_root as champ.ChampInternalNode<K, V>).ensureMutable(
        owner,
      );
    } else if (_root is champ.ChampCollisionNode<K, V>) {
      mutableRoot = (_root as champ.ChampCollisionNode<K, V>).ensureMutable(
        owner,
      );
    } else {
      // Empty and Data nodes are immutable, start transient op from them
      mutableRoot = _root;
    }

    int removalCount = 0;
    // Need to collect keys to remove first, as modifying during iteration is problematic
    final keysToRemove = <K>[];
    for (final entry in entries) {
      // Iterate original entries
      if (predicate(entry.key, entry.value)) {
        keysToRemove.add(entry.key);
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
      try {
        // TODO: Optimize equality check using tree comparison if possible.
        for (final entry in entries) {
          // Uses efficient iterator
          // Use other[key] which should be efficient (O(logN))
          if (!other.containsKey(entry.key) ||
              other[entry.key] != entry.value) {
            return false;
          }
        }
        return true; // All entries matched
      } catch (_) {
        return false; // Error during comparison
      }
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
    for (final entry in entries) {
      // Uses efficient iterator
      // Combine key and value hash codes for the entry's hash
      int entryHash = entry.key.hashCode ^ entry.value.hashCode;
      result =
          result ^ entryHash; // XOR combine entry hashes (order-independent)
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
