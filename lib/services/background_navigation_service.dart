import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/itinerary.dart';
import '../utils/itinerary_leg_utils.dart';
import '../utils/itinerary_navigation.dart';
import '../utils/leg_helper.dart';
import '../utils/time_utils.dart';
import 'itinerary_navigation_tracker.dart';

const String _channelId = 'itinerary_tracking';
const String _channelName = 'Live itinerary tracking';
const int _notificationId = 4821;

// Notification action taps land in whatever isolate Android spawns for
// them, which may not share Dart-VM-internal messaging (IsolateNameServer)
// with the long-running background-service isolate. SharedPreferences is
// backed by native storage, so it works as a reliable cross-isolate queue
// regardless of that topology; the service isolate polls it.
const String _pendingActionKey = 'nav_pending_action';
const String _pendingActionSeqKey = 'nav_pending_action_seq';
const Duration _pendingActionPollInterval = Duration(seconds: 1);

bool _configured = false;

Future<void> _ensureConfigured() async {
  if (_configured) return;
  _configured = true;
  final service = FlutterBackgroundService();
  const channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: 'Shows your progress while navigating a trip.',
    importance: Importance.low,
  );
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onServiceStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: _channelId,
      initialNotificationTitle: 'Transportia',
      initialNotificationContent: 'Preparing live tracking…',
      foregroundServiceNotificationId: _notificationId,
      foregroundServiceTypes: const [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

/// Starts (or attaches to an already-running) background tracking session.
/// Safe to call repeatedly; never throws.
Future<void> attachOrStartBackgroundNavigation({
  required List<DisplayLegInfo> legs,
  required LatLng initialPos,
  required int startLegIndex,
}) async {
  await _ensureConfigured();
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('queryState');
    return;
  }
  await service.startService();
  await service.on('ready').first.timeout(
    const Duration(seconds: 5),
    onTimeout: () => null,
  );
  service.invoke('startTracking', {
    'legs': legs.map(_displayLegToJson).toList(),
    'startLegIndex': startLegIndex,
    'lat': initialPos.latitude,
    'lon': initialPos.longitude,
  });
}

/// UI-side mirror of the tracker running in the background isolate.
class BackgroundNavigationBridge extends ChangeNotifier
    implements NavigationProgressState {
  BackgroundNavigationBridge() {
    _subscription = FlutterBackgroundService().on('progress').listen(_onEvent);
    FlutterBackgroundService().invoke('queryState');
  }

  StreamSubscription<Map<String, dynamic>?>? _subscription;

  @override
  bool isActive = true;
  @override
  bool arrived = false;
  @override
  bool gpsSignalLost = false;
  @override
  int currentLegIndex = 0;
  @override
  double? remainingWalkMeters;
  @override
  int? remainingStops;

  void _onEvent(Map<String, dynamic>? event) {
    if (event == null) return;
    isActive = event['isActive'] as bool? ?? isActive;
    arrived = event['arrived'] as bool? ?? arrived;
    gpsSignalLost = event['gpsSignalLost'] as bool? ?? gpsSignalLost;
    currentLegIndex = event['currentLegIndex'] as int? ?? currentLegIndex;
    remainingWalkMeters = (event['remainingWalkMeters'] as num?)?.toDouble();
    remainingStops = event['remainingStops'] as int?;
    notifyListeners();
  }

  @override
  void stop() {
    FlutterBackgroundService().invoke('stopTracking');
  }

  @override
  void jumpToLeg(int legIndex) {
    FlutterBackgroundService().invoke('jumpToLeg', {'legIndex': legIndex});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

Map<String, dynamic> _displayLegToJson(DisplayLegInfo entry) {
  return {
    'leg': entry.leg.toJson(),
    'originalIndex': entry.originalIndex,
    'type': entry.type.index,
  };
}

DisplayLegInfo _displayLegFromJson(Map<String, dynamic> json) {
  return DisplayLegInfo(
    leg: Leg.fromJson((json['leg'] as Map).cast<String, dynamic>()),
    originalIndex: json['originalIndex'] as int,
    type: DisplayLegType.values[json['type'] as int],
  );
}

Map<String, dynamic> _progressToMap(ItineraryNavigationTracker tracker) {
  return {
    'isActive': tracker.isActive,
    'arrived': tracker.arrived,
    'gpsSignalLost': tracker.gpsSignalLost,
    'currentLegIndex': tracker.currentLegIndex,
    'remainingWalkMeters': tracker.remainingWalkMeters,
    'remainingStops': tracker.remainingStops,
  };
}

/// "LINE → HEADSIGN" — the headsign is what riders actually see displayed
/// on the vehicle, so it's what lets them confirm they're getting on the
/// right one.
String _legTitle(Leg leg) {
  if (leg.mode == 'WALK') return 'Walking to ${leg.toName}';
  final routeLabel = _legRouteLabel(leg);
  final headsign = leg.headsign;
  if (headsign == null || headsign.isEmpty || headsign == routeLabel) {
    return routeLabel;
  }
  return '$routeLabel → $headsign';
}

String _legRouteLabel(Leg leg) {
  if (leg.displayName != null && leg.displayName!.isNotEmpty) {
    return leg.displayName!;
  }
  if (leg.routeShortName != null && leg.routeShortName!.isNotEmpty) {
    return leg.routeShortName!;
  }
  return getTransitModeName(leg.mode);
}

/// Drives the Android notification's progress bar. Uses [ItineraryNavigationTracker.legProgress]
/// (continuous, GPS-distance-based) rather than the displayed stop count, so
/// the bar creeps forward smoothly between stops instead of only jumping on
/// arrival — for both walk and transit legs.
int _progressPercent(ItineraryNavigationTracker tracker) {
  if (tracker.currentLegIndex >= tracker.legs.length) return 100;
  return (tracker.legProgress * 100).round().clamp(0, 100);
}

/// A departure countdown for a transit leg not yet boarded, shown in place
/// of the usual "N stops to go" line — null once departed (the live/
/// scheduled departure time has passed, or GPS already shows movement) or
/// for walk legs, at which point the caller falls back to the stop count.
String? _waitingLabel(Leg leg, ItineraryNavigationTracker tracker) {
  if (leg.mode == 'WALK') return null;

  final hasDeparted =
      !DateTime.now().isBefore(leg.startTime) || tracker.legProgress >= 0.05;
  if (hasDeparted) return null;

  if (!leg.realTime) {
    final scheduled = leg.scheduledStartTime ?? leg.startTime;
    return 'Scheduled at ${formatTime(scheduled)}';
  }

  final remaining = leg.startTime.difference(DateTime.now());
  if (remaining.inMinutes >= 20) {
    return '🟢 Departs at ${formatTime(leg.startTime)}';
  }
  final minutes = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;
  return '🟢 Departs in $minutes min';
}

/// "N stops until STOP (HH:MM)" / "N stops, X min until STOP" / "STOP is
/// next, in X min" / "STOP is next, at HH:MM" — richer than the shared
/// [progressLabel] (which only knows the stop *count*, for the carousel
/// too): the notification also has the leg itself on hand, so it can name
/// the destination stop and estimate when it'll actually be reached.
///
/// With [virtualRemaining] — the rider's own pace, once it parts from the
/// timetable's (see [virtualRemaining] in itinerary_navigation.dart) — the
/// time left is an estimate and says so: "~9 min", never HH:MM.
String _stopsProgressLine(
  Leg leg,
  int remainingStops, {
  Duration? virtualRemaining,
}) {
  if (remainingStops <= 0) return 'Arriving now';

  final stopName = leg.toName;
  if (virtualRemaining != null) {
    final rounded = (virtualRemaining.inSeconds / 60).round();
    final estimate = rounded < 1 ? 1 : rounded;
    return remainingStops == 1
        ? '$stopName is next, in ~$estimate min'
        : '$remainingStops stops, ~$estimate min until $stopName';
  }

  final arrival = leg.endTime;
  final remaining = arrival.difference(DateTime.now());
  final isSoon = remaining.inMinutes < 15;
  final minutes = remaining.inMinutes < 1 ? 1 : remaining.inMinutes;

  if (remainingStops == 1) {
    return isSoon
        ? '$stopName is next, in $minutes min'
        : '$stopName is next, at ${formatTime(arrival)}';
  }

  return isSoon
      ? '$remainingStops stops, $minutes min until $stopName'
      : '$remainingStops stops until $stopName (${formatTime(arrival)})';
}

/// Rasterizes a Lucide glyph (the same ones used in-app for leg icons) into a
/// bitmap for the notification's large icon. Returns null on any failure so
/// callers can just omit the icon rather than fail the whole notification.
Future<ByteArrayAndroidBitmap?> _renderModeIcon(String mode) async {
  try {
    final iconData = getLegIcon(mode);
    const double size = 96;
    final fontFamily = iconData.fontPackage != null
        ? 'packages/${iconData.fontPackage}/${iconData.fontFamily}'
        : iconData.fontFamily;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = const Color(0xFF2E7D32),
    );

    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: size * 0.55),
          )
          ..pushStyle(ui.TextStyle(fontFamily: fontFamily, color: const Color(0xFFFFFFFF)))
          ..addText(String.fromCharCode(iconData.codePoint));
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(paragraph, Offset(0, (size - paragraph.height) / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return ByteArrayAndroidBitmap(byteData.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null) return;
  unawaited(_queuePendingAction(actionId));
}

Future<void> _queuePendingAction(String actionId) async {
  final prefs = SharedPreferencesAsync();
  final seq = (await prefs.getInt(_pendingActionSeqKey) ?? 0) + 1;
  await prefs.setString(_pendingActionKey, actionId);
  await prefs.setInt(_pendingActionSeqKey, seq);
}

@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();

  final plugin = FlutterLocalNotificationsPlugin();
  ItineraryNavigationTracker? tracker;
  VoidCallback? trackerListener;

  Future<void> showNotification() async {
    final current = tracker;
    if (current == null) return;

    final legIndex = current.currentLegIndex;
    final leg = legIndex < current.legs.length
        ? current.legs[legIndex].leg
        : null;
    final title = leg == null ? 'Trip complete' : _legTitle(leg);
    final remainingStops = current.remainingStops;
    final progressLine =
        (leg == null ? null : _waitingLabel(leg, current)) ??
        (leg != null && leg.mode != 'WALK' && remainingStops != null
            ? _stopsProgressLine(
                leg,
                remainingStops,
                virtualRemaining: current.virtualRemainingNow(),
              )
            : progressLabel(
                remainingWalkMeters: current.remainingWalkMeters,
                remainingStops: remainingStops,
              )) ??
        '';
    final body = current.arrived
        ? "You've arrived"
        : current.gpsSignalLost
        ? '$progressLine (GPS signal lost)'
        : progressLine;

    final actions = <AndroidNotificationAction>[
      const AndroidNotificationAction(
        'leg_prev',
        '◀◀',
        showsUserInterface: false,
        cancelNotification: false,
      ),
      if (leg != null && leg.mode != 'WALK') ...[
        const AndroidNotificationAction(
          'stop_prev',
          '◀',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        const AndroidNotificationAction(
          'stop_next',
          '▶',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      ],
      const AndroidNotificationAction(
        'leg_next',
        '▶▶',
        showsUserInterface: false,
        cancelNotification: false,
      ),
      const AndroidNotificationAction(
        'exit',
        '✕',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    final largeIcon = leg == null ? null : await _renderModeIcon(leg.mode);

    await plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Shows your progress while navigating a trip.',
          ongoing: !current.arrived,
          autoCancel: false,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: _progressPercent(current),
          category: AndroidNotificationCategory.navigation,
          largeIcon: largeIcon,
          actions: actions,
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
    );
  }

  Timer? pendingActionPoll;

  Future<void> stopTracking() async {
    if (trackerListener != null) tracker?.removeListener(trackerListener!);
    tracker?.stop();
    tracker = null;
    pendingActionPoll?.cancel();
    pendingActionPoll = null;
    await plugin.cancel(id: _notificationId);
    await service.stopSelf();
  }

  Future<void> handleActionId(String? actionId) async {
    final current = tracker;
    if (current == null) return;
    switch (actionId) {
      case 'stop_prev':
        current.stepStopBackward();
      case 'stop_next':
        current.stepStopForward();
      case 'leg_prev':
        current.stepLegBackward();
      case 'leg_next':
        current.stepLegForward();
      case 'exit':
        await stopTracking();
    }
  }

  // Primes the "already handled" watermark so a stale action left over from
  // a previous session isn't replayed the moment tracking starts again.
  final prefs = SharedPreferencesAsync();
  int lastHandledActionSeq = await prefs.getInt(_pendingActionSeqKey) ?? 0;

  Future<void> pollPendingAction() async {
    final seq = await prefs.getInt(_pendingActionSeqKey) ?? 0;
    if (seq == lastHandledActionSeq) return;
    lastHandledActionSeq = seq;
    final actionId = await prefs.getString(_pendingActionKey);
    await handleActionId(actionId);
  }

  pendingActionPoll = Timer.periodic(
    _pendingActionPollInterval,
    (_) => unawaited(pollPendingAction()),
  );

  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
    onDidReceiveNotificationResponse: (response) =>
        unawaited(handleActionId(response.actionId)),
    onDidReceiveBackgroundNotificationResponse:
        _handleBackgroundNotificationResponse,
  );

  service.on('startTracking').listen((event) async {
    if (event == null) return;
    if (trackerListener != null) tracker?.removeListener(trackerListener!);
    tracker?.stop();

    final legsJson = (event['legs'] as List).cast<Map>();
    final legs = legsJson
        .map((json) => _displayLegFromJson(json.cast<String, dynamic>()))
        .toList();
    final startLegIndex = event['startLegIndex'] as int? ?? 0;
    final lat = (event['lat'] as num).toDouble();
    final lon = (event['lon'] as num).toDouble();

    final newTracker = ItineraryNavigationTracker(legs);
    tracker = newTracker;
    trackerListener = () async {
      await showNotification();
      service.invoke('progress', _progressToMap(newTracker));
      if (newTracker.arrived) {
        await Future.delayed(const Duration(seconds: 3));
        if (tracker == newTracker) await stopTracking();
      }
    };
    newTracker.addListener(trackerListener!);
    newTracker.start(LatLng(lat, lon), startLegIndex: startLegIndex);
    await showNotification();
    service.invoke('progress', _progressToMap(newTracker));
  });

  service.on('queryState').listen((event) {
    final current = tracker;
    if (current != null) {
      service.invoke('progress', _progressToMap(current));
    }
  });

  service.on('jumpToLeg').listen((event) {
    final legIndex = event?['legIndex'] as int?;
    if (legIndex != null) tracker?.jumpToLeg(legIndex);
  });

  service.on('stopTracking').listen((event) => unawaited(stopTracking()));

  service.invoke('ready');
}
