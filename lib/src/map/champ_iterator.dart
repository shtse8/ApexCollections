/// Defines the iterator for traversing CHAMP Tries used by [ApexMap].
library;

import 'champ_node.dart' as champ;

import 'champ_node.dart' as champ;

/// Efficient iterator for traversing the CHAMP Trie.
class ChampTrieIterator<K, V> implements Iterator<MapEntry<K, V>> {
  // Stacks to manage the traversal state
  final List<champ.ChampNode<K, V>> _nodeStack = [];
  final List<int> _bitposStack =
      []; // Stores the next bit position (1 << i) to check
  final List<Iterator<MapEntry<K, V>>> _collisionIteratorStack =
      []; // For CollisionNodes

  // Store key/value separately, create MapEntry in 'current' getter
  K? _currentKey;
  V? _currentValue;
  bool _hasCurrent = false; // Track if key/value are valid
  bool _yieldSingleDataNodeRoot = false; // Flag for single data node root

  ChampTrieIterator(champ.ChampNode<K, V> rootNode) {
    if (rootNode is champ.ChampDataNode<K, V>) {
      // Handle root being a single data node: Set initial key/value
      _currentKey = rootNode.dataKey;
      _currentValue = rootNode.dataValue;
      _hasCurrent = true; // Mark as having a valid current value initially
      _yieldSingleDataNodeRoot = true;
    } else if (!rootNode.isEmptyNode) {
      // Otherwise, push internal/collision nodes as before
      _pushNode(rootNode);
    }
  }

  void _pushNode(champ.ChampNode<K, V> node) {
    if (node is champ.ChampCollisionNode<K, V>) {
      _nodeStack.add(node);
      _bitposStack.add(0); // Not used for collision nodes
      _collisionIteratorStack.add(node.entries.iterator);
    } else if (node is champ.ChampBitmapNode<K, V>) {
      _nodeStack.add(node);
      _bitposStack.add(1); // Start checking from the first bit position
    }
    // ChampEmptyNode and ChampDataNode are not pushed directly onto the main stack
    // DataNode is handled when found within an InternalNode
  }

  @override
  MapEntry<K, V> get current {
    if (!_hasCurrent) {
      // Adhere to Iterator contract
      throw StateError('No current element');
    }
    // Create MapEntry on demand
    return MapEntry(_currentKey as K, _currentValue as V);
  }

  @override
  bool moveNext() {
    // Check flag first for the single data node root case
    if (_yieldSingleDataNodeRoot) {
      _yieldSingleDataNodeRoot = false; // Consume the flag
      // _hasCurrent is already true from constructor
      return true; // Return true for the first call
    }
    // If the flag was already consumed, or wasn't set, invalidate current before trying to find next
    _hasCurrent = false;

    // Proceed with stack-based iteration
    while (_nodeStack.isNotEmpty) {
      final node = _nodeStack.last;
      final bitpos = _bitposStack.last;

      if (node is champ.ChampCollisionNode<K, V>) {
        final collisionIterator = _collisionIteratorStack.last;
        if (collisionIterator.moveNext()) {
          final entry = collisionIterator.current;
          _currentKey = entry.key;
          _currentValue = entry.value;
          _hasCurrent = true;
          return true;
        } else {
          // Finished with this collision node
          _nodeStack.removeLast();
          _bitposStack.removeLast();
          _collisionIteratorStack.removeLast();
          continue; // Try the next node on the stack
        }
      }

      if (node is champ.ChampBitmapNode<K, V>) {
        final dataMap = node.dataMap;
        final nodeMap = node.nodeMap;
        // Access the correct list based on the concrete type
        final List<Object?> list;
        if (node is champ.ChampArrayNode<K, V>) {
          list = node.content;
        } else if (node is champ.ChampSparseNode<K, V>) {
          list = node.children;
        } else {
          // Should not happen if type check is exhaustive
          throw StateError(
            'Unexpected ChampBitmapNode subtype: ${node.runtimeType}',
          );
        }
        final dataSlots =
            champ.bitCount(dataMap) * 2; // Calculate data offset once

        bool processedEntryOrNode =
            false; // Flag to check if we processed something in the loop

        // Resume checking bit positions from where we left off
        for (
          int currentBitpos = bitpos; // Start from saved bitpos
          // Loop until shift overflows or exceeds max bits for the level
          currentBitpos != 0 && currentBitpos <= (1 << champ.kBitPartitionSize);
          currentBitpos <<= 1 // Move to next bit
        ) {
          if ((dataMap & currentBitpos) != 0) {
            // Found a data entry
            final dataIndex = champ.bitCount(dataMap & (currentBitpos - 1));
            final payloadIndex = dataIndex * 2;
            _currentKey = list[payloadIndex] as K; // Use 'list'
            _currentValue = list[payloadIndex + 1] as V; // Use 'list'
            _hasCurrent = true;
            // Update stack to resume after this bitpos on next call
            _bitposStack[_bitposStack.length - 1] = currentBitpos << 1;
            processedEntryOrNode = true;
            return true; // Return the found data entry
          }
          if ((nodeMap & currentBitpos) != 0) {
            // Found a sub-node, push it onto the stack and descend
            final nodeLocalIndex = champ.bitCount(
              nodeMap & (currentBitpos - 1),
            );
            final nodeIndex =
                dataSlots + nodeLocalIndex; // Use pre-calculated dataSlots

            // Check bounds before accessing list
            if (nodeIndex < 0 || nodeIndex >= list.length) {
              // Use 'list'
              // This should ideally not happen with correct node logic, but handle defensively.
              // Consider logging an error or throwing if this occurs in production.
              _nodeStack.removeLast();
              _bitposStack.removeLast();
              processedEntryOrNode =
                  true; // Mark as processed to avoid double pop
              break; // Exit inner loop, continue outer loop
            }

            final subNode =
                list[nodeIndex] as champ.ChampNode<K, V>; // Use 'list'

            // Update stack to resume after this bitpos in the current node later
            _bitposStack[_bitposStack.length - 1] = currentBitpos << 1;
            // Push the new sub-node to explore next
            _pushNode(subNode);
            processedEntryOrNode = true;
            // Restart the outer loop to process the newly pushed node
            break; // Exit inner for-loop, outer while-loop will process pushed node
          }
        } // End for loop over bit positions

        // If the inner loop completed without finding/pushing anything *new* in this iteration
        if (!processedEntryOrNode) {
          _nodeStack.removeLast();
          _bitposStack.removeLast();
        }
        // Continue the outer while loop regardless
        continue;
      } else {
        // Should not happen if root wasn't empty and only Internal/Collision nodes are pushed
        // Should not happen if root wasn't empty and only Internal/Collision nodes are pushed
        _nodeStack.removeLast();
        _bitposStack.removeLast();
      }
    } // End while loop

    // Stack is empty, iteration complete
    _hasCurrent = false; // Invalidate current
    return false;
  }
}
