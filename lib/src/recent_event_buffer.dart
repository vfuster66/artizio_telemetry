import 'recent_event.dart';

/// Buffer circulaire des derniers événements (diagnostic local).
class RecentEventBuffer {
  RecentEventBuffer({this.capacity = 50});

  final int capacity;
  final List<RecentEvent> _items = [];

  void add(RecentEvent event) {
    _items.add(event);
    if (_items.length > capacity) {
      _items.removeRange(0, _items.length - capacity);
    }
  }

  List<RecentEvent> get items => List.unmodifiable(_items);

  void clear() => _items.clear();
}
