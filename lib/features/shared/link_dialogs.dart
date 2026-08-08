import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/partnerships_data.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radius.dart';
import 'partnership_provider.dart';

/// Traduce la etiqueta de error de negocio (de la RPC) a un mensaje claro.
String messageForInviteError(String code) {
  switch (code) {
    case 'invite_invalid':
      return 'El código no existe. Revisalo e intentá de nuevo.';
    case 'invite_used':
      return 'Ese código ya fue usado.';
    case 'invite_expired':
      return 'El código venció. Pedí uno nuevo.';
    case 'invite_self':
      return 'No podés usar tu propio código.';
    case 'already_linked':
      return 'Ya tenés un vínculo activo. Desvinculate antes de crear otro.';
    default:
      return 'No se pudo aceptar el código. Intentá de nuevo.';
  }
}

/// Modal "Generar código": pide (o reusa) el invite pendiente y muestra el
/// código para compartir con la otra persona.
Future<void> showGenerateCodeSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: const _GenerateCodeBody(),
    ),
  );
}

class _GenerateCodeBody extends ConsumerStatefulWidget {
  const _GenerateCodeBody();

  @override
  ConsumerState<_GenerateCodeBody> createState() => _GenerateCodeBodyState();
}

class _GenerateCodeBodyState extends ConsumerState<_GenerateCodeBody> {
  String? _code;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await ref.read(pendingInviteProvider.notifier).generate();
      if (mounted) setState(() => _code = invite.code);
    } on PartnerInviteException catch (e) {
      if (mounted) setState(() => _error = messageForInviteError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo generar el código. Intentá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Generar código',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Compartí este código con la otra persona. Al ingresarlo, quedan vinculados.',
            style: TextStyle(color: context.palette.textMuted),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_error != null)
            Text(_error!, style: TextStyle(color: context.palette.alert))
          else if (_code != null)
            _CodeBox(code: _code!),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: code));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código copiado')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: context.palette.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              code,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: context.palette.text,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.copy, size: 18, color: context.palette.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Modal "Ingresar código": la otra persona escribe el código y se vincula.
Future<void> showEnterCodeSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: const _EnterCodeBody(),
    ),
  );
}

class _EnterCodeBody extends ConsumerStatefulWidget {
  const _EnterCodeBody();

  @override
  ConsumerState<_EnterCodeBody> createState() => _EnterCodeBodyState();
}

class _EnterCodeBodyState extends ConsumerState<_EnterCodeBody> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Ingresá el código que te compartieron.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(partnershipProvider.notifier).accept(code);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Vinculados!')),
      );
    } on PartnerInviteException catch (e) {
      if (mounted) {
        setState(() => _error = messageForInviteError(e.code));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo aceptar el código. Intentá de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Ingresar código',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Código (ej: ABCD2345)'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: context.palette.alert)),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Vincular'),
          ),
        ],
      ),
    );
  }
}
