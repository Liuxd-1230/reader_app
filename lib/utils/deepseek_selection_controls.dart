import 'package:flutter/foundation.dart'; // 必须引入，用于 ValueListenable
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 自定义文本选择控制器
class DeepSeekSelectionControls extends MaterialTextSelectionControls {
  // 自定义按钮的回调函数
  final Function(String selectedText) onDeepSeekExplain;

  DeepSeekSelectionControls({required this.onDeepSeekExplain});

  @override
  Widget buildToolbar(
      BuildContext context,
      Rect globalEditableRegion,
      double textLineHeight,
      Offset selectionMidpoint,
      List<TextSelectionPoint> endpoints,
      TextSelectionDelegate delegate,
      // 【关键修改】这里类型改成了 ValueListenable<ClipboardStatus>?
      ValueListenable<ClipboardStatus>? clipboardStatus,
      Offset? lastSecondaryTapDownPosition,
      ) {
    // 1. 获取当前选中的文本
    final TextSelection selection = delegate.textEditingValue.selection;
    final String selectedText = selection.textInside(delegate.textEditingValue.text);

    // 2. 定义我们的自定义按钮
    final List<ContextMenuButtonItem> buttonItems = [
      // 系统"复制"按钮
      ContextMenuButtonItem(
        onPressed: () {
          canCopy(delegate) ? handleCopy(delegate) : null;
          delegate.hideToolbar();
        },
        type: ContextMenuButtonType.copy,
      ),
      // 系统"全选"按钮
      ContextMenuButtonItem(
        onPressed: () {
          canSelectAll(delegate) ? handleSelectAll(delegate) : null;
        },
        type: ContextMenuButtonType.selectAll,
      ),
      // ✨ DeepSeek 解释按钮
      ContextMenuButtonItem(
        onPressed: () {
          if (selectedText.isNotEmpty) {
            onDeepSeekExplain(selectedText);
            delegate.hideToolbar();
            // 可选：清除选中状态
            // delegate.userUpdateTextEditingValue(
            //   delegate.textEditingValue.copyWith(
            //     selection: const TextSelection.collapsed(offset: 0),
            //   ),
            //   SelectionChangedCause.toolbar,
            // );
          }
        },
        label: 'DeepSeek解释',
      ),
    ];

    // 3. 构建自适应工具栏
    return AdaptiveTextSelectionToolbar.buttonItems(
      buttonItems: buttonItems,
      anchors: TextSelectionToolbarAnchors(
        primaryAnchor: endpoints.first.point,
      ),
    );
  }
}