import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'brand_mark.dart';

class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF861B62), AppTheme.plum, AppTheme.plumDark],
            stops: [0, .48, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _OrbPainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 48, 40, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      BrandMark(light: true),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Z8 Card Manager',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Card programme console',
                            style: TextStyle(
                              color: Color(0xFFE8CFE0),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _Eyebrow(),
                          SizedBox(height: 22),
                          _HeroHeadline(),
                          SizedBox(height: 18),
                          Text(
                            'A friendly space to create cards, manage limits, and stay on top of every payment.',
                            style: TextStyle(
                              color: Color(0xFFEBDCE6),
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                          SizedBox(height: 18),
                          _CardArtwork(),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Row(
                    children: [
                      Icon(
                        Icons.credit_card_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Virtual cards',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      SizedBox(width: 24),
                      Icon(Icons.tune, color: Colors.white, size: 17),
                      SizedBox(width: 8),
                      Text(
                        'Simple spending controls',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .11),
      border: Border.all(color: Colors.white.withValues(alpha: .23)),
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 14, color: Colors.white),
        SizedBox(width: 8),
        Text(
          'Make room for possibilities',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  );
}

class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline();

  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      style: TextStyle(
        color: Colors.white,
        fontSize: 48,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.6,
      ),
      children: [
        TextSpan(text: 'Your cards.\nYour everyday,\n'),
        TextSpan(
          text: 'made simpler.',
          style: TextStyle(color: AppTheme.mint),
        ),
      ],
    ),
  );
}

class _CardArtwork extends StatelessWidget {
  const _CardArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -.13,
            child: Container(
              width: 310,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                border: Border.all(color: Colors.white.withValues(alpha: .24)),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Transform.rotate(
            angle: -.055,
            child: Container(
              width: 335,
              height: 204,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF811A5D), Color(0xFF48113D)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .22)),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Z8',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'serif',
                          fontSize: 38,
                        ),
                      ),
                      _TinyPill('Virtual card'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 34,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8D0A0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.memory,
                      color: Color(0xFF968D65),
                      size: 19,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '••••  ••••  ••••  ••••',
                    style: TextStyle(
                      color: Colors.white,
                      letterSpacing: 2.5,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CARDHOLDER',
                            style: TextStyle(
                              color: Color(0xFFE7C9DD),
                              fontSize: 8,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'YOUR NAME',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      _CardCircles(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.mint,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check, size: 16, color: AppTheme.ink),
                  SizedBox(width: 7),
                  Text(
                    "You're in control",
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white, fontSize: 10),
    ),
  );
}

class _CardCircles extends StatelessWidget {
  const _CardCircles();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Text('mastercard', style: TextStyle(color: Colors.white, fontSize: 8)),
      SizedBox(width: 6),
      SizedBox(
        width: 30,
        height: 20,
        child: Stack(
          children: [
            Positioned(left: 0, child: _Circle(Color(0xFFE67B60))),
            Positioned(left: 12, child: _Circle(Color(0xFFE8C25D))),
          ],
        ),
      ),
    ],
  );
}

class _Circle extends StatelessWidget {
  const _Circle(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .9),
      shape: BoxShape.circle,
    ),
  );
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 70
      ..color = Colors.white.withValues(alpha: .035);
    canvas.drawCircle(
      Offset(size.width * .16, size.height * .9),
      size.width * .28,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
