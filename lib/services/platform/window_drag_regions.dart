import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Windows 原生拖拽区注册表：把 Flutter 侧的拖拽矩形转发给 runner 的 WM_NCHITTEST。
///
/// 背景：Flutter 侧 `GestureDetector.onPanStart` + `startDragging()` 要和页面里
/// 所有滚动/点击抢手势竞技场，经常输掉导致窗口拖不动；原生 hit-test 由 OS
/// 直接接管拖拽，按下即动，不经过手势竞技场。
///
/// 矩形为客户区物理像素坐标。洞区（可交互控件）优先于拖拽区判定，
/// 保证 HTCAPTION 不吞掉按钮点击。
class WindowDragRegions {
  WindowDragRegions._();

  static const MethodChannel _channel =
      MethodChannel('com.predidit.kazumi/drag');

  /// 仅 Windows 走原生通道；其余平台保持 startDragging 手势方案
  static bool get supported => Platform.isWindows;

  static final Map<Object, Rect> _regions = {};
  static final Map<Object, Rect> _holes = {};

  static bool _dirty = false;

  /// 通道不可用时降级为纯 pan 手势兜底并只记一次日志；
  /// 注意 NotImplemented 响应同样抛 MissingPluginException，方法名漂移会走此分支，
  /// 因此必须留日志，否则「原生拖拽坏了」与「从未启用」在可观测性上无法区分
  static bool _channelAvailable = true;

  static int _retryCount = 0;

  static void registerRegion(Object id, Rect rect) {
    _apply(_regions, id, rect);
  }

  static void registerHole(Object id, Rect rect) {
    _apply(_holes, id, rect);
  }

  static void unregister(Object id) {
    if (_regions.remove(id) != null || _holes.remove(id) != null) {
      _markDirty();
    }
  }

  static void _apply(Map<Object, Rect> map, Object id, Rect rect) {
    if (map[id] == rect) {
      return;
    }
    map[id] = rect;
    _markDirty();
  }

  static void _markDirty() {
    if (!supported) {
      return;
    }
    _dirty = true;
    // 用 microtask 而非 post-frame：post-frame 阶段内再注册的回调要等下一帧才跑，
    // 静止页面上可能永远不跑，native 会停在陈旧矩形（旧页面的带子继续吞点击）
    scheduleMicrotask(_flush);
  }

  static Future<void> _flush() async {
    if (!_dirty) {
      return;
    }
    _dirty = false;
    if (!supported || !_channelAvailable) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setDragRegions', {
        'regions': _encode(_regions.values),
        'holes': _encode(_holes.values),
      });
      _retryCount = 0;
    } on MissingPluginException catch (e) {
      _channelAvailable = false;
      debugPrint('WindowDragRegions: drag channel unavailable, '
          'falling back to pan gesture only: $e');
    } catch (e) {
      // 失败不能丢 payload：回滚 dirty 有限重试，否则 Dart 与 native 矩形永久分叉
      debugPrint('WindowDragRegions flush failed (retry $_retryCount/3): $e');
      if (_retryCount < 3) {
        _retryCount++;
        _dirty = true;
        scheduleMicrotask(_flush);
      }
    }
  }

  static List<Map<String, double>> _encode(Iterable<Rect> rects) {
    return [
      for (final rect in rects)
        {
          'x': rect.left,
          'y': rect.top,
          'width': rect.width,
          'height': rect.height,
        },
    ];
  }
}

/// 计算组件在客户区中的物理像素矩形；布局未就绪时返回 null
Rect? measureClientRect(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  final dpr = View.of(context).devicePixelRatio;
  final origin = renderObject.localToGlobal(Offset.zero);
  final size = renderObject.size;
  return Rect.fromLTWH(
      origin.dx * dpr, origin.dy * dpr, size.width * dpr, size.height * dpr);
}
