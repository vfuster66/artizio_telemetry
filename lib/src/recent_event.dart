/// Entrée du journal local (diagnostic exportable + debug).
class RecentEvent {
  RecentEvent({
    required this.at,
    required this.kind,
    required this.code,
    this.message,
    this.error,
  });

  final DateTime at;
  final String kind; // error | crash | analytics
  final String code;
  final String? message;
  final String? error;

  Map<String, String> toMap() => {
        'at': at.toIso8601String(),
        'kind': kind,
        'code': code,
        if (message != null) 'message': message!,
        if (error != null) 'error': error!,
      };

  @override
  String toString() {
    final buf = StringBuffer('${at.toIso8601String()} [$kind] $code');
    if (message != null && message!.isNotEmpty) buf.write(' — $message');
    if (error != null && error!.isNotEmpty) buf.write(' ($error)');
    return buf.toString();
  }
}
