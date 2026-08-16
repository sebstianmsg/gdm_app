import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Muestra el overlay "Escuchando…" animado (spec 27). Refleja en vivo el
/// [transcript] reconocido y ofrece un botón para terminar el dictado
/// ([onStop]). Se cierra solo cuando el caller hace `Navigator.pop`.
Future<void> showListeningOverlay(
  BuildContext context, {
  required ValueListenable<String> transcript,
  required VoidCallback onStop,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Escuchando',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) =>
        _ListeningOverlay(transcript: transcript, onStop: onStop),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}

class _ListeningOverlay extends StatefulWidget {
  const _ListeningOverlay({required this.transcript, required this.onStop});

  final ValueListenable<String> transcript;
  final VoidCallback onStop;

  @override
  State<_ListeningOverlay> createState() => _ListeningOverlayState();
}

class _ListeningOverlayState extends State<_ListeningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mic pulsante con halo animado.
            ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.15).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.ink.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.ink,
                    ),
                    child: Icon(Icons.mic, color: palette.inkText, size: 32),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Escuchando…',
              style: TextStyle(
                color: palette.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Texto transcripto en vivo.
            ValueListenableBuilder<String>(
              valueListenable: widget.transcript,
              builder: (context, text, _) => Text(
                text.isEmpty ? 'Decí tu gasto…' : text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text.isEmpty ? palette.textMuted : palette.text,
                  fontSize: 16,
                  fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.onStop,
              icon: const Icon(Icons.stop),
              label: const Text('Listo'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.ink,
                foregroundColor: palette.inkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
