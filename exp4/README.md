# 实验四：系统稳定性分析

本目录包含 App Designer 文件 `SystemStabilityApp.mlapp` 和独立 MATLAB 分析核心。数值分析不需要 Signal Processing Toolbox 或 Control System Toolbox；符号逆变换在检测到可用的 Symbolic Math Toolbox 时执行。

## 启动与函数接口

将本目录加入 MATLAB 路径后运行：

```matlab
app = SystemStabilityApp();
```

编辑界面请在 App Designer 中打开 `SystemStabilityApp.mlapp`。保存后，在项目根目录运行 `addpath('tools'); export_app_sources`，同步生成的 `exp4/src/SystemStabilityApp.m` 仅供代码审阅，运行时不要将 `src` 加入 MATLAB 路径。

数值 API 可单独使用，不需要创建 GUI：

```matlab
config = exp4_defaults('continuous'); % 或 'discrete'
result = exp4_analyze(config);
```

`result` 包含原始零点和极点、稳定性类别与余量、复数频率响应及 dB 幅度、数值冲激响应，以及可选的符号表达式、采样值和数值对照误差。GUI 中的 **运行分析** 会校验所有输入；发生输入或计算错误时，原结果仍保留供查看，修正参数后可再次运行。

`exp4_defaults(domain)` 返回的配置字段如下。调用者可以在 `exp4_analyze` 前修改任一字段；频率轴按所选域解释。

| 字段 | 类型 | 离散默认值 | 连续默认值 | 含义 |
|---|---|---:|---:|---|
| `domain` | `'discrete'` / `'continuous'` | `'discrete'` | `'continuous'` | z 域或 s 域 |
| `numerator` | 有限实系数向量 | `[0.021 0 -0.042 0 0.021]` | `[1 7 24 24]` | 分子系数，按各域约定排序 |
| `denominator` | 有限实系数向量 | `[1 -1.491 2.848 -1.68 1.2732]` | `[1 10 35 50 24]` | 分母系数，按各域约定排序 |
| `stabilityTolerance` | 有限非负标量 | `1e-8` | `1e-8` | 严格判稳边界容差；z 平面无量纲，s 平面为 rad/s |
| `frequencyMin`, `frequencyMax` | 有限非负标量 | `0`, `pi` rad/sample | `0`, `50` rad/s | 频率采样范围 |
| `frequencyPoints` | 整数 2–200000 | `1024` | `1024` | 频率采样点数；频率单位随系统域变化 |
| `sampleCount` | 整数 2–200000 | `120` | `1001` | 冲激响应采样点数；离散域按样本编号，连续域覆盖 `0` 至 `maxTime` s |
| `maxTime` | 有限正标量 | `10`（离散域不使用） | `10` s | 连续冲激响应终止时间 |
| `symbolic` | `true` / `false` | `true` | `true` | 是否尝试符号逆变换 |

分析结果字段为：

| 字段 | 内容 |
|---|---|
| `result.config`, `result.domain` | 实际使用的配置和系统域 |
| `result.originalNumerator`, `result.originalDenominator` | 用户输入的系数 |
| `result.numerator`, `result.denominator` | 去除不改变多项式的零系数并归一化后的系数 |
| `result.zeros`, `result.poles` | 原始输入多项式的有限零点、极点；不自动约分。离散域为 z 平面位置，连续域为 s 平面位置（rad/s） |
| `result.stability` | `isStable`、`classification`、`margin`、`scope`、判稳范围和严格条件 |
| `result.frequency.axis`, `.response`, `.magnitudeDb` | 频率轴（离散域 rad/sample，连续域 rad/s）、复数频响、dB 幅度和 `singularMask`；另有 `axisLabel`、`title`、`note` |
| `result.impulse.axis`, `.numerical`, `.deltaWeight` | 响应横轴（离散样本编号或连续时间 s）、数值常规响应、连续域直接 Dirac 权重 |
| `result.symbolic` | `status`、`available`、`success`、`comparisonPerformed`、表达式、样本和误差 |
| `result.zNumeratorPolynomial`, `result.zDenominatorPolynomial` | 离散域变换成降幂 z 多项式后的系数 |

## 默认传递函数

离散域预设为

\[
H(z)=\frac{0.021(1-2z^{-2}+z^{-4})}{1-1.491z^{-1}+2.848z^{-2}-1.68z^{-3}+1.2732z^{-4}}.
\]

连续域预设为

\[
H(s)=\frac{s^3+7s^2+24s+24}{s^4+10s^3+35s^2+50s+24}.
\]

连续域分母原图首项印作 \(z^4\)；本实验是 s 域传递函数，按 \(s^4\) 解释。离散域分子、分母系数对应指导书中的 \(z^{-1}\) 系列。程序保留输入公式中的全部分母极点；即使输入存在公因子，也不做约分后判稳。

## 系数约定与建模边界

- **离散域：** 系数按 \(z^{-1}\) 升幂排列，例如 `[b0 b1 b2]` 表示 \(b_0+b_1z^{-1}+b_2z^{-2}\)。分子开头的零表示延迟。末尾零系数不改变多项式，会在建模时裁去。分母首系数必须非零，才能表示因果差分方程。
- 求离散零极点时令 \(N=\max(m,n)\)，将分子、分母各自乘以 \(z^N\)，并在短向量尾部补零后求根。由 \(z^N\) 引入的原点零点会保留；分子显式延迟则按多项式本身保留对应的有限零点。零分子不报告有限零点。
- **连续域：** 系数按 \(s\) 降幂排列，例如 `[1 3 2]` 表示 \(s^2+3s+2\)。开头零系数会裁去并按剩余次数处理。仅接受真有理或恰当传递函数；非真有理系统会报错，不将 Dirac 导数画成有限曲线。
- 连续域同次数分子、分母的直接项会单独报告为 \(D\delta(t)\)。冲激响应图只画常规部分，标题会标明 delta 权重；纯直接项没有常规曲线。
- 判稳容差 \(\epsilon\) 使用严格条件：离散系统要求所有原始分母极点满足 \(|p|<1-\epsilon\)，连续系统要求 \(\operatorname{Re}(p)<-\epsilon\)。容差带内的极点标为边界极点，判稳状态为“不稳定”。这是对未约分分母的保守判据；含有不稳定公因子或零分子的模型不据此宣称输入输出传递函数的 BIBO 性质。
- 未约分分母判稳未通过时，频率图仍显示代数 \(H(e^{j\omega})\) 或 \(H(j\omega)\)，并注明约分后的传递函数性质需另行判断。恰逢极点的频率采样点留空，不伪造有限幅度。

## 符号计算与导出

启用 **计算符号逆变换** 后，程序尝试 `iztrans` 或 `ilaplace`，并与数值冲激响应逐点比较。没有安装 Symbolic Math Toolbox 时，界面明确显示该组件不可用；许可证不可用、符号计算失败或模型阶数超过 16 时，会分别显示原因并继续显示数值曲线。连续时间的零时刻对照由符号常规响应的右极限计算，Dirac 项另行报告。超过 64 阶的输入会被核心拒绝以保持交互响应。

导出按钮使用 MATLAB 原生保存对话框：

- **MAT** 保存完整 `result` 结构。
- **CSV** 保存冲激响应坐标、数值响应、可用的符号响应列和单独的 `delta_weight` 列。
- **PNG** 导出当前选中标签页的图。

编辑输入后必须重新运行分析，导出按钮会在新结果生成前保持禁用，避免保存旧结果。

## GUI 控件标签

主要控件带稳定 `Tag`，便于自动化冒烟检查：`DomainDropDown`、`NumeratorField`、`DenominatorField`、`ToleranceField`、`FrequencyMinField`、`FrequencyMaxField`、`FrequencyPointsField`、`SampleCountField`、`MaxTimeField`、`SymbolicCheckBox`、`RunAnalysisButton`、`ResetPresetButton`、`ExportMatButton`、`ExportCsvButton`、`ExportPngButton`、`ZeroPoleAxes`、`FrequencyAxes`、`ImpulseAxes`、`PoleZeroTable` 和 `SymbolicDetails`。

## 测试

在 MATLAB 中运行：

```matlab
runtests(fullfile(fileparts(which('SystemStabilityApp')), 'tests'))
```

测试覆盖指导书系数与极点、已知离散和连续冲激响应、延迟转换、公因子保留、边界和不稳定分类、连续域非真有理处理，以及符号工具箱可用时的响应对照。
