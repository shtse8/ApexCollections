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
  // TODO: Consider caching hashCode

  /// The canonical empty instance (internal).
  static final ApexMapImpl _emptyInstance = ApexMapImpl._(
    champ.ChampEmptyNode.instance(),
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
  // Delegates to the efficient entries iterator
  Iterable<K> get keys => entries.map((e) => e.key);

  @override
  // Delegates to the efficient entries iterator
  Iterable<V> get values => entries.map((e) => e.value);

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
    // Assume _root.add returns an object like:
    // class ChampAddResult<K, V> { final ChampNode<K, V> node; final bool didAdd; ... }
    final addResult = _root.add(key, value, key.hashCode, 0);

    // If the node itself didn't change, return the original map.
    if (identical(addResult.node, _root)) return this;

    // Calculate the new length based on whether an actual insertion occurred.
    final newLength = addResult.didAdd ? _length + 1 : _length;

    return ApexMapImpl._(addResult.node, newLength);
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
    // Assume _root.remove returns an object like:
    // class ChampRemoveResult<K, V> { final ChampNode<K, V> node; final bool didRemove; ... }
    final removeResult = _root.remove(key, key.hashCode, 0);

    // If the node itself didn't change, return the original map.
    if (identical(removeResult.node, _root)) return this;

    // Calculate the new length based on whether a removal actually occurred.
    final newLength = removeResult.didRemove ? _length - 1 : _length;

    // Ensure length doesn't go negative (shouldn't happen if didRemove is correct)
    assert(newLength >= 0);

    return ApexMapImpl._(removeResult.node, newLength);
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
    // Uses the efficient iterator implicitly via 'entries'
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
  static const collection.MapEquality _equality = collection.MapEquality();

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
              (1 << champ.kBranchingFactor); // Use imported constant
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
            continue; // Use continue to restart the while loop with the new node
          }
        }
        // If we finish iterating through all bit positions for this node, pop it.
        _nodeStack.removeLast();
        _bitposStack.removeLast();
      }
    }

    // Stack is empty, iteration complete
    _currentEntry = null; // Invalidate current
    return false;
  }
}
