import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RouteFieldBox extends StatefulWidget {
  const RouteFieldBox({
    super.key,
    required this.fromController,
    required this.toController,
    this.fromFocusNode,
    this.toFocusNode,
    this.showMyLocationDefault = false,
    this.accentColor = const Color.fromARGB(255, 0, 113, 133),
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final FocusNode? fromFocusNode;
  final FocusNode? toFocusNode;
  final bool showMyLocationDefault;
  final Color accentColor;

  @override
  State<RouteFieldBox> createState() => _RouteFieldBoxState();
}

class _RouteFieldBoxState extends State<RouteFieldBox> {
  @override
  void initState() {
    super.initState();
    widget.fromController.addListener(_onChanged);
    widget.fromFocusNode?.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant RouteFieldBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromController != widget.fromController) {
      oldWidget.fromController.removeListener(_onChanged);
      widget.fromController.addListener(_onChanged);
    }
    if (oldWidget.fromFocusNode != widget.fromFocusNode) {
      oldWidget.fromFocusNode?.removeListener(_onChanged);
      widget.fromFocusNode?.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.fromController.removeListener(_onChanged);
    widget.fromFocusNode?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000)), // ~10% black
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // subtle shadow
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // From
          Expanded(
            child: _InlineField(
              controller: widget.fromController,
              focusNode: widget.fromFocusNode,
              hintText: 'From',
              textAlign: TextAlign.left,
              isFromField: true,
              showMyLocationDefault: widget.showMyLocationDefault,
              accentColor: widget.accentColor,
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0x1A000000),
          ),
          // To
          Expanded(
            child: _InlineField(
              controller: widget.toController,
              focusNode: widget.toFocusNode,
              hintText: 'To',
              textAlign: TextAlign.right,
              isFromField: false,
              showMyLocationDefault: false,
              accentColor: widget.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.controller,
    required this.hintText,
    required this.textAlign,
    required this.isFromField,
    required this.showMyLocationDefault,
    required this.accentColor,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hintText;
  final TextAlign textAlign;
  final bool isFromField;
  final bool showMyLocationDefault;
  final Color accentColor;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final showMyLocOverlay = isFromField && showMyLocationDefault && controller.text.isEmpty && !(focusNode?.hasFocus ?? false);
    return Stack(
      alignment: textAlign == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
      children: [
        CupertinoTextField(
          controller: controller,
          focusNode: focusNode,
          placeholder: showMyLocOverlay ? '' : hintText,
          placeholderStyle: const TextStyle(color: Color(0x66000000), fontSize: 16),
          style: const TextStyle(color: Color(0xFF000000), fontSize: 16),
          cursorColor: const Color(0xFF007185),
          textAlign: textAlign,
          decoration: null, // Let outer container draw the box
          padding: const EdgeInsets.symmetric(vertical: 8),
          maxLines: 1,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.text,
        ),
        if (showMyLocOverlay)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => focusNode?.requestFocus(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.mousePointer2, size: 18, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  'My Location',
                  style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
