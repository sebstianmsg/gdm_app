import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../reminders/reminders_card.dart';
import '../shared/shared_card.dart';
import 'donut_card.dart';

/// Carrusel horizontal de **alto fijo** que reemplaza a la `DonutCard` suelta
/// en el home (spec 14). Tres páginas:
///   - Card 1: el donut actual (sin cambios).
///   - Card 2: gastos compartidos (placeholder temporal en este paso).
///   - Card 3: placeholder "Próximamente".
///
/// El alto lo fija la **card del donut** (donut + leyenda): se mide una copia
/// offstage y las cards 2 y 3 se ajustan a ese mismo alto. Debajo del carrusel,
/// fuera de las cards, hay **3 puntitos** que reflejan la página visible.
class HomeCarousel extends StatefulWidget {
  const HomeCarousel({
    super.key,
    required this.donut,
  });

  /// La card 1 ya construida por el caller (mantiene su cableado actual).
  final DonutCard donut;

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  final _controller = PageController();
  final _measureKey = GlobalKey();
  int _page = 0;
  double? _cardHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant HomeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La leyenda del donut puede cambiar con los datos → re-medir el alto.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if (h > 0 && h != _cardHeight) {
      setState(() => _cardHeight = h);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pages = <Widget>[
          widget.donut,
          const SharedCard(),
          const RemindersCard(),
        ];

        return Column(
          children: [
            Stack(
              children: [
                // Medidor offstage: una copia de la card 1 con ancho real, para
                // conocer el alto natural del donut sin ocupar espacio.
                Offstage(
                  offstage: true,
                  child: SizedBox(
                    width: width,
                    key: _measureKey,
                    child: widget.donut,
                  ),
                ),
                if (_cardHeight != null)
                  SizedBox(
                    height: _cardHeight,
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (p) => setState(() => _page = p),
                      children: pages,
                    ),
                  )
                else
                  // Primer frame (aún sin medir): mostramos el donut directo
                  // para que no haya salto visible.
                  widget.donut,
              ],
            ),
            const SizedBox(height: 12),
            _Dots(count: pages.length, active: _page),
          ],
        );
      },
    );
  }
}

/// Tres puntitos indicadores, estilo consistente con el carrusel de íconos
/// (spec 12): el activo se resalta y alarga con `context.palette`.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? context.palette.ink
                : context.palette.textMuted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

