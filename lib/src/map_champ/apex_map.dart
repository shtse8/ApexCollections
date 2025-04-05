/// Defines the concrete implementation [ApexMapImpl] using a CHAMP Trie.
library;

import 'dart:math'; // For Random (potentially needed by Iterable methods like shuffle)
import 'package:collection/collection.dart'; // For ListEquality
import '../map/apex_map_api.dart';
import 'champ_node_base.dart' as champ;
import 'champ_empty_node.dart';
import 'champ_data_node.dart';
import 'champ_collision_node.dart';
import 'champ_sparse_node.dart';
import 'champ_array_node_impl.dart';
import 'champ_utils.dart' as champ_utils;
import 'champ_iterator.dart';
import 'champ_merging.dart';
import 'champ_bitmap_node.dart';

/// Concrete implementation of [ApexMap] using a CHAMP Trie.
class ApexMapImpl<K, V> extends ApexMap<K, V> {
  final champ.ChampNode<K, V> _root;
  final int _length;
  int? _cachedHashCode;

  static final ApexMapImpl<Never, Never> _emptyInstance = ApexMapImpl._(
    ChampEmptyNode(),
    0,
  );

  static ApexMapImpl<K, V> emptyInstance<K, V>() {
    if (K == Never && V == Never) {
      return _emptyInstance as ApexMapImpl<K, V>;
    }
    return ApexMapImpl._(ChampEmptyNode(), 0);
  }

  /// Internal constructor.
  ApexMapImpl._(this._root, this._length) : _cachedHashCode = null;

  /// Internal getter for debugging/testing purposes.
  champ.ChampNode<K, V>? get debugRoot => _root;

  // --- Factory Constructor ---
  factory ApexMapImpl.fromMap(Map<K, V> map) {
    if (map.isEmpty) {
      return emptyInstance<K, V>();
    }
    final entries = map.entries.toList();
    final owner = champ_utils.TransientOwner();
    final rootNode = _buildNode(entries, 0, owner);
    final frozenRoot = rootNode.freeze(owner);
    return ApexMapImpl._(frozenRoot, map.length);
  }

  // --- Bulk Loading Helper ---
  static champ.ChampNode<K, V> _buildNode<K, V>(
    List<MapEntry<K, V>> entries,
    int shift,
    champ_utils.TransientOwner owner,
  ) {
    if (entries.isEmpty) {
      return ChampEmptyNode<K, V>();
    }
    if (entries.length == 1) {
      final entry = entries.first;
      return ChampDataNode<K, V>(entry.key.hashCode, entry.key, entry.value);
    }
    final firstHash = entries.first.key.hashCode;
    bool allSameHash = true;
    for (int i = 1; i < entries.length; i++) {
      if (entries[i].key.hashCode != firstHash) {
        allSameHash = false;
        break;
      }
    }
    if (allSameHash &&
        shift >= champ_utils.kMaxDepth * champ_utils.kBitPartitionSize) {
      return ChampCollisionNode<K, V>(firstHash, entries, owner);
    }
    final List<List<MapEntry<K, V>>> partitions = List.generate(
      1 << champ_utils.kBitPartitionSize,
      (_) => [],
      growable: false,
    );
    int dataMap = 0;
    int nodeMap = 0;
    for (final entry in entries) {
      final frag = champ_utils.indexFragment(shift, entry.key.hashCode);
      partitions[frag].add(entry);
    }
    for (int i = 0; i < partitions.length; i++) {
      final partitionLength = partitions[i].length;
      if (partitionLength == 1) {
        dataMap |= (1 << i);
      } else if (partitionLength > 1) {
        nodeMap |= (1 << i);
      }
    }
    final dataCount = champ_utils.bitCount(dataMap);
    final nodeCount = champ_utils.bitCount(nodeMap);
    final contentSize = (dataCount * 2) + nodeCount;
    final List<Object?> finalContent = List.filled(
      contentSize,
      null,
      growable: true,
    );
    int currentDataIndex = 0;
    int currentNodeIndex = 0;
    for (int frag = 0; frag < partitions.length; frag++) {
      final bitpos = 1 << frag;
      if ((dataMap & bitpos) != 0) {
        final payloadIndex = currentDataIndex * 2;
        final entry = partitions[frag].first;
        finalContent[payloadIndex] = entry.key;
        finalContent[payloadIndex + 1] = entry.value;
        currentDataIndex++;
      } else if ((nodeMap & bitpos) != 0) {
        final actualNodeIndex = finalContent.length - 1 - currentNodeIndex;
        final partition = partitions[frag];
        final subNode = _buildNode(
          partition,
          shift + champ_utils.kBitPartitionSize,
          owner,
        );
        finalContent[actualNodeIndex] = subNode;
        currentNodeIndex++;
      }
    }
    assert(currentDataIndex == dataCount);
    assert(currentNodeIndex == nodeCount);
    final childCount = dataCount + nodeCount;
    if (childCount <= champ_utils.kSparseNodeThreshold) {
      return ChampSparseNode<K, V>(dataMap, nodeMap, finalContent, owner);
    } else {
      return ChampArrayNodeImpl<K, V>(dataMap, nodeMap, finalContent, owner);
    }
  }

  // --- Core Properties ---
  @override
  int get length => _length;
  @override
  bool get isEmpty => _length == 0;
  @override
  bool get isNotEmpty => _length > 0;

  // --- Accessors ---
  @override
  Iterable<K> get keys sync* {
    final iterator = ChampTrieIterator<K, V>(_root);
    while (iterator.moveNext()) {
      yield iterator.current.key;
    }
  }

  @override
  Iterable<V> get values sync* {
    final iterator = ChampTrieIterator<K, V>(_root);
    while (iterator.moveNext()) {
      yield iterator.current.value;
    }
  }

  @override
  Iterable<MapEntry<K, V>> get entries => this;
  @override
  V? operator [](K key) {
    if (isEmpty) return null;
    return _root.get(key, key.hashCode, 0);
  }

  @override
  bool containsKey(K key) {
    if (isEmpty) return false;
    return _root.containsKey(key, key.hashCode, 0);
  }

  @override
  bool containsValue(V value) {
    if (isEmpty) return false;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      if (iter.currentValue == value) {
        return true;
      }
    }
    return false;
  }

  // --- Modifiers ---
  @override
  ApexMap<K, V> add(K key, V value) {
    if (identical(_root, ChampEmptyNode())) {
      final newNode = ChampDataNode<K, V>(key.hashCode, key, value);
      return ApexMapImpl._(newNode, 1);
    }
    final addResult = _root.add(key, value, key.hashCode, 0, null);
    if (!addResult.didAdd && identical(addResult.node, _root)) {
      return this;
    }
    final newLength = _length + (addResult.didAdd ? 1 : 0);
    return ApexMapImpl._(addResult.node, newLength);
  }

  @override
  ApexMap<K, V> addAll(Map<K, V> other) {
    if (other.isEmpty) return this;
    if (isEmpty) {
      return ApexMapImpl.fromMap(other);
    }
    final owner = champ_utils.TransientOwner();
    champ.ChampNode<K, V> mutableRoot;
    if (_root is ChampBitmapNode<K, V>) {
      mutableRoot = (_root as ChampBitmapNode<K, V>).ensureMutable(owner);
    } else if (_root is ChampCollisionNode<K, V>) {
      mutableRoot = (_root as ChampCollisionNode<K, V>).ensureMutable(owner);
    } else {
      mutableRoot = _root;
    }
    int additions = 0;
    other.forEach((key, value) {
      final result = mutableRoot.add(key, value, key.hashCode, 0, owner);
      if (!identical(mutableRoot, result.node)) {
        mutableRoot = result.node;
      }
      if (result.didAdd) {
        additions++;
      }
    });
    if (additions == 0 && identical(mutableRoot, _root)) {
      return this;
    }
    final frozenRoot = mutableRoot.freeze(owner);
    final newCount = _length + additions;
    return ApexMapImpl._(frozenRoot, newCount);
  }

  @override
  ApexMap<K, V> remove(K key) {
    if (isEmpty) return this;
    final removeResult = _root.remove(key, key.hashCode, 0, null);
    if (identical(removeResult.node, _root)) return this;
    final newLength = removeResult.didRemove ? _length - 1 : _length;
    assert(newLength >= 0);
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
      if (ifAbsent != null) {
        final newValue = ifAbsent();
        final newNode = ChampDataNode<K, V>(key.hashCode, key, newValue);
        updateResult = (node: newNode, sizeChanged: true);
      } else {
        return emptyInstance<K, V>();
      }
    } else {
      updateResult = _root.update(
        key,
        key.hashCode,
        0,
        updateFn,
        ifAbsentFn: ifAbsent,
        owner: null,
      );
    }
    if (identical(updateResult.node, _root)) {
      return this;
    }
    final newLength = updateResult.sizeChanged ? _length + 1 : _length;
    if (updateResult.node.isEmptyNode) {
      return emptyInstance<K, V>();
    }
    return ApexMapImpl._(updateResult.node, newLength);
  }

  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) updateFn) {
    if (isEmpty) return this;
    final owner = champ_utils.TransientOwner();
    champ.ChampNode<K, V> mutableRoot;
    if (_root is ChampBitmapNode<K, V>) {
      mutableRoot = (_root as ChampBitmapNode<K, V>).ensureMutable(owner);
    } else if (_root is ChampCollisionNode<K, V>) {
      mutableRoot = (_root as ChampCollisionNode<K, V>).ensureMutable(owner);
    } else {
      mutableRoot = _root;
    }
    bool changed = false;
    for (final entry in entries) {
      final key = entry.key;
      final currentValue = entry.value;
      final newValue = updateFn(key, currentValue);
      if (!identical(newValue, currentValue)) {
        final updateResult = mutableRoot.update(
          key,
          key.hashCode,
          0,
          (_) => newValue,
          owner: owner,
        );
        if (!identical(mutableRoot, updateResult.node)) {
          mutableRoot = updateResult.node;
        }
        changed = true;
      }
    }
    if (!changed) {
      if (identical(mutableRoot, _root)) return this;
      final frozenRoot = mutableRoot.freeze(owner);
      return ApexMapImpl._(frozenRoot, _length);
    }
    final frozenRoot = mutableRoot.freeze(owner);
    return ApexMapImpl._(frozenRoot, _length);
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    final existing = this[key];
    if (existing != null) {
      return existing;
    }
    return ifAbsent();
  }

  @override
  ApexMap<K, V> clear() {
    return emptyInstance<K, V>();
  }

  @override
  ApexMap<K, V> removeWhere(bool Function(K key, V value) predicate) {
    if (isEmpty) return this;
    final owner = champ_utils.TransientOwner();
    champ.ChampNode<K, V> mutableRoot;
    if (_root is ChampBitmapNode<K, V>) {
      mutableRoot = (_root as ChampBitmapNode<K, V>).ensureMutable(owner);
    } else if (_root is ChampCollisionNode<K, V>) {
      mutableRoot = (_root as ChampCollisionNode<K, V>).ensureMutable(owner);
    } else {
      mutableRoot = _root;
    }
    int removalCount = 0;
    final keysToRemove = <K>[];
    for (final entry in entries) {
      if (predicate(entry.key, entry.value)) {
        keysToRemove.add(entry.key);
      }
    }
    if (keysToRemove.isEmpty) {
      return this;
    }
    for (final key in keysToRemove) {
      final removeResult = mutableRoot.remove(key, key.hashCode, 0, owner);
      if (!identical(mutableRoot, removeResult.node)) {
        mutableRoot = removeResult.node;
      }
      if (removeResult.didRemove) {
        removalCount++;
      }
    }
    final frozenRoot = mutableRoot.freeze(owner);
    final newCount = _length - removalCount;
    if (newCount == 0) {
      return emptyInstance<K, V>();
    }
    return ApexMapImpl._(frozenRoot, newCount);
  }

  // --- Iterable<MapEntry<K, V>> implementations ---
  @override
  Iterator<MapEntry<K, V>> get iterator => ChampTrieIterator<K, V>(_root);
  @override
  bool any(bool Function(MapEntry<K, V> element) test) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      if (test(MapEntry(iter.currentKey, iter.currentValue))) return true;
    }
    return false;
  }

  @override
  Iterable<T> cast<T>() => entries.cast<T>();
  @override
  bool contains(Object? element) {
    if (element is! MapEntry<K, V>) return false;
    if (!containsKey(element.key)) return false;
    final internalValue = this[element.key];
    return internalValue == element.value;
  }

  @override
  MapEntry<K, V> elementAt(int index) {
    RangeError.checkValidIndex(index, this);
    int count = 0;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      if (count == index) {
        return MapEntry(iter.currentKey, iter.currentValue);
      }
      count++;
    }
    throw StateError('Internal error: Index out of bounds after check');
  }

  @override
  bool every(bool Function(MapEntry<K, V> element) test) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      if (!test(MapEntry(iter.currentKey, iter.currentValue))) return false;
    }
    return true;
  }

  @override
  Iterable<T> expand<T>(
    Iterable<T> Function(MapEntry<K, V> element) toElements,
  ) => entries.expand(toElements);
  @override
  MapEntry<K, V> get first {
    final iter = iterator as ChampTrieIterator<K, V>;
    if (!iter.moveNext()) {
      throw StateError("Cannot get first element of an empty map");
    }
    return MapEntry(iter.currentKey, iter.currentValue);
  }

  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
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
    var value = initialValue;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      value = combine(value, MapEntry(iter.currentKey, iter.currentValue));
    }
    return value;
  }

  @override
  Iterable<MapEntry<K, V>> followedBy(Iterable<MapEntry<K, V>> other) =>
      entries.followedBy(other);
  @override
  void forEach(void Function(MapEntry<K, V> element) action) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      action(MapEntry(iter.currentKey, iter.currentValue));
    }
  }

  @override
  String join([String separator = '']) {
    return toList(growable: false).join(separator);
  }

  @override
  MapEntry<K, V> get last {
    final iter = iterator as ChampTrieIterator<K, V>;
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
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
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
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      yield convert(MapEntry(iter.currentKey, iter.currentValue));
    }
  }

  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) {
    final iter = iterator as ChampTrieIterator<K, V>;
    if (!iter.moveNext()) {
      throw StateError("Cannot reduce empty collection");
    }
    var value = MapEntry(iter.currentKey, iter.currentValue);
    while (iter.moveNext()) {
      value = combine(value, MapEntry(iter.currentKey, iter.currentValue));
    }
    return value;
  }

  @override
  MapEntry<K, V> get single {
    final iter = iterator as ChampTrieIterator<K, V>;
    if (!iter.moveNext())
      throw StateError("Cannot get single element of an empty map");
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
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (test(entry)) {
        if (foundEntry != null)
          throw StateError("Multiple elements match test");
        foundEntry = entry;
      }
    }
    if (foundEntry != null) return foundEntry;
    if (orElse != null) return orElse();
    throw StateError("No element matching test found");
  }

  @override
  Iterable<MapEntry<K, V>> skip(int count) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    int skipped = 0;
    while (iter.moveNext()) {
      if (skipped < count) {
        skipped++;
      } else {
        yield MapEntry(iter.currentKey, iter.currentValue);
      }
    }
  }

  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    bool skipping = true;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
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
    if (count <= 0) return;
    final iter = iterator as ChampTrieIterator<K, V>;
    int taken = 0;
    while (iter.moveNext() && taken < count) {
      yield MapEntry(iter.currentKey, iter.currentValue);
      taken++;
    }
  }

  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (test(entry)) {
        yield entry;
      } else {
        break;
      }
    }
  }

  @override
  List<MapEntry<K, V>> toList({bool growable = true}) {
    final list = <MapEntry<K, V>>[];
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      list.add(MapEntry(iter.currentKey, iter.currentValue));
    }
    if (growable) {
      return list;
    } else {
      return List<MapEntry<K, V>>.of(list, growable: false);
    }
  }

  @override
  Set<MapEntry<K, V>> toSet() {
    final set = <MapEntry<K, V>>{};
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      set.add(MapEntry(iter.currentKey, iter.currentValue));
    }
    return set;
  }

  @override
  Iterable<MapEntry<K, V>> where(
    bool Function(MapEntry<K, V> element) test,
  ) sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final entry = MapEntry(iter.currentKey, iter.currentValue);
      if (test(entry)) {
        yield entry;
      }
    }
  }

  @override
  Iterable<T> whereType<T>() sync* {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final currentEntry = MapEntry(iter.currentKey, iter.currentValue);
      if (currentEntry is T) {
        yield currentEntry as T;
      }
    }
  }

  // --- Other Methods ---
  @override
  Map<K, V> toMap() {
    final map = <K, V>{};
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      map[iter.currentKey] = iter.currentValue;
    }
    return map;
  }

  @override
  void forEachEntry(void Function(K key, V value) f) {
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      f(iter.currentKey, iter.currentValue);
    }
  }

  @override
  ApexMap<K2, V2> mapEntries<K2, V2>(
    MapEntry<K2, V2> Function(K key, V value) convert,
  ) {
    if (isEmpty) return ApexMap<K2, V2>.empty();
    final owner = champ_utils.TransientOwner();
    champ.ChampNode<K2, V2>? mutableNewRoot;
    int newCount = 0;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      final newEntry = convert(iter.currentKey, iter.currentValue);
      final K2 newKey = newEntry.key;
      final V2 newValue = newEntry.value;
      final int newKeyHash = newKey.hashCode;
      if (mutableNewRoot == null) {
        mutableNewRoot = ChampDataNode<K2, V2>(newKeyHash, newKey, newValue);
        newCount = 1;
      } else {
        final result = mutableNewRoot.add(
          newKey,
          newValue,
          newKeyHash,
          0,
          owner,
        );
        mutableNewRoot = result.node;
        if (result.didAdd) {
          newCount++;
        }
      }
    }
    if (mutableNewRoot == null) {
      return ApexMap<K2, V2>.empty();
    }
    if (newCount == 0) return ApexMap<K2, V2>.empty();
    final frozenNewRoot = mutableNewRoot.freeze(owner);
    return ApexMapImpl<K2, V2>._(frozenNewRoot, newCount);
  }

  // Equality and HashCode (Moved back from base, using iterator)
  static const _equality = ListEquality(); // Keep for potential internal use

  @override
  int get hashCode {
    if (_cachedHashCode != null) return _cachedHashCode!;
    if (isEmpty) {
      _cachedHashCode = 0;
      return _cachedHashCode!;
    }
    int result = 0;
    final iter = iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      int entryHash = iter.currentKey.hashCode ^ iter.currentValue.hashCode;
      result = result ^ entryHash;
    }
    result = 0x1fffffff & (result + ((0x03ffffff & result) << 3));
    result = result ^ (result >> 11);
    result = 0x1fffffff & (result + ((0x00003fff & result) << 15));
    _cachedHashCode = result;
    return _cachedHashCode!;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is ApexMap<K, V>) {
      if (length != other.length) return false;
      if (isEmpty) return true;
      final iter = iterator as ChampTrieIterator<K, V>;
      while (iter.moveNext()) {
        final key = iter.currentKey;
        final value = iter.currentValue;
        // Use other.containsKey first for potentially faster check
        if (!other.containsKey(key)) return false;
        if (other[key] != value) return false;
      }
      return true;
    }
    return false;
  }
} // End of ApexMapImpl

// Removed _ApexMapImplInternal class definition
