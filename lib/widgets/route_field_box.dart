import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/validation_toast.dart';
import '../utils/haptics.dart';
import '../theme/app_colors.dart';

// Toast helpers moved to lib/widgets/validation_toast.dart

class RouteFieldBox extends StatefulWidget {
  const RouteFieldBox({
    super.key,
    required this.fromController,
    required this.toController,
    this.fromFocusNode,
    this.toFocusNode,
    this.showMyLocationDefault = false,
    this.accentColor = AppColors.accent,
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
  bool _swapPressed = false;

  void _swapFields() {
    final fromText = widget.fromController.text;
    final toText = widget.toController.text;

    if (fromText.isEmpty && toText.isEmpty) {
      showValidationToast(context, "Supply at least one location to swap");
      return;
    }

    // Swap texts as typed (including empties)
    widget.fromController
      ..text = toText
      ..selection = TextSelection.collapsed(offset: toText.length);
    widget.toController
      ..text = fromText
      ..selection = TextSelection.collapsed(offset: fromText.length);
  }

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
          SizedBox(
            width: 44,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The thin divider line behind the button
                Container(width: 1, height: 28, color: const Color(0x1A000000)),
                // The swap button centered on the divider
                GestureDetector(
                  onTap: () {
                    final fromText = widget.fromController.text;
                    final toText = widget.toController.text;
                    if (fromText.isEmpty && toText.isEmpty) {
                      showValidationToast(
                        context,
                        "Supply at least one location to swap",
                      );
                      return;
                    }
                    _swapFields();
                    // Light haptic on successful swap
                    Haptics.mediumTick();
                  },
                  onTapDown: (_) => setState(() => _swapPressed = true),
                  onTapUp: (_) => setState(() => _swapPressed = false),
                  onTapCancel: () => setState(() => _swapPressed = false),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 100),
                    scale: _swapPressed ? 0.92 : 1.0,
                    curve: Curves.easeOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _swapPressed
                            ? const Color(0xFFF5F5F5)
                            : const Color(0xFFFFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x1A000000)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        LucideIcons.arrowLeftRight,
                        size: 16,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    final wantsOverlay =
        isFromField &&
        showMyLocationDefault &&
        controller.text.isEmpty &&
        !(focusNode?.hasFocus ?? false);
    final isFocused = focusNode?.hasFocus ?? false;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: wantsOverlay ? 1.0 : 0.0),
      builder: (context, overlayT, _) {
        return Stack(
          alignment: textAlign == TextAlign.right
              ? Alignment.centerRight
              : Alignment.centerLeft,
          children: [
            CupertinoTextField(
              controller: controller,
              focusNode: focusNode,
              // Show placeholder immediately when focused; hide when overlay wants to show.
              placeholder:
                  (isFromField &&
                      showMyLocationDefault &&
                      controller.text.isEmpty &&
                      !isFocused)
                  ? ''
                  : hintText,
              placeholderStyle: const TextStyle(
                color: Color(0x66000000),
                fontSize: 16,
              ),
              style: const TextStyle(color: AppColors.black, fontSize: 16),
              cursorColor: const Color(0xFF007185),
              textAlign: textAlign,
              decoration: null, // Let outer container draw the box
              padding: const EdgeInsets.symmetric(vertical: 8),
              maxLines: 1,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.text,
            ),
            // Overlay always present but animated opacity/blur/offset for smooth transitions
            IgnorePointer(
              ignoring: overlayT < 0.01,
              child: Opacity(
                opacity: overlayT,
                child: Transform.translate(
                  offset: Offset(0, (1 - overlayT) * 4),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: (1 - overlayT) * 2.0,
                      sigmaY: (1 - overlayT) * 2.0,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => focusNode?.requestFocus(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.mousePointer2,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'My Location',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Inline toast view removed; shared toast lives in validation_toast.dart
