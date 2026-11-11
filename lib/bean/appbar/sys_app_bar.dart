import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/window_drag_area.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/services/platform/desktop_window_config.dart';
import 'package:kazumi/services/platform/window_drag_regions.dart';
import 'package:window_manager/window_manager.dart';
import 'package:kazumi/utils/device.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double? toolbarHeight;
  final Widget? title;
  final Color? backgroundColor;
  final List<Widget>? actions;
  final Widget? leading;
  final bool needTopOffset;

  const SysAppBar({
    super.key,
    this.toolbarHeight,
    this.title,
    this.backgroundColor,
    this.actions,
    this.leading,
    this.needTopOffset = true,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop();
    final appBarActions = <Widget>[...?actions];
    if (desktop) {
      if (!DesktopWindowConfig.showWindowButton) {
        appBarActions.add(CloseButton(onPressed: () => windowManager.close()));
      }
      appBarActions.add(const SizedBox(width: 8));
    }
    final appBarLeading =
        leading ??
        ((ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
            ? IconButton(
                onPressed: () => context.maybePop(),
                icon: const Icon(Icons.arrow_back),
              )
            : null);

    // Windows 下整条 bar 注册为原生拖拽区，按钮位挖洞保住点击；
    // pan 手势保留作兜底（洞区内与矩形未刷新时仍可拖）
    Widget appBar = AppBar(
      toolbarHeight: preferredSize.height,
      scrolledUnderElevation: 0.0,
      title: title != null
          ? EmbeddedNativeControlArea(
              requireOffset: needTopOffset,
              child: title!,
            )
          : null,
      centerTitle: Platform.isIOS,
      actions: appBarActions.map((action) {
        return EmbeddedNativeControlArea(
          requireOffset: needTopOffset,
          child: WindowDragHole(child: action),
        );
      }).toList(),
      leading: appBarLeading != null
          ? EmbeddedNativeControlArea(
              requireOffset: needTopOffset,
              child: WindowDragHole(child: appBarLeading),
            )
          : null,
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Theme.of(context).brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
    if (desktop && WindowDragRegions.supported) {
      appBar = WindowDragArea(child: appBar);
    }

    return GestureDetector(
      onPanStart: desktop ? (_) => windowManager.startDragging() : null,
      child: appBar,
    );
  }

  @override
  Size get preferredSize {
    // Reserve space for native macOS window controls.
    final topOffset =
        Platform.isMacOS &&
            needTopOffset &&
            DesktopWindowConfig.showWindowButton
        ? 22.0
        : 0.0;
    return Size.fromHeight((toolbarHeight ?? kToolbarHeight) + topOffset);
  }
}
