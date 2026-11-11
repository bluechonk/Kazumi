#include "drag_region_utils.h"

#include <windowsx.h>

#include <cmath>
#include <vector>

namespace {

// 拖拽区与洞区都是客户区物理像素坐标，由 Dart 侧在布局后上报。
// 洞区（按钮等可交互控件）优先于拖拽区：HTCAPTION 会吞掉点击，
// 必须让控件所在区域保持 HTCLIENT 才能点得动。
std::vector<RECT> g_drag_regions;
std::vector<RECT> g_drag_holes;

// 缺字段或类型不符时按 0 处理：Dart 侧 _encode 是唯一生产者，恒发 double，
// 出现其他类型只会是契约漂移；静默归零退化为「不拖拽」而不是崩溃，冒烟即可发现
double ReadDouble(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return 0.0;
  }
  if (const auto* value = std::get_if<double>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<double>(*value);
  }
  return 0.0;
}

}  // namespace

std::vector<RECT> DragRegionUtils::ParseRects(
    const flutter::EncodableValue* value) {
  std::vector<RECT> rects;
  const auto* list = std::get_if<flutter::EncodableList>(value);
  if (!list) {
    return rects;
  }
  for (const auto& item : *list) {
    const auto* map = std::get_if<flutter::EncodableMap>(&item);
    if (!map) {
      continue;
    }
    RECT rect;
    rect.left = static_cast<LONG>(std::lround(ReadDouble(*map, "x")));
    rect.top = static_cast<LONG>(std::lround(ReadDouble(*map, "y")));
    rect.right = rect.left + static_cast<LONG>(std::lround(ReadDouble(*map, "width")));
    rect.bottom = rect.top + static_cast<LONG>(std::lround(ReadDouble(*map, "height")));
    rects.push_back(rect);
  }
  return rects;
}

bool DragRegionUtils::HandleMethodCall(const std::string& method_name,
                                       const flutter::EncodableValue* payload) {
  if (method_name != "setDragRegions") {
    return false;
  }
  const auto* args = std::get_if<flutter::EncodableMap>(payload);
  if (!args) {
    return false;
  }
  auto find_value = [&](const char* key) -> flutter::EncodableValue {
    auto it = args->find(flutter::EncodableValue(key));
    return it == args->end() ? flutter::EncodableValue() : it->second;
  };
  flutter::EncodableValue regions_value = find_value("regions");
  flutter::EncodableValue holes_value = find_value("holes");
  g_drag_regions = ParseRects(&regions_value);
  g_drag_holes = ParseRects(&holes_value);
  return true;
}

void DragRegionUtils::Clear() {
  g_drag_regions.clear();
  g_drag_holes.clear();
}

LRESULT DragRegionUtils::HitTest(HWND hwnd, LPARAM lparam) {
  if (g_drag_regions.empty()) {
    return 0;
  }
  POINT pt_screen{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};

  // 边框像素留给 DefWindowProc 做 resize 判定，拖拽区只在边框内侧生效；
  // 按窗口自身 DPI 取边框宽度，多屏不同缩放时边界不偏移
  RECT window_rect;
  GetWindowRect(hwnd, &window_rect);
  const UINT dpi = GetDpiForWindow(hwnd);
  const int border_x = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) +
                       GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
  const int border_y = GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) +
                       GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
  if (pt_screen.x < window_rect.left + border_x ||
      pt_screen.x >= window_rect.right - border_x ||
      pt_screen.y < window_rect.top + border_y ||
      pt_screen.y >= window_rect.bottom - border_y) {
    return 0;
  }

  POINT pt_client = pt_screen;
  ScreenToClient(hwnd, &pt_client);
  for (const RECT& hole : g_drag_holes) {
    if (PtInRect(&hole, pt_client)) {
      return 0;
    }
  }
  for (const RECT& region : g_drag_regions) {
    if (PtInRect(&region, pt_client)) {
      return HTCAPTION;
    }
  }
  return 0;
}
