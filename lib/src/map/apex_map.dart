import 'package:collection/collection.dart'
    as collection; // For equality, mixins, bitCount
import 'apex_map_api.dart';
import 'champ_node.dart' as champ; // Use prefix for clarity and constants

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
  static ApexMapImpl<K, V> emptyInstance<K, V>() =>
      _emptyInstance as ApexMapImpl<K, V>; // Cast the const instance

  /// Internal constructor. Cannot be const due to mutable _cachedHashCode.
  ApexMapImpl._(this._root, this._length) : _cachedHashCode = null;

  /// Factory constructor to create from a Map.
  factory ApexMapImpl.fromMap(Map<K, V> map) {
    if (map.isEmpty) {
      // Return the canonical empty instance via the getter
      return emptyInstance<K, V>();
    }
    // Use transient building for efficiency
    final owner = champ.TransientOwner();
    // Start with a null root, create the first node on the first iteration
    champ.ChampNode<K, V>? root;
    int count = 0;

    map.forEach((key, value) {
      if (root == null) {
        // First element: create the initial DataNode directly
        root = champ.ChampDataNode<K, V>(key.hashCode, key, value);
        count = 1; // Initialize count
      } else {
        // Subsequent elements: add to the existing root using transient owner
        final result = root!.add(key, value, key.hashCode, 0, owner);
        root = result.node; // Update root reference
        if (result.didAdd) {
          count++;
        }
      }
    });

    // If the map was empty after all, root will be null. Return canonical empty.
    if (root == null) {
      return emptyInstance<K, V>();
    }

    // Otherwise, root is non-null. Freeze the final potentially mutable root node.
    final frozenRoot = root!.freeze(
      owner,
    ); // Use null assertion '!' as root is guaranteed non-null here
    return ApexMapImpl._(frozenRoot, count);
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
    final iterator = _ChampTrieIterator<K, V>(_root);
    while (iterator.moveNext()) {
      yield iterator.current.key;
    }
  }

  @override
  // Use the efficient iterator directly
  Iterable<V> get values sync* {
    final iterator = _ChampTrieIterator<K, V>(_root);
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
    return this[key] != null; // Simple check, relies on efficient operator []
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
    final champ.ChampAddResult<K, V> addResult;
    // Handle adding to the logical empty map explicitly
    if (_root.isEmptyNode) {
      // DataNode creation doesn't need owner
      final newNode = champ.ChampDataNode<K, V>(key.hashCode, key, value);
      addResult = (node: newNode, didAdd: true);
    } else if (_root.isEmptyNode) {
      // Explicitly handle adding to logical empty map
      // Create the first data node directly
      final newNode = champ.ChampDataNode<K, V>(key.hashCode, key, value);
      addResult = (node: newNode, didAdd: true);
    } else {
      // Pass null owner for immutable operation on non-empty root
      addResult = _root.add(key, value, key.hashCode, 0, null);
    }

    // If the node itself didn't change, return the original map.
    if (identical(addResult.node, _root)) return this;

    // Calculate the new length based on whether an actual insertion occurred.
    final newLength = addResult.didAdd ? _length + 1 : _length;

    return ApexMapImpl._(addResult.node, newLength);
  }

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
  Iterator<MapEntry<K, V>> get iterator => _ChampTrieIterator<K, V>(_root);

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
  List<MapEntry<K, V>> toList({bool growable = true}) {
    // Explicit implementation using iterator
    final list = <MapEntry<K, V>>[];
    final iter = iterator;
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
    final iter = iterator;
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
    final iter = iterator;
    while (iter.moveNext()) {
      if (test(iter.current)) {
        yield iter.current;
      }
    }
  }

  @override
  Iterable<T> whereType<T>() sync* {
    // Explicit implementation using iterator
    final iter = iterator;
    while (iter.moveNext()) {
      // Need to check the type of the entry itself, not just yield
      final current = iter.current;
      if (current is T) {
        yield current as T; // Add cast
      }
    }
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
    champ.ChampNode<K2, V2> mutableNewRoot = champ.ChampEmptyNode<K2, V2>();
    int newCount = 0;
    // No need for 'changed' flag when building from scratch

    for (final entry in entries) {
      // Iterate original entries
      final newEntry = convert(entry.key, entry.value);
      final K2 newKey = newEntry.key;
      final V2 newValue = newEntry.value;
      final int newKeyHash = newKey.hashCode;

      // Add the new entry to the mutableNewRoot, passing the owner
      final result = mutableNewRoot.add(newKey, newValue, newKeyHash, 0, owner);

      // Update root reference (might be the same mutable node or a new one)
      mutableNewRoot = result.node;
      if (result.didAdd) {
        newCount++;
      }
      // Overwrites are handled correctly by add
    }

    // If the resulting map is empty, return the canonical empty instance.
    if (newCount == 0) return ApexMap<K2, V2>.empty();

    // If no structural changes occurred and the count is the same,
    // and if the types match, we could potentially return 'this'.
    // This is complex to check correctly, especially value equality after conversion.
    // Example check (use with caution):
    // if (!changed && newCount == _length && this is ApexMap<K2, V2>) {
    //   // Still need to verify values didn't change if structure is identical
    //   bool valuesChanged = false;
    //   try {
    //      final tempNewMap = ApexMapImpl<K2, V2>._(newRoot, newCount);
    //      for (final entry in entries) {
    //         final newEntryCheck = convert(entry.key, entry.value);
    //         if (tempNewMap[newEntryCheck.key] != newEntryCheck.value) {
    //            valuesChanged = true;
    //            break;
    //         }
    //      }
    //   } catch (_) { valuesChanged = true; } // Assume change on error
    //   if (!valuesChanged) return this as ApexMap<K2, V2>;
    // }
    // For simplicity and guaranteed correctness, we create the new instance if changed.
    // Freeze the final potentially mutable root node
    final frozenNewRoot = mutableNewRoot.freeze(owner);

    // Return the newly built map
    return ApexMapImpl<K2, V2>._(frozenNewRoot, newCount);
  }

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
      // If ensureMutable created a copy, freeze it before returning
      if (!identical(mutableRoot, _root)) {
        final frozenRoot = mutableRoot.freeze(owner);
        return ApexMapImpl._(frozenRoot, _length); // Length unchanged
      }
      return this; // No changes needed
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
    // Removed the old iterative logic replaced above
  }

  // --- Equality and HashCode ---

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is ApexMap<K, V>) {
      // Use 'is' for type check
      if (length != other.length) return false;
      if (isEmpty) return true; // Both empty and same length

      // TODO: Optimize equality check using tree comparison if possible.
      // Intermediate approach: Compare entries one by one.
      try {
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
        // If other map throws during lookup, consider them unequal
        return false;
      }
    }
    return false; // Not an ApexMap<K, V>
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

/// Efficient iterator for traversing the CHAMP Trie.
class _ChampTrieIterator<K, V> implements Iterator<MapEntry<K, V>> {
  // Stacks to manage the traversal state
  final List<champ.ChampNode<K, V>> _nodeStack = [];
  final List<int> _bitposStack =
      []; // Stores the next bit position (1 << i) to check
  final List<Iterator<MapEntry<K, V>>> _collisionIteratorStack =
      []; // For CollisionNodes

  MapEntry<K, V>? _currentEntry;

  _ChampTrieIterator(champ.ChampNode<K, V> rootNode) {
    if (!rootNode.isEmptyNode) {
      _pushNode(rootNode);
    }
  }

  void _pushNode(champ.ChampNode<K, V> node) {
    if (node is champ.ChampCollisionNode<K, V>) {
      _nodeStack.add(node);
      _bitposStack.add(0); // Not used for collision nodes
      _collisionIteratorStack.add(node.entries.iterator);
    } else if (node is champ.ChampInternalNode<K, V>) {
      _nodeStack.add(node);
      _bitposStack.add(1); // Start checking from the first bit position
    }
    // ChampEmptyNode is not pushed
  }

  @override
  MapEntry<K, V> get current {
    if (_currentEntry == null) {
      // Adhere to Iterator contract: throw if current is accessed before moveNext
      // or after moveNext returns false.
      throw StateError('No current element');
    }
    return _currentEntry!;
  }

  @override
  bool moveNext() {
    while (_nodeStack.isNotEmpty) {
      final node = _nodeStack.last;
      final bitpos = _bitposStack.last;

      if (node is champ.ChampCollisionNode<K, V>) {
        final iterator = _collisionIteratorStack.last;
        if (iterator.moveNext()) {
          _currentEntry = iterator.current;
          return true;
        } else {
          // Finished with this collision node
          _nodeStack.removeLast();
          _bitposStack.removeLast();
          _collisionIteratorStack.removeLast();
          continue; // Try the next node on the stack
        }
      }

      if (node is champ.ChampInternalNode<K, V>) {
        final dataMap = node.dataMap;
        final nodeMap = node.nodeMap;
        final content = node.content;

        // Resume checking bit positions from where we left off
        for (
          int currentBitpos = bitpos;
          currentBitpos <
              (1 << champ.kBitPartitionSize); // Use imported constant
          currentBitpos <<= 1
        ) {
          if ((dataMap & currentBitpos) != 0) {
            // Found a data entry
            final dataIndex = champ.bitCount(
              // Use bitCount from champ_node.dart
              dataMap & (currentBitpos - 1),
            );
            final payloadIndex = dataIndex * 2;
            final key = content[payloadIndex] as K;
            final value = content[payloadIndex + 1] as V;
            _currentEntry = MapEntry(key, value);
            // Update stack to resume after this bitpos on next call
            _bitposStack[_bitposStack.length - 1] = currentBitpos << 1;
            return true;
          }
          if ((nodeMap & currentBitpos) != 0) {
            // Found a sub-node, push it onto the stack and descend
            final nodeLocalIndex = champ.bitCount(
              // Use bitCount from champ_node.dart
              nodeMap & (currentBitpos - 1),
            );
            // Explicitly cast to int as a workaround for potential analyzer issue
            final nodeIndex = (content.length - 1 - nodeLocalIndex) as int;
            final subNode = content[nodeIndex] as champ.ChampNode<K, V>;

            // Update stack to resume after this bitpos in the current node later
            _bitposStack[_bitposStack.length - 1] = currentBitpos << 1;
            // Push the new sub-node to explore next
            _pushNode(subNode);
            // Restart the outer loop to process the newly pushed node
            // Use break instead of continue to avoid processing the same node again immediately
            break; // Exit inner for-loop, outer while-loop will process pushed node
          }
        }
        // If the inner loop completed without finding/pushing, pop the current node
        if (_nodeStack.isNotEmpty && _nodeStack.last == node) {
          // Check if a sub-node was pushed
          _nodeStack.removeLast();
          _bitposStack.removeLast();
        }
      } else {
        // Should not happen if root wasn't empty (ChampEmptyNode case handled in constructor)
        // Or if node was ChampDataNode (should not be pushed onto stack)
        _nodeStack.removeLast();
        _bitposStack.removeLast();
      }
    }

    // Stack is empty, iteration complete
    _currentEntry = null; // Invalidate current
    return false;
  }
}
