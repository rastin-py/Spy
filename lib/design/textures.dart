import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The two textures in the system, generated rather than shipped.
///
/// Film grain sits over the dossier card and the home hero only; the venetian
/// blind sits behind the hero and the word bay. Neither ever goes behind body
/// text. Both are painted from a single cached tile and wrapped in a
/// [RepaintBoundary] - without one they repaint on every slider frame.
abstract final class SpyTextures {
  static const _tile = 128;
  static ui.Image? _grain;

  /// Flips once the tile exists, so anything already on screen can pick it up.
  static final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Builds the noise tile once, in the background.
  ///
  /// Never awaited by startup: grain is decoration, and decoration that can
  /// hold up the first frame is a bug waiting for a slow phone. If the decode
  /// never comes back, the app is simply un-grained.
  static Future<void> warmUp() async {
    if (_grain != null) return;
    final pixels = Uint8List(_tile * _tile * 4);
    // Fixed seed: the grain is part of the design, not a random surprise that
    // differs between two phones on the same table.
    final rng = math.Random(0x5D3);
    for (var i = 0; i < _tile * _tile; i++) {
      // Fractal-ish: two octaves of value noise summed, cheap and plenty at 5%.
      final v = (rng.nextInt(256) * 0.65 + rng.nextInt(256) * 0.35).round().clamp(0, 255);
      pixels[i * 4] = v;
      pixels[i * 4 + 1] = v;
      pixels[i * 4 + 2] = v;
      pixels[i * 4 + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      _tile,
      _tile,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    _grain = await completer.future;
    ready.value = true;
  }

  static ui.Image? get grainTile => _grain;
}

/// Film grain at the theme's opacity, over its child.
class Grain extends StatelessWidget {
  const Grain({required this.child, this.borderRadius, super.key});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SpyTextures.ready,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final tile = SpyTextures.grainTile;
    if (tile == null) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: borderRadius ?? BorderRadius.zero,
                child: CustomPaint(
                  painter: _GrainPainter(tile, context.spy.grainOpacity),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.tile, this.opacity);

  final ui.Image tile;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.ImageShader(
        tile,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      )
      ..blendMode = BlendMode.overlay
      ..color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.tile != tile || old.opacity != opacity;
}

/// Venetian blind - 1px lines every 9px at 5%. Behind the hero and the word bay.
class Blind extends StatelessWidget {
  const Blind({required this.child, required this.color, super.key});

  final Widget child;

  /// The light the slats catch: [SpyColors.text] over a dark ground, the ink
  /// over paper. Passed in because the word bay is `--redact` in both themes
  /// and so cannot read the theme's surface colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BlindPainter(color),
      child: child,
    );
  }
}

class _BlindPainter extends CustomPainter {
  const _BlindPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.05);
    for (var y = 0.0; y < size.height; y += 9) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_BlindPainter old) => old.color != color;
}
