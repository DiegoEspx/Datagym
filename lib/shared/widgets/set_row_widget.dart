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
  final VoidCallback? onFieldEditComplete;

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
    this.onFieldEditComplete,
  });

  @override
  State<SetRowWidget> createState() => _SetRowWidgetState();
}

class _SetRowWidgetState extends State<SetRowWidget> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  bool _isChecked = false;

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
    final colors = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isChecked ? 0.6 : 1.0,
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.isDropSet ? 28 : 0,
          top: 4,
          right: 0,
          bottom: 4,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _isChecked = !_isChecked),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _isChecked
                      ? colors.primary
                      : (widget.isDropSet ? colors.secondary.withValues(alpha: 0.15) : colors.surfaceContainer),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isChecked ? colors.primary : colors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: _isChecked
                      ? const Icon(Icons.check, size: 16, color: Colors.black)
                      : Text(
                          widget.isDropSet ? 'D' : '${widget.index}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.isDropSet ? colors.secondary : colors.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'kg',
                  suffixStyle: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                controller: _weightController,
                onChanged: (val) {
                  final d = double.tryParse(val);
                  if (d != null) {
                    widget.onWeightChanged(d);
                    widget.onFieldEditComplete?.call();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'reps',
                  suffixStyle: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                controller: _repsController,
                onChanged: (val) {
                  final i = int.tryParse(val);
                  if (i != null) {
                    widget.onRepsChanged(i);
                    widget.onFieldEditComplete?.call();
                  }
                },
              ),
            ),
            if (widget.onAddDrop != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  icon: Icon(Icons.arrow_downward, size: 20, color: colors.secondary),
                  tooltip: 'Drop set',
                  onPressed: widget.onAddDrop,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
              color: colors.error.withValues(alpha: 0.7),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
