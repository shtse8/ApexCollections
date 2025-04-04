/// Defines the iterator for traversing CHAMP Tries used by [ApexMap].
library;

import 'dart:collection'; // For Queue
import 'champ_node.dart' as champ;

/// Efficient iterator for traversing the CHAMP Trie using a simplified stack approach.
class ChampTrieIterator<K, V> implements Iterator<MapEntry<K, V>> {
  // Use a Queue as a stack for easier adding/removing from the front (LIFO)
  // Store nodes or entries directly.
  final Queue<Object> _stack = Queue<Object>();

  K? _currentKey;
  V? _currentValue;
  bool _hasCurrent = false;

  ChampTrieIterator(champ.ChampNode<K, V> rootNode) {
    if (!rootNode.isEmptyNode) {
      _stack.addFirst(rootNode); // Add the root node to start traversal
    }
  }

  @override
  MapEntry<K, V> get current {
    if (!_hasCurrent) {
      throw StateError('No current element');
    }
    return MapEntry(_currentKey as K, _currentValue as V);
  }

  @override
  bool moveNext() {
    _hasCurrent = false; // Invalidate current before finding next

    while (_stack.isNotEmpty) {
      final element = _stack.removeFirst(); // Pop from stack

      if (element is champ.ChampDataNode<K, V>) {
        // Found a data node directly
        _currentKey = element.dataKey;
        _currentValue = element.dataValue;
        _hasCurrent = true;
        return true;
      } else if (element is MapEntry<K, V>) {
        // Found an entry from a CollisionNode
        _currentKey = element.key;
        _currentValue = element.value;
        _hasCurrent = true;
        return true;
      } else if (element is champ.ChampCollisionNode<K, V>) {
        // Push all entries from the collision node onto the stack (in reverse order for correct iteration)
        for (int i = element.entries.length - 1; i >= 0; i--) {
          _stack.addFirst(element.entries[i]);
        }
        // Continue the loop to process the first entry pushed
        continue;
      } else if (element is champ.ChampBitmapNode<K, V>) {
        // Push children (data and nodes) onto the stack in reverse order of their bit position
        final dataMap = element.dataMap;
        final nodeMap = element.nodeMap;
        final List<Object?> list;
        if (element is champ.ChampArrayNode<K, V>) {
          list = element.content;
        } else if (element is champ.ChampSparseNode<K, V>) {
          list = element.children;
        } else {
          throw StateError(
            'Unexpected ChampBitmapNode subtype: ${element.runtimeType}',
          );
        }

        // Iterate through possible bit positions in reverse order (31 down to 0)
        for (
          int i = champ.kBitPartitionSize * champ.kMaxDepth - 1;
          i >= 0;
          i--
        ) {
          final bitpos = 1 << i;
          if ((nodeMap & bitpos) != 0) {
            final nodeIndex = champ.nodeIndexFromFragment(i, nodeMap);
            final contentIdx = champ.contentIndexFromNodeIndex(
              nodeIndex,
              dataMap,
            );
            // Check bounds before accessing list
            if (contentIdx >= 0 && contentIdx < list.length) {
              _stack.addFirst(list[contentIdx] as champ.ChampNode<K, V>);
            } else {
              // Log error or handle defensively if index is out of bounds
              print("Error: Iterator node index out of bounds.");
            }
          }
          if ((dataMap & bitpos) != 0) {
            final dataIndex = champ.dataIndexFromFragment(i, dataMap);
            final payloadIndex = champ.contentIndexFromDataIndex(dataIndex);
            // Check bounds before accessing list
            if (payloadIndex >= 0 && payloadIndex + 1 < list.length) {
              // Create a temporary MapEntry to push onto the stack
              final key = list[payloadIndex] as K;
              final value = list[payloadIndex + 1] as V;
              _stack.addFirst(MapEntry(key, value));
            } else {
              // Log error or handle defensively if index is out of bounds
              print("Error: Iterator data index out of bounds.");
            }
          }
        }
        // Continue the loop to process the first child pushed
        continue;
      }
      // Ignore ChampEmptyNode if somehow pushed onto stack
    }

    // Stack is empty
    return false;
  }
}
