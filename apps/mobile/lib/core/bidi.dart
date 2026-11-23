import 'package:material_ui/material_ui.dart';

/// Picks a text direction from the first strongly-directional character, so
/// Arabic content renders right-to-left even inside an English UI (and vice versa).
TextDirection directionFor(String text, {TextDirection fallback = TextDirection.ltr}) {
  for (final r in text.runes) {
    if ((r >= 0x0590 && r <= 0x08FF) || (r >= 0xFB1D && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F)) {
      return TextDirection.ltr;
    }
  }
  return fallback;
}
