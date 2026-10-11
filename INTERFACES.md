# 实验模块接口

`MatlabExperimentHub.mlapp` 只负责导航和窗口管理。四个实验的 App Designer `.mlapp` 界面负责读取参数、显示状态、绘图和保存；数值计算函数只接收普通参数并返回结果结构体，不接收 App、窗口或坐标轴句柄。每个 `.mlapp` 在相邻 `src/` 目录有一份可审阅的 MATLAB 文本副本；运行时使用 `.mlapp`。

## 公共入口

```matlab
hub = run_experiments;           % 打开 MatlabExperimentHub.mlapp
app = hub.openExperiment(2);   % 重复调用唤回同一窗口
app = launch_experiment(3);    % 每次调用新建独立窗口
```

| 接口 | 输入 | 输出与职责 |
| --- | --- | --- |
| `run_experiments` | 无 | `MatlabExperimentHub` 对象，打开公共导航 |
| `hub.selectExperiment(k)` | 整数 1–4 | 切换选中的实验 |
| `hub.openExperiment(k)` | 整数 1–4，可省略使用当前选择 | 返回对应实验 App，已打开时唤回窗口 |
| `launch_experiment(k)` | 整数 1–4 | 新建对应实验 App |
| `app.UIFigure` | 公开属性 | MATLAB 图窗句柄，可用于窗口管理 |

启动器只将相应的 `expN` 目录加入当前会话路径，不调用 `savepath`，不切换当前文件夹。不要使用 `addpath(genpath(...))`：`src` 文本副本和测试替身目录可能遮蔽正式入口。关闭公共入口保留已打开的独立实验窗口。

## 各实验

| 实验 | 独立 GUI | 无 GUI 计算接口 | 详细说明 |
| --- | --- | --- | --- |
| 一 | `exp1/StatisticsExperimentApp.mlapp` | `StatisticsExperimentMath.runSimulation(...)`、`analyzeAudio(...)` | [实验一接口](exp1/docs/接口说明.txt) |
| 二 | `exp2/NumericalRootsApp.mlapp` | `exp2_defaults`、`exp2_solve`、`newton_root`、`bisect_root` | [实验二接口](exp2/README.md) |
| 三 | `exp3/ArrayPatternApp.mlapp` | `exp3_defaults`、`exp3_pattern` | [实验三接口](exp3/README.md) |
| 四 | `exp4/SystemStabilityApp.mlapp` | `exp4_defaults`、`exp4_analyze` | [实验四接口](exp4/README.md) |

各实验保存自身的参数与计算结果，互相之间没有数值计算依赖。可单独复制任一 `expN` 文件夹运行；实验一还需保留 `StatisticsExperimentMath.m`。App Designer 编辑 `.mlapp` 后，用项目根目录的 `tools/export_app_sources` 同步 `src/` 文本副本；不要把 `src/` 加入应用运行路径。

## 指导书与实现约定

- 实验二选择内容 1：两道多项式、牛顿法与二分法、函数句柄、函数图、迭代过程、`roots` 验证。
- 实验三选择内容 1：均匀线列阵指向性，直角坐标与极坐标同时展示。指导书公式的峰值是阵元数 N，默认保留原始幅度；归一化与扫描角为可选扩展。
- 实验四完成离散、连续两题及选做的符号脉冲／冲激响应。连续系统原图分母首项印为 `z^4`，根据 `H(s)` 和其余各项按 `s^4` 实现。离散系统参数原样保留，不能为获得稳定结果而更改系数。
- 公共入口和四个实验界面都使用 App Designer `.mlapp` 设计文件。`src/*.m` 是同步导出的审阅副本；界面编辑应在 App Designer 中完成，再用 `tools/export_app_sources` 更新副本。

指导书提到的 GUIDE 是旧界面设计工具。项目使用 App Designer；MathWorks 已在 R2025a 移除 GUIDE 设计环境，参见 [GUIDE 迁移说明](https://www.mathworks.com/help/matlab/creating_guis/gui-options.html)。
