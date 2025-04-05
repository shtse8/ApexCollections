// Helper class with controlled hash code to force collisions
class HashCollider {
  final String id;
  final int hashCodeValue;

  HashCollider(this.id, this.hashCodeValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HashCollider &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => hashCodeValue;

  @override
  String toString() => 'HC($id, #$hashCodeValue)';
}
