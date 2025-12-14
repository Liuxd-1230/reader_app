import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // [新增] 用于 ValueListenable
import 'package:http/http.dart' as http;  // [新增]

class DeepSeekSelectionControls extends MaterialTextSelectionControls {
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
      ValueListenable<ClipboardStatus>? clipboardStatus,
      Offset? lastSecondaryTapDownPosition,
      ) {
    return TextSelectionToolbar(
      anchorAbove: endpoints.first.point,
      anchorBelow: endpoints.last.point,
      children: [
        TextSelectionToolbarTextButton(
          padding: const EdgeInsets.all(8.0),
          onPressed: () {
            final TextSelection selection = delegate.textEditingValue.selection;
            final String text = delegate.textEditingValue.text;
            if (selection.isValid && !selection.isCollapsed) {
              final selectedText = text.substring(selection.start, selection.end);
              delegate.hideToolbar();
              onDeepSeekExplain(selectedText);
            }
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
              SizedBox(width: 4),
              Text('AI 解释', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        TextSelectionToolbarTextButton(
          padding: const EdgeInsets.all(8.0),
          onPressed: () {
            delegate.copySelection(SelectionChangedCause.toolbar);
            delegate.hideToolbar();
          },
          child: const Text('复制'),
        ),
      ],
    );
  }
}

Future<String> fetchDeepSeekExplanation(String text, String apiKey) async {
  if (apiKey.isEmpty) return "请先在设置中配置 API Key";

  try {
    final response = await http.post(
      Uri.parse('https://api.deepseek.com/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        "model": "deepseek-chat",
        "messages": [
          {"role": "system", "content": "你是一个文学阅读助手。请简短地解释、赏析或翻译用户选中的文本。"},
          {"role": "user", "content": text}
        ],
        "stream": false
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] ?? "无内容返回";
    } else {
      return "请求失败: ${response.statusCode}\n${response.body}";
    }
  } catch (e) {
    return "网络错误: $e";
  }
}