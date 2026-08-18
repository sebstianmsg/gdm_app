import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import 'category_summary.dart';
import 'donut_painter.dart';
import 'legend_list.dart';

/// Estado combinado del donut derivado de los providers de categorías y gastos
/// (spec 32). Diferencia explícitamente "cargando" de "sin gastos" y de "error",
/// evitando el anillo gris ambiguo durante la primera carga.
enum DonutStatus {
  /// Primera carga sin valor previo de alguno de los providers.
  loading,

  /// La primera carga falló y no hay valor previo utilizable.
  error,

  /// Ambos providers tienen valor: se puede pintar el donut / "sin gastos".
  ready,
}

// Violeta claro para el texto "Más detalles" en modo oscuro.
// Tinte claro del acento morado (ink #64009D), legible sobre el
// fondo oscuro de la card (#1F0A30).
const Color _masDetallesDarkText = Color(0xFFC6A3E8);

// Color del texto según el tema: negro en claro, violeta claro en oscuro.
Color _masDetallesColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? _masDetallesDarkText
        : const Color(0xFF000000); // negro

/// Tarjeta "Por categoría": donut (SVG-equivalente vía CustomPainter) con
/// botón "+" central que abre el alta de gasto, y debajo la leyenda.
/// Réplica de `.donut-card` / `#catSummary` en `public/index.html`.
class DonutCard extends StatelessWidget {
  const DonutCard({
    super.key,
    required this.summaries,
    required this.onAddPressed,
    required this.onManageCategories,
    this.onVoicePressed,
    this.status = DonutStatus.ready,
  });

  final List<CategorySummary> summaries;
  final VoidCallback onAddPressed;
  final VoidCallback onManageCategories;

  /// Alta de gasto por voz (spec 27). Si es null, no se muestra el mic.
  final VoidCallback? onVoicePressed;

  /// Estado combinado del donut (spec 32). En [DonutStatus.loading] se muestra
  /// un spinner en vez del anillo gris; en [DonutStatus.ready] con [summaries]
  /// vacío se conserva el anillo gris de "sin gastos".
  final DonutStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'POR CATEGORÍA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.palette.textMuted,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.edit, color: context.palette.textMuted),
                onPressed: onManageCategories,
                tooltip: 'Agregar/Modificar categoría',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              // Lado del donut = ancho interno de la tarjeta − 8px de respiro
              // a cada lado (16px total), para que nunca toque el borde. Se
              // mantiene el mismo `Size` en todos los estados para que el
              // carrusel no descuadre al llegar los datos (spec 32, riesgo).
              final side = constraints.maxWidth - 16;
              final isLoading = status == DonutStatus.loading;
              final isError = status == DonutStatus.error;
              return Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Cargando (primera carga): spinner centrado en lugar del
                      // anillo gris ambiguo. Error (reintentos agotados): aviso
                      // mínimo. Listo/sin gastos: donut/anillo.
                      if (isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (isError)
                        const Align(
                          alignment: Alignment(0, -0.55),
                          child: _DonutError(),
                        )
                      else
                        CustomPaint(
                          size: Size(side, side),
                          painter: DonutPainter(summaries: summaries),
                        ),
                      _AddButton(onPressed: onAddPressed),
                      // Mic flotante en la esquina inferior derecha del donut,
                      // al alcance del pulgar, sin tapar el "+" central.
                      if (onVoicePressed != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: _VoiceButton(onPressed: onVoicePressed!),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (summaries.isNotEmpty) ...[
            const SizedBox(height: 24),
            _MoreDetailsButton(
              onPressed: () => _showLegendSheet(context, summaries),
            ),
          ],
        ],
      ),
    );
  }
}

// Abre un modal bottom sheet con el título "Por categoría" y la LegendList.
void _showLegendSheet(BuildContext context, List<CategorySummary> summaries) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.surface,
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'POR CATEGORÍA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.palette.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              LegendList(summaries: summaries),
            ],
          ),
        ),
      );
    },
  );
}

class _MoreDetailsButton extends StatelessWidget {
  const _MoreDetailsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          'Más detalles',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _masDetallesColor(context),
          ),
        ),
      ),
    );
  }
}

/// Aviso mínimo de error del donut (spec 32): se muestra solo cuando el
/// reintento automático agotó su límite. El pull-to-refresh queda como salida.
class _DonutError extends StatelessWidget {
  const _DonutError();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off, size: 32, color: context.palette.textMuted),
        const SizedBox(height: 8),
        Text(
          'No se pudo cargar',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.palette.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Deslizá para reintentar',
          style: TextStyle(fontSize: 12, color: context.palette.textMuted),
        ),
      ],
    );
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.ink,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: context.palette.ink,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.mic, color: context.palette.inkText, size: 26),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.ink,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: context.palette.ink,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 96,
          height: 96,
          child: Icon(Icons.add, color: context.palette.inkText, size: 40),
        ),
      ),
    );
  }
}
