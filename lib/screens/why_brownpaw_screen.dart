import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Why Brownpaw exists, in the founder's words, under the launch animation.
class WhyBrownpawScreen extends StatelessWidget {
  const WhyBrownpawScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = Riverstone.of(context);
    final text = Theme.of(context).textTheme;

    final lead = text.headlineSmall?.copyWith(
      color: rs.ink,
      fontWeight: FontWeight.w800,
      height: 1.3,
    );
    final body = text.titleMedium?.copyWith(
      color: rs.ink,
      fontWeight: FontWeight.w600,
      height: 1.55,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Why Brownpaw'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                ClipRRect(
                  borderRadius: Pebble.a,
                  child: const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: PlayOnceAnimation(
                      asset: 'images/why-brownpaw.webp',
                      semanticLabel:
                          'A drawn hand curls into a paw beside the Brownpaw '
                          'name',
                      background: Color(0xFFF1EDE4),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'The days of “throw caution to the wind and send” '
                  'are behind me.',
                  style: lead,
                ),
                const SizedBox(height: 20),
                Text("I'm tired of friends dying on the water.", style: body),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Brownpaw',
                        style: TextStyle(
                          color: rs.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ' represents a new mindset where we can have fun '
                            'on the water without taking excessive risk.',
                      ),
                    ],
                  ),
                  style: body,
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 4,
                    width: 44,
                    decoration: BoxDecoration(
                      color: rs.accent,
                      borderRadius: Pebble.pill,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays an animated image (GIF or WebP) once and holds on its last frame.
///
/// Tapping it plays it again. With reduced motion turned on, it shows only
/// the last frame.
class PlayOnceAnimation extends StatefulWidget {
  const PlayOnceAnimation({
    super.key,
    required this.asset,
    required this.semanticLabel,
    this.background,
  });

  final String asset;
  final String semanticLabel;
  final Color? background;

  @override
  State<PlayOnceAnimation> createState() => _PlayOnceAnimationState();
}

class _PlayOnceAnimationState extends State<PlayOnceAnimation> {
  ui.Codec? _codec;
  ui.Image? _frame;
  Timer? _timer;
  bool _playing = false;
  bool _disposed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_codec == null && !_playing) _play();
  }

  Future<void> _play() async {
    if (_playing) return;
    _playing = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    try {
      // A fresh codec each time, so a replay starts from the first frame.
      final data = await rootBundle.load(widget.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      if (_disposed) {
        codec.dispose();
        return;
      }
      _codec?.dispose();
      _codec = codec;
      final count = codec.frameCount;
      for (var i = 0; i < count; i++) {
        final next = await codec.getNextFrame();
        if (_disposed) {
          next.image.dispose();
          return;
        }
        final isLast = i == count - 1;
        if (reduceMotion && !isLast) {
          next.image.dispose();
          continue;
        }
        _show(next.image);
        if (!isLast) {
          final wait = Completer<void>();
          _timer = Timer(next.duration, wait.complete);
          await wait.future;
          if (_disposed) return;
        }
      }
    } catch (e) {
      debugPrint('Could not play ${widget.asset}: $e');
    } finally {
      _playing = false;
    }
  }

  void _show(ui.Image image) {
    final old = _frame;
    setState(() => _frame = image);
    old?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _frame?.dispose();
    _codec?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      hint: 'Double tap to play again',
      child: GestureDetector(
        onTap: _play,
        child: ColoredBox(
          color: widget.background ?? Colors.transparent,
          child: _frame == null
              ? const SizedBox.expand()
              : RawImage(
                  image: _frame,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
        ),
      ),
    );
  }
}
