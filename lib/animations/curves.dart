import 'package:flutter/animation.dart';

class SmallBackOutCurve extends Curve {
  const SmallBackOutCurve(this.s);
  final double s; // overshoot; 0.4–0.8 is subtle
  @override
  double transform(double t) {
    t = t - 1.0;
    return t * t * ((s + 1) * t + s) + 1.0;
  }
}
