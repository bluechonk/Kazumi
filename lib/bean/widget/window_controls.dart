import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端自定义窗口按钮（最小化/最大化/关闭）。
///
/// 用于隐藏原生标题栏（showWindowButton=false）的播放器顶栏等深色浮层场景，
/// 图标颜色跟随 [iconColor]，默认白色适配播放器遮罩。
class WindowControls extends StatefulWidget {
  const WindowControls({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize,
  });

  final Color iconColor;
  final double? iconSize;

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((value) {
      if (mounted) {
        setState(() => _isMaximized = value);
      }
    }).catchError((e) {
      // 图标状态错了可被后续 maximize 事件自愈，但异常不能无人认领
      KazumiLogger().e('WindowControls: query maximize state failed', error: e);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _isMaximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _isMaximized = false);
    }
  }

  /// 窗口操作失败对用户表现为「点了没反应」，必须留日志并提示
  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      KazumiLogger().e('WindowControls: $label failed', error: e);
      KazumiDialog.showToast(message: '$label失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '最小化',
          iconSize: widget.iconSize ?? IconTheme.of(context).size,
          onPressed: () => _run('最小化', windowManager.minimize),
          icon: Icon(Icons.horizontal_rule, color: widget.iconColor),
        ),
        IconButton(
          tooltip: _isMaximized ? '还原' : '最大化',
          iconSize: widget.iconSize ?? IconTheme.of(context).size,
          onPressed: () => _isMaximized
              ? _run('还原', windowManager.unmaximize)
              : _run('最大化', windowManager.maximize),
          icon: Icon(
            _isMaximized ? Icons.filter_none : Icons.crop_square,
            color: widget.iconColor,
          ),
        ),
        IconButton(
          tooltip: '关闭',
          iconSize: widget.iconSize ?? IconTheme.of(context).size,
          onPressed: () => _run('关闭', windowManager.close),
          icon: Icon(Icons.close, color: widget.iconColor),
        ),
      ],
    );
  }
}
