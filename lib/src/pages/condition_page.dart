import 'package:flutter/material.dart';

/// Modo comparacion de estado: dos fotos, el estado actual del producto
/// y una referencia de como se ve nuevo.
class ConditionPage extends StatefulWidget {
  const ConditionPage({super.key});

  @override
  State<ConditionPage> createState() => _ConditionPageState();
}

class _ConditionPageState extends State<ConditionPage> {
  bool _currentTaken = false;
  bool _referenceTaken = false;

  final TextEditingController _notesController = TextEditingController();

  bool get _bothTaken => _currentTaken && _referenceTaken;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar estado')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Saca las dos fotos para dejar documentado el desgaste antes '
            'de vender.',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _photoSlot(
                  label: 'Estado actual',
                  taken: _currentTaken,
                  onTap: () => setState(() => _currentTaken = !_currentTaken),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _photoSlot(
                  label: 'Como nuevo',
                  taken: _referenceTaken,
                  onTap: () =>
                      setState(() => _referenceTaken = !_referenceTaken),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Detalles del desgaste',
              hintText: 'Ej: rayon en la carcasa, almohadillas gastadas',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _bothTaken ? _save : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar comparacion'),
            ),
          ),
        ],
      ),
    );
  }

  /// Espacio para una foto. Mientras no haya camara, el toque solo
  /// cambia el estado del recuadro.
  Widget _photoSlot({
    required String label,
    required bool taken,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: taken ? Colors.green : Colors.grey,
                width: taken ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                taken ? Icons.check_circle : Icons.add_a_photo_outlined,
                size: 32,
                color: taken ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          taken ? 'Foto lista' : 'Tocar para sacar',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comparacion guardada')),
    );
    Navigator.pop(context);
  }
}
