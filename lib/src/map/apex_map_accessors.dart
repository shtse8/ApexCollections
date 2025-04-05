/// Defines accessor methods (getters, [], containsKey, containsValue) for [ApexMapImpl].
library;

import 'apex_map_impl.dart'; // Import the concrete implementation
import 'champ_iterator.dart'; // Import the iterator

/// Extension methods for accessing elements in ApexMapImpl.
extension ApexMapImplAccessors<K, V> on ApexMapImpl<K, V> {
  @override
  Iterable<K> get keys sync* {
    final iterator = ChampTrieIterator<K, V>(debugRoot!);
    while (iterator.moveNext()) {
      yield iterator.current.key;
    }
  }

  @override
  Iterable<V> get values sync* {
    final iterator = ChampTrieIterator<K, V>(debugRoot!);
    while (iterator.moveNext()) {
      yield iterator.current.value;
    }
  }

  @override
  Iterable<MapEntry<K, V>> get entries => this; // 'this' is already Iterable<MapEntry>

  @override
  V? operator [](K key) {
    if (isEmpty) return null;
    return debugRoot!.get(key, key.hashCode, 0);
  }

  @override
  bool containsKey(K key) {
    if (isEmpty) return false;
    return debugRoot!.containsKey(key, key.hashCode, 0);
  }

  @override
  bool containsValue(V value) {
    if (isEmpty) return false;
    // Cast needed because iterator() getter is on the base ApexMap
    final iter =
        (this as ApexMapImpl<K, V>).iterator as ChampTrieIterator<K, V>;
    while (iter.moveNext()) {
      if (iter.currentValue == value) {
        return true;
      }
    }
    return false;
  }
}
