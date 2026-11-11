import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/bean/appbar/window_drag_area.dart';
import 'package:kazumi/services/platform/window_drag_regions.dart';
import 'package:kazumi/utils/device.dart';

/// A widget for drag to move window.
///
/// When you have hidden the title bar, you can add this widget to move the window position.
///
/// {@tool snippet}
///
/// The sample creates a red box, drag the box to move the window.
///
/// ```dart
/// DragToMoveArea(
///   child: Container(
///     width: 300,
///     height: 32,
///     color: Colors.red,
///   ),
/// )
/// ```
/// {@end-tool}
class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// false 时注销原生拖拽矩形（播放器全屏等场景）
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final gesture = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => (isDesktop()) ? windowManager.startDragging() : null,
      child: child,
    );
    // Windows 走原生 HTCAPTION：pan 手势要和滚动/点击抢竞技场，经常输掉；
    // 原生判定按下即拖。pan 兜底保留，覆盖洞区与矩形未刷新的场景。
    if (isDesktop() && WindowDragRegions.supported) {
      return WindowDragArea(enabled: enabled, child: gesture);
    }
    return gesture;
  }
}
