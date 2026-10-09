import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// NYU torch logo + "Bobst Library", recoloured to sit on any background.
///
/// Logo: https://commons.wikimedia.org/wiki/File:Nyu_short_color.svg
/// NYU's name and torch are trademarks; fine for this internal prototype and
/// the pitch, but needs NYU's sign-off before any public release.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.color = Colors.white,
    required this.cutoutColor,
  });

  /// Colour of the torch box and "NYU" letters.
  final Color color;

  /// Colour of the torch inside the box; match it to the background so the
  /// torch reads as cut out.
  final Color cutoutColor;

  static const _asset = 'assets/brand/nyu_logo.svg';
  static const _violet = '#4f2987';
  static const _white = '#ffffff';
  static Future<String>? _svg;

  @override
  Widget build(BuildContext context) {
    _svg ??= rootBundle.loadString(_asset);
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder<String>(
          future: _svg,
          builder: (context, snapshot) {
            final svg = snapshot.data;
            if (svg == null) return const SizedBox(width: 82, height: 28);
            return SvgPicture.string(
              svg
                  .replaceAll(_white, _hex(cutoutColor))
                  .replaceAll(_violet, _hex(color)),
              height: 28,
              semanticsLabel: 'NYU',
            );
          },
        ),
        Container(
          width: 1,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: color.withValues(alpha: 0.5),
        ),
        Text(
          'BOBST LIBRARY',
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
