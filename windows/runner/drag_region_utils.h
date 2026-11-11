#ifndef RUNNER_DRAG_REGION_UTILS_H_
#define RUNNER_DRAG_REGION_UTILS_H_

#include <windows.h>

#include <flutter/encodable_value.h>

#include <string>
#include <vector>

// 原生拖拽区：把 Flutter 侧上报的标题栏矩形翻译成 WM_NCHITTEST 的 HTCAPTION。
// 走原生 hit-test 而不是 Flutter pan 手势，因为后者要和滚动/点击抢手势竞技场，
// 经常输给 Scrollable 导致窗口拖不动。
class DragRegionUtils {
 public:
  // 处理 com.predidit.kazumi/drag 通道的 setDragRegions 调用。
  // 清除走空列表语义（Dart 侧注销后自然收敛），无需独立方法。
  static bool HandleMethodCall(const std::string& method_name,
                               const flutter::EncodableValue* payload);

  // WM_NCHITTEST 命中判断。返回 HTCAPTION 表示该点应拖窗口；
  // 返回 0 表示不表态，交回默认处理（保留 resize 边框与按钮点击）。
  static LRESULT HitTest(HWND hwnd, LPARAM lparam);

  static void Clear();

 private:
  static std::vector<RECT> ParseRects(const flutter::EncodableValue* value);
};

#endif  // RUNNER_DRAG_REGION_UTILS_H_
