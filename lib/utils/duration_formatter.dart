String formatDuration(int seconds) {
  if (seconds < 0) {
    return 'N/A';
  }

  int hours = seconds ~/ 3600;
  int minutes = (seconds % 3600) ~/ 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else {
    return '${minutes}m';
  }
}