# LocalSend 跨平台字体一致性说明

> 适用范围：Android / Linux / Windows  
> 核心实现：`app/lib/config/theme.dart`  
> 相关历史：[#52](https://github.com/localsend/localsend/issues/52)、CHANGELOG 中 Windows/Linux CJK 字体修复

---

## 1. 问题背景

在 Flutter 桌面端，**默认不强制指定字体**时，文字渲染会走各平台系统字体回退链（font fallback）。

对中日韩（CJK）尤其容易出问题：

| 现象 | 原因 |
|------|------|
| 同一句话里中文粗细/字形不一致 | 简体、繁体、日文汉字分别命中不同系统字体 |
| 字重看起来忽粗忽细 | 不同字体家族的 Regular/Medium 度量不一致 |
| 行高、字距观感不同 | 各字体 metrics（ascent/descent/leading）不同 |
| 缺字、豆腐块（□） | 当前字体无对应字形，且 fallback 不完整 |

典型案例见 Issue [#52](https://github.com/localsend/localsend/issues/52)：Windows 简体中文界面下，一句话混用了简体、繁体、日文字体，阅读观感割裂。

LocalSend **没有打包自定义 `.ttf/.otf`**，而是通过「按平台 + 按语言」选定系统 UI 字体，挂到全局 `ThemeData.fontFamily`，保证同一语言界面内字体统一。

---

## 2. 总体策略

```
MaterialApp
  theme / darkTheme = getTheme(...)
    └── ThemeData(fontFamily: <平台+语言决定的字体>)
          └── 几乎所有 Text / 默认 TextStyle 继承该 fontFamily
```

入口在 `app/lib/main.dart`：

```dart
theme: getTheme(colorMode, Brightness.light, dynamicColors),
darkTheme: getTheme(colorMode, Brightness.dark, dynamicColors),
```

`getTheme` 在 `app/lib/config/theme.dart` 中根据：

1. **当前平台**（Windows / Linux / 其他）
2. **当前语言**（`LocaleSettings.currentLocale`）

选择 `fontFamily`，再写入 `ThemeData`。

**设计原则：**

- **不捆绑字体包**（体积、许可证、维护成本更低）
- **优先使用各平台「为该语言优化」的系统 UI 字体**
- **全局统一** `ThemeData.fontFamily`，避免组件各自指定导致混用
- Android 信任系统默认（Roboto + 系统 CJK），不强制覆盖

---

## 3. 平台实现细节

### 3.1 核心代码

```dart
// app/lib/config/theme.dart
// https://github.com/localsend/localsend/issues/52
final String? fontFamily;
if (checkPlatform([TargetPlatform.windows])) {
  fontFamily = switch (LocaleSettings.currentLocale) {
    AppLocale.ja => 'Yu Gothic UI',
    AppLocale.ko => 'Malgun Gothic',
    AppLocale.zhCn => 'Microsoft YaHei UI',
    AppLocale.zhHk || AppLocale.zhTw => 'Microsoft JhengHei UI',
    _ => 'Segoe UI Variable Display',
  };
} else if (checkPlatform([TargetPlatform.linux])) {
  fontFamily = switch (LocaleSettings.currentLocale) {
    AppLocale.ja => 'Noto Sans CJK JP',
    AppLocale.ko => 'Noto Sans CJK KR',
    AppLocale.zhCn => 'Noto Sans CJK SC',
    AppLocale.zhHk || AppLocale.zhTw => 'Noto Sans CJK TC',
    _ => 'Noto Sans',
  };
} else {
  // Android / iOS / macOS 等：不强制指定
  fontFamily = null;
}

return ThemeData(
  // ...
  fontFamily: fontFamily,
);
```

平台判断来自 `app/lib/util/native/platform_check.dart` 的 `checkPlatform`（基于 `defaultTargetPlatform`）。

---

### 3.2 Windows

| 语言 | fontFamily | 说明 |
|------|------------|------|
| 日语 `ja` | `Yu Gothic UI` | 日文 UI 标准字体 |
| 韩语 `ko` | `Malgun Gothic` | 맑은 고딕，韩文 UI |
| 简体中文 `zhCn` | `Microsoft YaHei UI` | 微软雅黑 UI，专为屏幕显示 |
| 繁体 `zhHk` / `zhTw` | `Microsoft JhengHei UI` | 微软正黑体 UI |
| 其他语言 | `Segoe UI Variable Display` | 现代 Windows 可变 UI 字体 |

**为什么能解决「同一句话粗细不一致」：**

- 未指定时，Flutter/Skia 按码点回退，汉字可能分别命中 YaHei / JhengHei / 游ゴシック 等，**同一段落多种字体**
- 指定 `Microsoft YaHei UI` 后，整句中文走同一字体家族，字重与 metrics 一致

历史演进（见 `app/assets/CHANGELOG.md`）：

1. 先为中文固定 `Microsoft YaHei UI`
2. 再扩展为日/韩/繁体各自专用字体

---

### 3.3 Linux

| 语言 | fontFamily | 说明 |
|------|------------|------|
| 日语 | `Noto Sans CJK JP` | 日本字形 |
| 韩语 | `Noto Sans CJK KR` | 韩国字形 |
| 简体中文 | `Noto Sans CJK SC` | Simplified Chinese |
| 繁体 | `Noto Sans CJK TC` | Traditional Chinese |
| 其他 | `Noto Sans` | 通用无衬线 |

**要点：**

- Linux 发行版默认字体差异极大；直接用「系统默认」时 CJK 经常缺字或混用
- Noto CJK 是跨发行版最常见的统一方案（需系统已安装对应字体包）
- CHANGELOG：`fix(linux): add CJK font support...`（PR #2719）

**依赖侧注意：**

- 打包配置（deb/rpm）**未声明** `fonts-noto-cjk` 为硬依赖
- 用户机器上需已安装 Noto CJK，例如：
  - Debian/Ubuntu: `fonts-noto-cjk`
  - Fedora: `google-noto-sans-cjk-fonts`
  - Arch: `noto-fonts-cjk`
- 若未安装，会再次回退到系统其他字体，可能重新出现混用/缺字

---

### 3.4 Android

```dart
} else {
  fontFamily = null;
}
```

| 策略 | 说明 |
|------|------|
| 不设置 `fontFamily` | 使用 Flutter / Material 默认 |
| 默认拉丁字体 | 一般为 **Roboto**（Material） |
| CJK / 多语言 | 由 Android 系统 font fallback 处理（通常含 Noto CJK 等） |

**为何 Android 不必像桌面一样硬编码：**

1. Android 系统字体回退链对多语言支持较完善
2. Material 3 在 Android 上与系统字体体系对齐较好
3. 强制写桌面字体名（如 YaHei）在 Android 上不存在，反而可能出问题

`pubspec.yaml` 中：

```yaml
flutter:
  uses-material-design: true
  # 无 fonts: 段落，无自定义字体资源
```

---

## 4. 如何保证「大小 / 粗细」一致

字体一致性不仅靠 `fontFamily`，还依赖样式使用方式：

### 4.1 全局统一入口

- 几乎所有 UI 文本继承 `Theme.of(context).textTheme` 或默认 `TextStyle`
- 默认 `TextStyle` 会继承 `ThemeData.fontFamily`
- 因此换语言/平台时，整 app 同一套字体家族

### 4.2 字号与字重的写法

项目中常见两种安全写法：

```dart
// 只改字号/字重，不改 fontFamily → 继承主题字体
Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold));

// 使用 textTheme → 同样继承主题 fontFamily
Text(label, style: Theme.of(context).textTheme.titleMedium);
```

应避免的写法（会导致局部脱离统一字体）：

```dart
// 危险：硬编码与主题无关的字体
Text(cmd, style: TextStyle(fontFamily: 'SomeRandomFont'));
```

例外：故障排查页命令文本使用 `fontFamily: 'RobotoMono'`（等宽），属于有意覆盖，仅用于代码/命令展示。

### 4.3 不打包字体时的「粗细」边界

- `FontWeight.w400` / `w500` / `w700` 是否真正有对应字重，取决于**系统字体是否提供该 weight**
- 系统字体缺失某 weight 时，引擎会合成（synthetic bold）或回退，不同平台观感仍可能略有差异
- LocalSend 通过「同一语言固定同一家族」把差异压到最小，而不是做到像素级跨平台完全一致

### 4.4 桌面视觉补偿（与字体相关的周边）

```dart
double get desktopPaddingFix => checkPlatformIsDesktop() ? 8 : 0;
```

按钮等控件在桌面额外加 padding，使控件高度与移动端观感接近；这不是字体文件本身，但影响「文字在控件里是否显得偏小/偏挤」。

---

## 5. Yaru 主题路径的特殊情况

当 `ColorMode.yaru` 时，走 `_getYaruTheme`：

```dart
final baseTheme = brightness == Brightness.light ? yaru.yaruLight : yaru.yaruDark;
return baseTheme.copyWith(/* 输入框、按钮等，未改 fontFamily */);
```

- **不会**应用上文 Windows/Linux 的 locale 字体表
- 字体由 **yaru** 包自带主题决定（面向 Ubuntu/Yaru 桌面）
- 若在 Yaru 主题下仍需严格 CJK 一致，需在 `copyWith` 中额外设置 `fontFamily`（当前未做）

---

## 6. 语言切换与字体刷新

字体选择读取的是：

```dart
LocaleSettings.currentLocale  // slang 当前语言
```

`MaterialApp` 在 `theme` / `darkTheme` 构建时调用 `getTheme`。语言变更后，只要触发了依赖 locale/settings 的重建，新主题会带上新 `fontFamily`。

设置中的 locale 存在 `settingsProvider` / persistence；与 `TranslationProvider`、`LocaleSettings` 配合完成多语言切换。

---

## 7. 未覆盖与已知限制

| 项 | 现状 |
|----|------|
| 自定义字体资源 | 无；完全依赖系统字体是否安装 |
| Linux 未装 Noto CJK | 可能回退混用或缺字 |
| Android 强制统一 | 不强制；依赖 OEM 字体栈 |
| macOS / iOS | `fontFamily = null`，系统默认（如 SF Pro + 苹方等） |
| Yaru 模式 | 不走 CJK 字体表 |
| 等宽字体 | 仅个别调试/命令 UI 使用 `RobotoMono` |
| emoji | 未单独配置；走系统 emoji 字体 |
| 可变字体轴 | Windows 用 `Segoe UI Variable Display`，其他语言多为静态家族 |

---

## 8. 实践清单（迁移到其他 Flutter 项目）

若要在自有 Flutter 项目中复现类似方案：

1. **不要**在每个 `Text` 上散落 `fontFamily`；集中在 `ThemeData.fontFamily`。
2. **Windows**：按语言映射到系统 UI 字体（YaHei UI / JhengHei UI / Yu Gothic UI / Malgun Gothic / Segoe UI）。
3. **Linux**：优先 `Noto Sans CJK *`，并在文档或包装依赖中说明需安装 CJK 字体包。
4. **Android**：通常 `fontFamily: null` 即可；若要强一致，可打包 `Noto Sans SC` 等并在 `pubspec.yaml` 的 `fonts:` 声明。
5. 业务 `TextStyle` 只改 `fontSize` / `fontWeight` / `color`，**不要**覆盖 `fontFamily`（特殊等宽/代码字体除外）。
6. 用真实 CJK 长句回归：同一行内简体汉字、标点、数字、拉丁字母是否同族、同重。
7. 参考 Issue：同一段落混字体 → 几乎一定是 fallback 链问题，而不是单纯 `fontSize` 问题。

---

## 9. 相关文件索引

| 路径 | 作用 |
|------|------|
| `app/lib/config/theme.dart` | 平台 + 语言 → `fontFamily`，生成 `ThemeData` |
| `app/lib/main.dart` | `MaterialApp` 应用 light/dark theme |
| `app/lib/util/native/platform_check.dart` | 平台检测 |
| `app/pubspec.yaml` | 无自定义 fonts 资源；`uses-material-design: true` |
| `app/assets/CHANGELOG.md` | Windows/Linux CJK 字体相关变更记录 |
| `app/lib/pages/troubleshoot_page.dart` | 等宽字体特例 `RobotoMono` |

---

## 10. 一句话总结

LocalSend 通过在 **`ThemeData.fontFamily` 上按平台与语言指定系统 UI 字体**（Windows 用各语言 UI 字体，Linux 用 Noto Sans CJK，Android 用系统默认），避免 Flutter 默认 fallback 在 CJK 场景下混用多种字体，从而保证同一句话在字族、字重与观感上的一致性——**不靠打字体包，而靠正确选择并全局统一系统字体**。
