import 'package:flutter/cupertino.dart';

class RouteFieldBox extends StatelessWidget {
  const RouteFieldBox({
    super.key,
    required this.fromController,
    required this.toController,
  });

  final TextEditingController fromController;
  final TextEditingController toController;

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
          Expanded(child: _InlineField(controller: fromController, hintText: 'From')),
          // Divider
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0x1A000000),
          ),
          // To
          Expanded(child: _InlineField(controller: toController, hintText: 'To', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.controller,
    required this.hintText,
    this.textAlign = TextAlign.left,
  });

  final TextEditingController controller;
  final String hintText;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField( 
      controller: controller,
      placeholder: hintText,
      placeholderStyle: const TextStyle(color: Color(0x66000000), fontSize: 16),
      style: const TextStyle(color: Color(0xFF000000), fontSize: 16),
      cursorColor: const Color(0xFF007185),
      textAlign: textAlign,
      decoration: null, // Let outer container draw the box
      padding: const EdgeInsets.symmetric(vertical: 8),
      maxLines: 1,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.text,
    );
  }
}
