String formatTime(DateTime? dateTime, {String nullPlaceholder = '-'}) {
  if (dateTime == null) return nullPlaceholder;

  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
