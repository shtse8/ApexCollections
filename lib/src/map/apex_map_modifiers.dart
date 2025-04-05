/// Defines modifier methods (add, addAll, remove, update, etc.) for [ApexMapImpl].
part of 'apex_map_impl.dart'; // Use part of directive

/// Extension methods for modifying ApexMapImpl instances.
/// Note: Since this is a 'part' file, these become instance methods of ApexMapImpl.
extension ApexMapImplModifiers<K, V> on ApexMapImpl<K, V> {
  @override
  ApexMap<K, V> add(K key, V value) {
    final champ.ChampNode<K, V> root = _root; // Access private member directly

    if (identical(root, ChampEmptyNode())) {
      final newNode = ChampDataNode<K, V>(key.hashCode, key, value);
      // Use the internal constructor directly as we are in the same library
      return ApexMapImpl._(newNode, 1);
    }

    final addResult = root.add(key, value, key.hashCode, 0, null);

    if (!addResult.didAdd && identical(addResult.node, root)) {
      return this;
    }

    final newLength =
        _length + (addResult.didAdd ? 1 : 0); // Access private member
    return ApexMapImpl._(addResult.node, newLength); // Use internal constructor
  }

  @override
  ApexMap<K, V> addAll(Map<K, V> other) {
    if (other.isEmpty) return this;
    if (isEmpty) {
      // Use the factory constructor defined in the main part file
      return ApexMapImpl.fromMap(other);
    }

    final owner = champ_utils.TransientOwner();
    champ.ChampNode<K, V> mutableRoot;
    final champ.ChampNode<K, V> root = _root; // Access private member

    if (root is ChampBitmapNode<K, V>) {
      mutableRoot = root.ensureMutable(owner);
    } else if (root is ChampCollisionNode<K, V>) {
      mutableRoot = root.ensureMutable(owner);
    } else {
      mutableRoot = root;
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

    if (additions == 0 && identical(mutableRoot, root)) {
      return this;
    }

    final frozenRoot = mutableRoot.freeze(owner);
    final newCount = _length + additions; // Access private member

    return ApexMapImpl._(frozenRoot, newCount); // Use internal constructor
  }

  @override
  ApexMap<K, V> remove(K key) {
    if (isEmpty) return this;
    final champ.ChampNode<K, V> root = _root; // Access private member

    final removeResult = root.remove(key, key.hashCode, 0, null);

    if (identical(removeResult.node, root)) return this;

    final newLength =
        removeResult.didRemove ? _length - 1 : _length; // Access private member
    assert(newLength >= 0);

    if (removeResult.node.isEmptyNode) {
      return ApexMapImpl.emptyInstance<K, V>(); // Use static method
    }

    return ApexMapImpl._(
      removeResult.node,
      newLength,
    ); // Use internal constructor
  }

  @override
  ApexMap<K, V> update(
    K key,
    V Function(V value) updateFn, {
    V Function()? ifAbsent,
  }) {
    final champ.ChampNode<K, V> root = _root; // Access private member
    final champ.ChampUpdateResult<K, V> updateResult;

    if (root.isEmptyNode) {
      if (ifAbsent != null) {
        final newValue = ifAbsent();
        final newNode = ChampDataNode<K, V>(key.hashCode, key, newValue);
        updateResult = (node: newNode, sizeChanged: true);
      } else {
        return ApexMapImpl.emptyInstance<K, V>(); // Use static method
      }
    } else {
      updateResult = root.update(
        key,
        key.hashCode,
        0,
        updateFn,
        ifAbsentFn: ifAbsent,
        owner: null,
      );
    }

    if (identical(updateResult.node, root)) {
      return this;
    }

    final newLength =
        updateResult.sizeChanged
            ? _length + 1
            : _length; // Access private member

    if (updateResult.node.isEmptyNode) {
      return ApexMapImpl.emptyInstance<K, V>(); // Use static method
    }

    return ApexMapImpl._(
      updateResult.node,
      newLength,
    ); // Use internal constructor
  }

  @override
  ApexMap<K, V> updateAll(V Function(K key, V value) updateFn) {
    if (isEmpty) return this;
    final owner = champ_utils.TransientOwner();
    champ.ChampNode<K, V> mutableRoot;
    final champ.ChampNode<K, V> root = _root; // Access private member

    if (root is ChampBitmapNode<K, V>) {
      mutableRoot = root.ensureMutable(owner);
    } else if (root is ChampCollisionNode<K, V>) {
      mutableRoot = root.ensureMutable(owner);
    } else {
      mutableRoot = root;
    }
    bool changed = false;
    // Need access to iterator - assumes 'entries' works (defined in accessors ext)
    // Correct approach: Iterate using the iterator from the main class/iterable extension
    final iter = iterator; // Assuming iterator getter is available
    while (iter.moveNext()) {
      final entry = iter.current; // Get the MapEntry
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
      if (identical(mutableRoot, root)) return this;
      final frozenRoot = mutableRoot.freeze(owner);
      return ApexMapImpl._(frozenRoot, _length); // Use internal constructor
    }
    final frozenRoot = mutableRoot.freeze(owner);
    return ApexMapImpl._(frozenRoot, _length); // Use internal constructor
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    // Use the accessor method defined in another part file
    final existing = this[key]; // Assumes operator[] is available
    if (existing != null) {
      return existing;
    }
    return ifAbsent();
  }

  @override
  ApexMap<K, V> clear() {
    return ApexMapImpl.emptyInstance<K, V>(); // Use static method
  }

  @override
  ApexMap<K, V> removeWhere(bool Function(K key, V value) predicate) {
    if (isEmpty) return this;
    final owner = champ_utils.TransientOwner();
    champ.ChampNode<K, V> mutableRoot;
    final champ.ChampNode<K, V> root = _root; // Access private member

    if (root is ChampBitmapNode<K, V>) {
      mutableRoot = root.ensureMutable(owner);
    } else if (root is ChampCollisionNode<K, V>) {
      mutableRoot = root.ensureMutable(owner);
    } else {
      mutableRoot = root;
    }
    int removalCount = 0;
    final keysToRemove = <K>[];
    // Iterate using the iterator from the main class/iterable extension
    final iter = iterator; // Assuming iterator getter is available
    while (iter.moveNext()) {
      final entry = iter.current;
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
    final newCount = _length - removalCount; // Access private member
    if (newCount == 0) {
      return ApexMapImpl.emptyInstance<K, V>(); // Use static method
    }
    return ApexMapImpl._(frozenRoot, newCount); // Use internal constructor
  }
}
