/// Defines the iterator for traversing HAMT Tries.
library apex_collections.src.map_hamt.hamt_iterator;

import 'dart:collection'; // For Queue, MapEntry
import 'hamt_node.dart'; // Import HAMT node definitions

/// Custom iterator for HAMT Tries designed to avoid unnecessary MapEntry creation.
class HamtIterator<K, V> {
  // Stack to manage traversal state. Stores HamtNode or [K, V] lists or MapEntry (from CollisionNode).
  final Queue<Object> _stack = Queue<Object>();

  // Internal state for the current key and value
  K? _internalCurrentKey;
  V? _internalCurrentValue;
  bool _hasCurrent = false;

  /// Creates an iterator starting from the root node.
  HamtIterator(HamtNode<K, V> rootNode) {
    if (!rootNode.isEmptyNode) {
      _stack.addFirst(rootNode);
    }
  }

  /// Returns the key of the current element.
  /// Throws a [StateError] if [moveNext] has not been called or has returned false.
  K get currentKey {
    if (!_hasCurrent) {
      throw StateError('No current element');
    }
    return _internalCurrentKey as K;
  }

  /// Returns the value of the current element.
  /// Throws a [StateError] if [moveNext] has not been called or has returned false.
  V get currentValue {
    if (!_hasCurrent) {
      throw StateError('No current element');
    }
    return _internalCurrentValue as V;
  }

  /// Returns the current element as a [MapEntry].
  /// Note: Creates a new [MapEntry] instance on each access.
  /// Use [currentKey] and [currentValue] for performance-critical code.
  MapEntry<K, V> get currentEntry {
    if (!_hasCurrent) {
      throw StateError('No current element');
    }
    return MapEntry(_internalCurrentKey as K, _internalCurrentValue as V);
  }

  /// Moves to the next element. Returns true if successful, false otherwise.
  bool moveNext() {
    _hasCurrent = false; // Invalidate current before finding next

    while (_stack.isNotEmpty) {
      final element = _stack.removeFirst(); // Pop from stack

      if (element is HamtDataNode<K, V>) {
        // Found a standalone data node
        _internalCurrentKey = element.dataKey;
        _internalCurrentValue = element.dataValue;
        _hasCurrent = true;
        return true;
      } else if (element is List<Object?> && element.length == 2) {
        // Found a [key, value] pair pushed from a BitmapNode
        _internalCurrentKey = element[0] as K;
        _internalCurrentValue = element[1] as V;
        _hasCurrent = true;
        return true;
      } else if (element is MapEntry<K, V>) {
        // Found an entry directly from a CollisionNode
        _internalCurrentKey = element.key;
        _internalCurrentValue = element.value;
        _hasCurrent = true;
        return true;
      } else if (element is HamtCollisionNode<K, V>) {
        // Push all entries from the collision node onto the stack (reverse order)
        // Decide whether to push MapEntry or [K, V] list here.
        // Pushing MapEntry is simpler as CollisionNode stores them.
        for (int i = element.entries.length - 1; i >= 0; i--) {
          _stack.addFirst(element.entries[i]);
        }
        continue; // Process the first pushed entry
      } else if (element is HamtBitmapNodeImpl<K, V>) {
        // Use concrete type
        // --- Process Bitmap Node (HAMT Strategy: Single list with [K,V] or Node) ---
        // Push nodes first (reverse bit order), then data (reverse bit order)
        // because stack is LIFO, data will be processed first.

        final bitmap = element.bitmap;
        final content = element.content;

        // 1. Push Nodes onto stack (reverse bit order)
        for (int i = 31; i >= 0; i--) {
          final bitpos = 1 << i;
          if ((bitmap & bitpos) != 0) {
            final sparseIdx = element.sparseIndex(bitpos);
            if (sparseIdx < content.length) {
              final item = content[sparseIdx];
              if (item is HamtNode<K, V>) {
                // Check if it's a node
                _stack.addFirst(item);
              }
              // If it's a List<Object?>, it's data, handle in next loop
            } else {
              print("Error: Iterator node sparse index out of bounds (HAMT)");
            }
          }
        }

        // 2. Push Data ([K, V] lists) onto stack (reverse bit order)
        for (int i = 31; i >= 0; i--) {
          final bitpos = 1 << i;
          if ((bitmap & bitpos) != 0) {
            final sparseIdx = element.sparseIndex(bitpos);
            if (sparseIdx < content.length) {
              final item = content[sparseIdx];
              if (item is List<Object?> && item.length == 2) {
                // Check if it's data ([K,V] list)
                _stack.addFirst(item); // Push the [K, V] list
              }
              // If it's a HamtNode, it was handled in the previous loop
            } else {
              print("Error: Iterator data sparse index out of bounds (HAMT)");
            }
          }
        }
        continue; // Process the first pushed child/data
      }
      // Ignore HamtEmptyNode
    }

    // Stack is empty
    return false;
  }
}
