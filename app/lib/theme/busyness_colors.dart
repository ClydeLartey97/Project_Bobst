import 'package:flutter/material.dart';

import '../models/bobst.dart';

/// Green → red across the six busyness steps.
Color colorFor(Busyness level) => switch (level) {
  Busyness.empty => const Color(0xFF1E9E63),
  Busyness.quiteEmpty => const Color(0xFF5FAE3C),
  Busyness.notTooBusy => const Color(0xFFD99A00),
  Busyness.busy => const Color(0xFFEC7A1C),
  Busyness.veryBusy => const Color(0xFFDD4127),
  Busyness.full => const Color(0xFFB3122E),
};

const nyuViolet = Color(0xFF57068C);
