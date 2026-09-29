import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/economy.dart';
import '../game/game_state.dart';
import '../l10n/strings.dart';

/// 캐릭터를 탭해 돈을 버는 영역. 손가락 여러 개로 동시에 연타할 수 있고(pointer down 마다 1회),
/// 탭 위치에서 "+금액" 글자가 떠오른다. 돈가방이 떠 있으면 함께 그린다.
class TapArea extends StatefulWidget {
  final GameState game;
  final VoidCallback onBag;
  const TapArea({super.key, required this.game, required this.onBag});

  @override
  State<TapArea> createState() => _TapAreaState();
}

class _Float {
  final Offset pos;
  final String text;
  final Duration born;
  final double drift;
  _Float(this.pos, this.text, this.born, this.drift);
}

class _TapAreaState extends State<TapArea> with TickerProviderStateMixin {
  static const _floatLife = Duration(milliseconds: 900);
  static const _maxFloats = 40;

  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  late final Ticker _ticker;
  final _floats = <_Float>[];
  final _rand = math.Random();
  Duration _now = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _now = elapsed;
      _floats.removeWhere((f) => elapsed - f.born > _floatLife);
      if (_floats.isEmpty) _ticker.stop();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _bounce.dispose();
    _bob.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent e) {
    final s = S.of(context);
    final value = widget.game.tapValue;
    widget.game.tap();
    HapticFeedback.selectionClick();
    _bounce.forward(from: 0).then((_) => _bounce.reverse());
    if (!_ticker.isActive) {
      _now = Duration.zero;
      _ticker.start();
    }
    if (_floats.length >= _maxFloats) _floats.removeAt(0);
    _floats.add(_Float(e.localPosition, '+${s.n(value)}', _now, (_rand.nextDouble() - 0.5) * 40));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final game = widget.game;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth, box.maxHeight) * 0.58;
        final bag = game.bagPosition;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // 탭 영역 전체가 반응한다 (캐릭터를 정확히 안 눌러도 됨).
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onDown,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween(
                          begin: 1.0,
                          end: 0.9,
                        ).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut)),
                        child: _Character(size: size, emoji: Economy.rankEmojis[game.rank]),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        game.totalTaps < 20 ? s.tapHint : s.perTap(game.tapValue),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          shadows: [Shadow(color: scheme.shadow.withValues(alpha: 0.4), blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 떠오르는 금액
            for (final f in _floats) _floatWidget(f),
            if (bag != null)
              Positioned(
                left: bag.dx * box.maxWidth - 32,
                top: bag.dy * box.maxHeight - 32,
                child: AnimatedBuilder(
                  animation: _bob,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -6 * _bob.value),
                    child: Transform.rotate(angle: (_bob.value - 0.5) * 0.3, child: child),
                  ),
                  child: GestureDetector(
                    onTap: widget.onBag,
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.25),
                        boxShadow: [BoxShadow(color: Colors.yellow.withValues(alpha: 0.7), blurRadius: 18)],
                      ),
                      child: const Text('💰', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _floatWidget(_Float f) {
    final t = ((_now - f.born).inMicroseconds / _floatLife.inMicroseconds).clamp(0.0, 1.0);
    return Positioned(
      left: f.pos.dx - 60 + f.drift * t,
      top: f.pos.dy - 30 - 90 * Curves.easeOut.transform(t),
      width: 120,
      child: IgnorePointer(
        child: Opacity(
          opacity: 1 - t * t,
          child: Text(
            f.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFF59D),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

class _Character extends StatelessWidget {
  final double size;
  final String emoji;
  const _Character({required this.size, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFFFFF3C4), Color(0xFFFFC94A)]),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.52)),
    );
  }
}
