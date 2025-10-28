import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/widgets.dart';

IconData getLegIcon(String mode) {
  switch (mode) {
    case 'WALK':
      return LucideIcons.footprints;
    case 'BIKE':
      return LucideIcons.bike;
    case 'RENTAL':
      return LucideIcons.carTaxiFront;
    case 'CAR':
      return LucideIcons.carFront;
    case 'CAR_PARKING':
      return LucideIcons.parkingMeter;
    case 'CAR_DROPOFF':
      return LucideIcons.parkingMeter;
    case 'ODM':
      return LucideIcons.carTaxiFront;
    // TODO: FLEX and TRANSIT
    case 'TRAM':
      return LucideIcons.tramFront;
    case 'SUBWAY':
      return LucideIcons.squareArrowDown;
    case 'FERRY':
      return LucideIcons.ship;
    case 'AIRPLANE':
      return LucideIcons.planeTakeoff;
    case 'SUBURBAN':
      return LucideIcons.tramFront;
    case 'BUS':
      return LucideIcons.busFront;
    case 'COACH':
      return LucideIcons.bus;
    case 'RAIL':
      return LucideIcons.trainFront;
    case 'HIGHSPEED_RAIL':
      return LucideIcons.trainFront;
    case 'LONG_DISTANCE':
      return LucideIcons.trainFront;
    case 'NIGHT_RAIL':
      return LucideIcons.trainFront;
    case 'REGIONAL_FAST_RAIL':
      return LucideIcons.trainFront;
    case 'REGIONAL_RAIL':
      return LucideIcons.trainFront;
    case 'CABLE_CAR':
      return LucideIcons.cableCar;
    case 'AERIAL_LIFT':
      return LucideIcons.cableCar;
    case 'FUNICULAR':
      return LucideIcons.cableCar;
    case 'AREAL_LIFT':
      return LucideIcons.cableCar;
    case 'METRO':
      return LucideIcons.squareArrowDown;
    default:
      return LucideIcons.circleQuestionMark;
  }
}

/// Returns a human‑readable name for a transit [mode].
/// This mirrors the icon mapping and provides clearer text for UI.
String getTransitModeName(String mode) {
  switch (mode) {
    case 'WALK':
      return 'Walk';
    case 'BIKE':
      return 'Bike';
    case 'RENTAL':
      return 'Rental';
    case 'CAR':
      return 'Car';
    case 'CAR_PARKING':
      return 'Car Parking';
    case 'CAR_DROPOFF':
      return 'Car Drop-off';
    case 'ODM':
      return 'On-Demand';
    case 'TRAM':
      return 'Tram';
    case 'SUBWAY':
      return 'Subway';
    case 'FERRY':
      return 'Ferry';
    case 'AIRPLANE':
      return 'Airplane';
    case 'SUBURBAN':
      return 'Suburban';
    case 'BUS':
      return 'Bus';
    case 'COACH':
      return 'Coach Bus';
    case 'RAIL':
      return 'Train';
    case 'HIGHSPEED_RAIL':
      return 'High-speed Train';
    case 'LONG_DISTANCE':
      return 'Train';
    case 'NIGHT_RAIL':
      return 'Night Train';
    case 'REGIONAL_FAST_RAIL':
      return 'Express Train';
    case 'REGIONAL_RAIL':
      return 'Train';
    case 'CABLE_CAR':
      return 'Cable Car';
    case 'AERIAL_LIFT':
      return 'Aerial Lift';
    case 'FUNICULAR':
      return 'Funicular';
    case 'AREAL_LIFT':
      return 'Areal Lift';
    case 'METRO':
      return 'Metro';
    default:
      return mode; // fallback to raw mode string
  }
}
