/// Defines the [ChampCollisionNode] class, representing a CHAMP node with hash collisions.
library;

// Remove unused: import 'dart:collection'; // MapEntry is part of dart:core

import 'champ_node_base.dart';
import 'champ_data_node.dart'; // Needed for remove and splitting
import 'champ_bitmap_node.dart'; // Needed for add/update splitting
import 'champ_utils.dart'; // For TransientOwner
// No need to import sparse/array here, factory is on ChampBitmapNode

// --- Collision Node ---

/// Represents a CHAMP node containing multiple entries that have the same hash code
/// up to a certain depth (i.e., their hash fragments collide at multiple levels).
/// Stores entries in a simple list and performs linear search within that list.
class ChampCollisionNode<K, V> extends ChampNode<K, V> {
  /// The hash code shared by all entries in this node.
  final int collisionHash;

  /// The list of colliding entries. Mutable only if the node is transient.
  List<MapEntry<K, V>> entries;

  /// Creates a collision node.
  ///
  /// - [collisionHash]: The common hash code.
  /// - [entries]: The list of entries with the colliding hash. Must contain at least 2 entries.
  /// - [owner]: Optional [TransientOwner] for mutability.
  ChampCollisionNode(
    this.collisionHash,
    List<MapEntry<K, V>> entries, [
    TransientOwner? owner,
  ]) : entries =
           entries, // Assign directly; immutability handled by returning new nodes or freezing
       assert(entries.length >= 2), // Must have at least 2 entries
       super(owner);

  @override
  V? get(K key, int hash, int shift) {
    // Only search if the hash matches the collision hash
    if (hash == collisionHash) {
      // Linear search through the colliding entries
      for (final entry in entries) {
        if (entry.key == key) {
          return entry.value;
        }
      }
    }
    return null; // Hash doesn't match or key not found in list
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    // Only search if the hash matches the collision hash
    if (hash == collisionHash) {
      // Linear search through the colliding entries
      for (final entry in entries) {
        if (entry.key == key) {
          return true;
        }
      }
    }
    return false; // Hash doesn't match or key not found in list
  }

  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    if (hash != collisionHash) {
      // Hash differs, need to create a bitmap node to split this collision node
      // and the new data node based on their differing hash fragments at this level.
      final dataNode = ChampDataNode<K, V>(hash, key, value);
      // Use the static factory on ChampBitmapNode (will be defined later)
      final newNode = ChampBitmapNode.fromNodes<K, V>(
        shift, // Create bitmap node at the current shift level
        collisionHash,
        this, // Existing collision node
        hash,
        dataNode, // New data node
        null, // Immutable operation when splitting
      );
      return (node: newNode, didAdd: true);
    }

    // Hash matches, add/update within the collision list
    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner); // Ensure mutable if owned
      final existingIndex = mutableNode.entries.indexWhere((e) => e.key == key);
      if (existingIndex != -1) {
        // Update existing key
        if (mutableNode.entries[existingIndex].value == value) {
          return (node: mutableNode, didAdd: false); // No change
        }
        mutableNode.entries[existingIndex] = MapEntry(
          key,
          value,
        ); // Mutate in place
        return (node: mutableNode, didAdd: false);
      } else {
        // Add new entry
        mutableNode.entries.add(MapEntry(key, value)); // Mutate in place
        return (node: mutableNode, didAdd: true);
      }
    } else {
      // --- Immutable Path ---
      final existingIndex = entries.indexWhere((e) => e.key == key);
      if (existingIndex != -1) {
        // Update existing key
        if (entries[existingIndex].value == value) {
          return (node: this, didAdd: false); // No change
        }
        // Create new list with updated entry
        final newEntries = List<MapEntry<K, V>>.of(entries);
        newEntries[existingIndex] = MapEntry(key, value);
        return (
          node: ChampCollisionNode<K, V>(collisionHash, newEntries), // New node
          didAdd: false,
        );
      } else {
        // Add new entry
        // Create new list with added entry
        final newEntries = List<MapEntry<K, V>>.of(entries)
          ..add(MapEntry(key, value));
        return (
          node: ChampCollisionNode<K, V>(collisionHash, newEntries), // New node
          didAdd: true,
        );
      }
    }
  }

  @override
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    if (hash != collisionHash) {
      return (node: this, didRemove: false); // Hash doesn't match
    }

    // Use ensureMutable to handle both transient and immutable cases cleanly
    final mutableNode = ensureMutable(owner);
    final initialLength = mutableNode.entries.length;

    // Perform removal (mutates if transient, creates new list if immutable via ensureMutable)
    mutableNode.entries.removeWhere((e) => e.key == key);
    final removed = mutableNode.entries.length < initialLength;

    if (!removed) {
      // Key not found, return original (or the mutable copy if it was created)
      // If it was immutable, ensureMutable returned a copy, which is fine to return.
      // If it was transient, ensureMutable returned 'this', which is also fine.
      return (node: mutableNode, didRemove: false);
    }

    // If only one entry remains, convert back to an immutable DataNode
    if (mutableNode.entries.length == 1) {
      final lastEntry = mutableNode.entries.first;
      // DataNode is always immutable
      final dataNode = ChampDataNode<K, V>(
        collisionHash,
        lastEntry.key,
        lastEntry.value,
      );
      return (node: dataNode, didRemove: true);
    }

    // Otherwise, return the modified collision node
    // If it was immutable, mutableNode is the new immutable copy.
    // If it was transient, mutableNode is the mutated original.
    return (node: mutableNode, didRemove: true);
  }

  @override
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  }) {
    if (hash != collisionHash) {
      // Hash doesn't match this collision node
      if (ifAbsentFn != null) {
        // Add as a new entry (will create an internal node to split)
        final newValue = ifAbsentFn();
        final dataNode = ChampDataNode<K, V>(hash, key, newValue);
        // Use the static factory on ChampBitmapNode (will be defined later)
        final newNode = ChampBitmapNode.fromNodes<K, V>(
          shift,
          collisionHash,
          this,
          hash,
          dataNode,
          null, // Immutable operation
        );
        return (node: newNode, sizeChanged: true);
      }
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }

    // Hash matches, operate on the list
    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner);
      final existingIndex = mutableNode.entries.indexWhere((e) => e.key == key);
      if (existingIndex != -1) {
        // Update existing key
        final currentValue = mutableNode.entries[existingIndex].value;
        final newValue = updateFn(currentValue);
        if (newValue == currentValue) {
          return (node: mutableNode, sizeChanged: false); // No change
        }
        mutableNode.entries[existingIndex] = MapEntry(
          key,
          newValue,
        ); // Mutate in place
        return (node: mutableNode, sizeChanged: false);
      } else if (ifAbsentFn != null) {
        // Key not found, add using ifAbsentFn
        final newValue = ifAbsentFn();
        mutableNode.entries.add(MapEntry(key, newValue)); // Mutate in place
        return (node: mutableNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: mutableNode, sizeChanged: false);
      }
    } else {
      // --- Immutable Path ---
      final existingIndex = entries.indexWhere((e) => e.key == key);
      if (existingIndex != -1) {
        // Update existing key
        final currentValue = entries[existingIndex].value;
        final newValue = updateFn(currentValue);
        if (newValue == currentValue) {
          return (node: this, sizeChanged: false); // No change
        }
        // Create new list with updated entry
        final newEntries = List<MapEntry<K, V>>.of(entries);
        newEntries[existingIndex] = MapEntry(key, newValue);
        return (
          node: ChampCollisionNode<K, V>(collisionHash, newEntries), // New node
          sizeChanged: false,
        );
      } else if (ifAbsentFn != null) {
        // Key not found, add using ifAbsentFn
        final newValue = ifAbsentFn();
        // Create new list with added entry
        final newEntries = List<MapEntry<K, V>>.of(entries)
          ..add(MapEntry(key, newValue));
        return (
          node: ChampCollisionNode<K, V>(collisionHash, newEntries), // New node
          sizeChanged: true,
        );
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  /// Returns this node if mutable and owned, otherwise a mutable copy.
  /// Used for transient operations.
  ChampCollisionNode<K, V> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    // Create a mutable copy with the new owner
    return ChampCollisionNode<K, V>(
      collisionHash,
      List<MapEntry<K, V>>.of(entries, growable: true), // Mutable copy
      owner, // Assign the new owner (can be null for immutable path)
    );
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      // Become immutable
      this.entries = List.unmodifiable(entries); // Make list unmodifiable
      // Call super.freeze() AFTER handling subclass state
      return super.freeze(owner);
    }
    return this; // Already immutable or not owned
  }
}
