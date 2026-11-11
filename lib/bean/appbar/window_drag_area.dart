import 'package:flutter/widgets.dart';
import 'package:kazumi/services/platform/window_drag_regions.dart';

/// 声明一块 Windows 原生可拖拽区域（标题栏带）。
///
/// 只在 Windows 生效（[WindowDragRegions.supported]），其余平台原样透传，
/// 由调用方保留的 `startDragging` 手势兜底。
/// [enabled] 为 false 时注销已上报的矩形（如播放器全屏：拖拽带会吞掉视频区点击）。
/// 拖拽区内新增可交互子件必须包 [WindowDragHole]，否则点击会被 HTCAPTION 吞掉且不报错。
class WindowDragArea extends StatefulWidget {
  const WindowDragArea({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<WindowDragArea> createState() => _WindowDragAreaState();
}

/// 拖拽区内的可交互控件（按钮等）：从原生拖拽判定中挖洞，保住点击。
class WindowDragHole extends StatefulWidget {
  const WindowDragHole({super.key, required this.child});

  final Widget child;

  @override
  State<WindowDragHole> createState() => _WindowDragHoleState();
}

/// 拖拽区与洞区共用的上报管线：布局后测量、窗口变化重测、销毁注销。
mixin _DragRectReporter<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  bool get _dragEnabled => true;

  void reportRect(Rect rect);

  @override
  void initState() {
    super.initState();
    if (WindowDragRegions.supported) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (WindowDragRegions.supported) {
      WidgetsBinding.instance.removeObserver(this);
    }
    WindowDragRegions.unregister(this);
    super.dispose();
  }

  // 窗口缩放/最大化/DPI 变化后矩形失效，重新测量
  @override
  void didChangeMetrics() => _report();

  @protected
  void scheduleReport() {
    if (WindowDragRegions.supported) {
      // 布局完成后才能拿到全局坐标；父级重建（如滚动）时顺带刷新
      WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    }
  }

  void _report() {
    if (!mounted) {
      return;
    }
    if (!_dragEnabled) {
      WindowDragRegions.unregister(this);
      return;
    }
    final rect = measureClientRect(context);
    // null 表示布局未就绪（post-frame 下几乎不可达）；跳过本次，等下次 build/metrics 重测
    if (rect != null) {
      reportRect(rect);
    }
  }
}

class _WindowDragAreaState extends State<WindowDragArea>
    with WidgetsBindingObserver, _DragRectReporter<WindowDragArea> {
  @override
  bool get _dragEnabled => widget.enabled;

  @override
  void reportRect(Rect rect) => WindowDragRegions.registerRegion(this, rect);

  @override
  Widget build(BuildContext context) {
    scheduleReport();
    return widget.child;
  }
}

class _WindowDragHoleState extends State<WindowDragHole>
    with WidgetsBindingObserver, _DragRectReporter<WindowDragHole> {
  @override
  void reportRect(Rect rect) => WindowDragRegions.registerHole(this, rect);

  @override
  Widget build(BuildContext context) {
    scheduleReport();
    return widget.child;
  }
}
