import 'package:flutter/material.dart';

class SetRowWidget extends StatefulWidget {
  final int index;
  final double weight;
  final int reps;
  final bool isDropSet;
  final VoidCallback? onAddDrop;
  final VoidCallback onRemove;
  final Function(double) onWeightChanged;
  final Function(int) onRepsChanged;

  const SetRowWidget({
    super.key,
    required this.index,
    required this.weight,
    required this.reps,
    this.isDropSet = false,
    this.onAddDrop,
    required this.onRemove,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  @override
  State<SetRowWidget> createState() => _SetRowWidgetState();
}

class _SetRowWidgetState extends State<SetRowWidget> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.weight == 0 ? '' : widget.weight.toString());
    _repsController = TextEditingController(text: widget.reps == 0 ? '' : widget.reps.toString());
  }

  @override
  void didUpdateWidget(covariant SetRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newWeight = widget.weight == 0 ? '' : widget.weight.toString();
    final newReps = widget.reps == 0 ? '' : widget.reps.toString();
    if (_weightController.text != newWeight) {
      _weightController.text = newWeight;
    }
    if (_repsController.text != newReps) {
      _repsController.text = newReps;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: widget.isDropSet ? 24 : 0,
        top: 4,
        right: 0,
        bottom: 4,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: widget.isDropSet ? Colors.orange : null,
            child: Text(widget.isDropSet ? 'D' : '${widget.index}', style: const TextStyle(fontSize: 10)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: 'kg', contentPadding: EdgeInsets.symmetric(horizontal: 8)),
              controller: _weightController,
              onChanged: (val) {
                final d = double.tryParse(val);
                if (d != null) widget.onWeightChanged(d);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: 'reps', contentPadding: EdgeInsets.symmetric(horizontal: 8)),
              controller: _repsController,
              onChanged: (val) {
                final i = int.tryParse(val);
                if (i != null) widget.onRepsChanged(i);
              },
            ),
          ),
          if (widget.onAddDrop != null)
            TextButton(
              onPressed: widget.onAddDrop,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('+ drop'),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
