/// Defines the concrete implementation [ApexMapImpl] class structure.
library;

import '../map/apex_map_api.dart';
import 'champ_node_base.dart' as champ;
import 'champ_empty_node.dart';
import 'champ_data_node.dart';
import 'champ_collision_node.dart';
import 'champ_sparse_node.dart';
import 'champ_array_node_impl.dart';
import 'champ_utils.dart' as champ_utils;

/// Concrete implementation of [ApexMap] using a CHAMP Trie.
/// Method implementations are provided via extensions in separate files.
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

  // --- Method implementations provided by extensions ---
  // Add stubs or leave abstract methods from ApexMap?
  // Adding stubs for now to make this class concrete.
  @override
  Iterable<K> get keys => throw UnimplementedError('Implemented by extension');
  @override
  Iterable<V> get values =>
      throw UnimplementedError('Implemented by extension');
  @override
  Iterable<MapEntry<K, V>> get entries => this; // 'this' is the iterable
  @override
  V? operator [](K key) => throw UnimplementedError('Implemented by extension');
  @override
  bool containsKey(K key) =>
      throw UnimplementedError('Implemented by extension');
  @override
  bool containsValue(V value) =>
      throw UnimplementedError('Implemented by extension');
  @override
  ApexMap<K, V> add(K key, V value) =>
      throw UnimplementedError('Implemented by extension');
  @override
  ApexMap<K, V> addAll(Map<K, V> other) =>
      throw UnimplementedError('Implemented by extension');
  @override
  ApexMap<K, V> remove(K key) =>
      throw UnimplementedError('Implemented by extension');
  @override
  ApexMap<K, V> update(
    K key,
    V Function(V value) update, {
    V Function()? ifAbsent,
  }) => throw UnimplementedError('Implemented by extension');
  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) update) =>
      throw UnimplementedError('Implemented by extension');
  @override
  V putIfAbsent(K key, V Function() ifAbsent) =>
      throw UnimplementedError('Implemented by extension');
  @override
  Iterator<MapEntry<K, V>> get iterator =>
      throw UnimplementedError('Implemented by extension');
  @override
  ApexMap<K, V> removeWhere(bool Function(K key, V value) predicate) =>
      throw UnimplementedError('Implemented by extension');
  @override
  ApexMap<K, V> clear() => throw UnimplementedError('Implemented by extension');
  @override
  Map<K, V> toMap() => throw UnimplementedError('Implemented by extension');
  @override
  void forEachEntry(void Function(K key, V value) f) =>
      throw UnimplementedError('Implemented by extension');
  @override
  ApexMap<K2, V2> mapEntries<K2, V2>(
    MapEntry<K2, V2> Function(K key, V value) convert,
  ) => throw UnimplementedError('Implemented by extension');

  // Equality and HashCode (Placeholder - will be implemented by extension)
  @override
  int get hashCode {
    if (_cachedHashCode != null) return _cachedHashCode!;
    _cachedHashCode = isEmpty ? 0 : 1;
    return _cachedHashCode!;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return false;
  }

  // Add stubs for remaining Iterable methods
  @override
  bool any(bool Function(MapEntry<K, V> element) test) =>
      throw UnimplementedError('Implemented by extension');
  @override
  Iterable<T> cast<T>() => throw UnimplementedError('Implemented by extension');
  @override
  bool contains(Object? element) =>
      throw UnimplementedError('Implemented by extension');
  @override
  MapEntry<K, V> elementAt(int index) =>
      throw UnimplementedError('Implemented by extension');
  @override
  bool every(bool Function(MapEntry<K, V> element) test) =>
      throw UnimplementedError('Implemented by extension');
  @override
  Iterable<T> expand<T>(
    Iterable<T> Function(MapEntry<K, V> element) toElements,
  ) => throw UnimplementedError('Implemented by extension');
  @override
  MapEntry<K, V> get first =>
      throw UnimplementedError('Implemented by extension');
  @override
  MapEntry<K, V> firstWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => throw UnimplementedError('Implemented by extension');
  @override
  T fold<T>(
    T initialValue,
    T Function(T previousValue, MapEntry<K, V> element) combine,
  ) => throw UnimplementedError('Implemented by extension');
  @override
  Iterable<MapEntry<K, V>> followedBy(Iterable<MapEntry<K, V>> other) =>
      throw UnimplementedError('Implemented by extension');
  @override
  void forEach(void Function(MapEntry<K, V> element) action) =>
      throw UnimplementedError('Implemented by extension');
  @override
  String join([String separator = '']) =>
      throw UnimplementedError('Implemented by extension');
  @override
  MapEntry<K, V> get last =>
      throw UnimplementedError('Implemented by extension');
  @override
  MapEntry<K, V> lastWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => throw UnimplementedError('Implemented by extension');
  @override
  Iterable<T> map<T>(T Function(MapEntry<K, V> e) convert) =>
      throw UnimplementedError('Implemented by extension');
  @override
  MapEntry<K, V> reduce(
    MapEntry<K, V> Function(MapEntry<K, V> value, MapEntry<K, V> element)
    combine,
  ) => throw UnimplementedError('Implemented by extension');
  @override
  MapEntry<K, V> get single =>
      throw UnimplementedError('Implemented by extension');
  @override
  MapEntry<K, V> singleWhere(
    bool Function(MapEntry<K, V> element) test, {
    MapEntry<K, V> Function()? orElse,
  }) => throw UnimplementedError('Implemented by extension');
  @override
  Iterable<MapEntry<K, V>> skip(int count) =>
      throw UnimplementedError('Implemented by extension');
  @override
  Iterable<MapEntry<K, V>> skipWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => throw UnimplementedError('Implemented by extension');
  @override
  Iterable<MapEntry<K, V>> take(int count) =>
      throw UnimplementedError('Implemented by extension');
  @override
  Iterable<MapEntry<K, V>> takeWhile(
    bool Function(MapEntry<K, V> value) test,
  ) => throw UnimplementedError('Implemented by extension');
  @override
  List<MapEntry<K, V>> toList({bool growable = true}) =>
      throw UnimplementedError('Implemented by extension');
  @override
  Set<MapEntry<K, V>> toSet() =>
      throw UnimplementedError('Implemented by extension');
  @override
  Iterable<MapEntry<K, V>> where(bool Function(MapEntry<K, V> element) test) =>
      throw UnimplementedError('Implemented by extension');
  @override
  Iterable<T> whereType<T>() =>
      throw UnimplementedError('Implemented by extension');
} // End of ApexMapImpl
