# 实验三：均匀线阵方向性

本模块用独立计算函数和 App Designer 文件 `ArrayPatternApp.mlapp` 展示均匀线阵方向图。打开 MATLAB 后切换到 `exp3` 目录，运行：

```matlab
ArrayPatternApp
```

编辑界面请在 App Designer 中打开 `ArrayPatternApp.mlapp`。保存后，在项目根目录执行 `addpath('tools'); export_app_sources`，同步导出的 `exp3/src/ArrayPatternApp.m` 用于审阅，不应加入日常运行路径。

参数控件、布局、直角坐标轴和极坐标容器均可在 Design View 编辑。R2024b 的极坐标轴由 `startupFcn` 在该容器内创建，其绘图与样式代码在 Code View 编辑。

参数和算法也可独立使用：

```matlab
config = exp3_defaults();
config.ElementCount = 8;
result = exp3_pattern(config);
```

## 计算约定

阵元沿线阵轴等间距排列，角度 `phi` 从阵列轴方向起算。`SteeringAngleDeg` 是可选的相位转向扩展，默认 90°，因此默认配置对应指导书中的宽侧阵列公式：

\[
|B(\phi)|=\left|\frac{\sin\!\left(\pi N(d/\lambda)\cos\phi\right)}{\sin\!\left(\pi(d/\lambda)\cos\phi\right)}\right|.
\]

未归一化幅度的理论峰值为阵元数 `N`。分母和分子同时为零时，程序使用解析极限 `N`，保留端射或栅瓣方向上的峰值。线性归一化是可选项，默认关闭。笛卡尔图可切换线性和相对 dB；dB 以 `N` 为参考，显示下限可调。极坐标图使用线性幅度，并遵循归一化选项。

配置字段及默认值由 `exp3_defaults` 定义；`exp3_pattern` 返回 `Config`、角度（度和弧度）、原始幅度、归一化幅度、相对 dB、笛卡尔值及极坐标值。结果只包含数值和配置，不包含图形句柄。函数没有 Signal Processing Toolbox 或 Phased Array System Toolbox 调用。

## 参数与返回字段

`result = exp3_pattern(config)` 接受标量结构体。省略字段时补充默认值，未知字段报错。

| config 字段 | 默认值 | 含义与类型 |
| --- | --- | --- |
| `ElementCount` | `8` | 阵元数，1–512 的整数 |
| `SpacingMeters` | `0.5` | 阵元间距 d，正实数，m |
| `WavelengthMeters` | `1` | 波长 λ，正实数，m |
| `SteeringAngleDeg` | `90` | 相位转向角，0–360°，从阵列轴起算 |
| `AngleStartDeg` / `AngleEndDeg` | `0` / `360` | 绘图角度区间，度 |
| `SampleCount` | `3601` | 等间隔角度采样数，含两端点 |
| `Normalize` | `false` | 是否将线性幅度除以 N，逻辑标量 |
| `CartesianScale` | `'linear'` | 直角图尺度：`'linear'` 或 `'db'` |
| `DecibelFloor` | `-40` | 相对 dB 的显示下限，范围 −200 至 −1 dB |

| result 字段 | 说明 |
| --- | --- |
| `Config` | 校验、补齐后的参数快照 |
| `AngleDegrees` / `AngleRadians` | `SampleCount×1` 角度列向量，度 / rad |
| `RawMagnitude` | 原始阵列因子幅度，理论峰值 N |
| `NormalizedMagnitude` | 除以 N 后的幅度，0–1 |
| `RelativeDb` | 相对 N 的 `20*log10` 幅度，按 `DecibelFloor` 截断 |
| `CartesianValues` | 当前直角坐标图应绘制的幅度或 dB |
| `PolarMagnitude` | 当前极坐标图应绘制的线性幅度 |

所有幅度和 dB 结果都是与角度对应的列向量。`app = ArrayPatternApp` 返回独立界面对象，`app.UIFigure` 为图窗，运行后的 `app.Result` 为上述结构体；修改参数会使结果失效。

输入范围为 `1 ≤ N ≤ 512`、`2 ≤ SampleCount ≤ 200001`，角度端点位于 0–360° 且终点大于起点，`0 < d/λ ≤ 1e6`。超出范围时函数返回带标识的参数错误。

界面提供参数校验、运行、恢复默认值，以及 MAT、CSV、PNG 导出。修改参数会清除旧图并禁用导出，避免把旧结果当作当前参数的结果。PNG 导出当前窗口视图。数值 API `exp3_pattern` 不创建图窗，也不依赖 Signal Processing Toolbox 或 Phased Array System Toolbox。

## 测试

在 `exp3` 目录中将 `tests` 加入路径后运行：

```matlab
addpath('tests')
results = runtests('test_exp3')
assertSuccess(results)
```

测试覆盖默认宽侧峰值、单阵元、解析零点、可去奇点和栅瓣峰值、对称性、转向、归一化、dB 下限及非法参数。测试不需要打开 GUI。
