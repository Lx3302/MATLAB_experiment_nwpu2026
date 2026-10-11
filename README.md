# MATLAB 实验 · NWPU 2026

本项目按《实验指导书》组织实验一至四。实验二选择内容 1，实验三选择内容 1，实验四包含全部题目及符号脉冲／冲激响应。公共入口和四个实验窗口均为 App Designer `.mlapp` 应用；每个实验的数值 API 与界面分离，可独立调用。

## 运行

在 MATLAB 中切换到本项目目录：

```matlab
cd('G:\MATLAB\MATLAB_experiment_nwpu2026')
run_experiments
```

公共入口左侧选择实验，点击“打开实验”。可以同时打开多个实验；再次打开会返回现有窗口。关闭公共入口会保留各实验窗口。公共入口源文件为 `MatlabExperimentHub.mlapp`，可单独打开：

```matlab
appdesigner('MatlabExperimentHub.mlapp')
```

也可以直接启动指定实验：

```matlab
app1 = launch_experiment(1);
app2 = launch_experiment(2);
app3 = launch_experiment(3);
app4 = launch_experiment(4);
```

各 `expN` 文件夹可独立运行。例如仅打开实验三：

```matlab
cd exp3
ArrayPatternApp
```

基准环境为 MATLAB R2024b。实验一至三和实验四的数值部分使用基础 MATLAB；实验四的 `iztrans` / `ilaplace` 使用 Symbolic Math Toolbox。无符号工具箱时仍可完成数值计算，界面明确显示符号功能不可用。

## 实验功能

| 实验 | 内容 | 可调整参数与结果 |
| --- | --- | --- |
| 一 | 统计仿真与音频分析 | 求和项数、试验次数、分箱、音频区间；波形、概率密度、拟合与统计量 |
| 二 · 内容 1 | 牛顿法、二分法求根 | 两道题及自定义系数、实/复初值、区间、误差、迭代上限；过程图、残差与 `roots` 验证 |
| 三 · 内容 1 | 均匀线列阵指向性 | 阵元数、阵元间距、波长、扫描角、角度采样、幅度尺度；直角坐标与极坐标图 |
| 四 · 全部 | 离散、连续系统分析 | 分子/分母系数、频率与时间范围、稳定性容差；零极点、稳定性、幅频响应、脉冲/冲激响应与符号表达式 |

各 GUI 支持保存数据和图形。详细参数、字段、单位、停止条件和异常约定见 [总接口说明](INTERFACES.md) 及各实验的 README。

实验四保留指导书离散系统的原始系数，其稳定性由程序实际计算。连续系统分母原图首项印成 `z^4`，本项目根据 `H(s)` 和其余各项按 `s^4` 处理。

## 目录与接口

```text
MatlabExperimentHub.mlapp               # 公共导航与窗口管理
run_experiments.m / launch_experiment.m # 公共入口与指定实验启动接口
src/MatlabExperimentHub.m                # .mlapp 的可审阅文本副本
exp1/StatisticsExperimentApp.mlapp       # 统计仿真与音频分析
exp2/NumericalRootsApp.mlapp             # 求根界面与独立数值 API
exp3/ArrayPatternApp.mlapp               # 阵列方向图界面与独立数值 API
exp4/SystemStabilityApp.mlapp            # 系统分析界面与独立数值 API
expN/src/                                # 各 App 的可审阅文本副本
INTERFACES.md                            # 模块边界和接口索引
tests/                                   # 跨实验集成与界面验证
```

计算函数与 GUI 分离；命令行调用不需要启动或创建 App 对象。无 GUI 使用示例：

```matlab
addpath('exp1','exp2','exp3','exp4')
statisticsResult = StatisticsExperimentMath.runSimulation(100, 10000, 'count', 60);
rootsResult = exp2_solve(exp2_defaults);
patternResult = exp3_pattern(exp3_defaults);
systemResult = exp4_analyze(exp4_defaults('discrete'));
```

数值实现的主要步骤如下，完整输入、输出和误差约定见各实验接口说明。

| 实验 | 数值实现 |
| --- | --- |
| 一 | 分块生成均匀随机变量并求和，计算样本均值、无偏方差和概率密度，与高斯拟合及理论均值 `m/2`、方差 `m/12` 对照；音频按选定时间窗分析。 |
| 二 | `polyval` / `polyder` 构造函数句柄，独立实现 Newton 迭代和二分区间收缩，记录每步残差与停止原因，再用 `roots` 核验。 |
| 三 | 直接计算均匀线阵阵列因子，在分子分母同时为零处使用解析极限 `N`，生成原始、归一化和相对 dB 幅度。 |
| 四 | 用 `roots` 计算零极点，以单位圆／左半平面判断因果系统稳定性；计算代数频率响应，以 `filter` 计算离散脉冲响应，以状态空间矩阵指数计算连续冲激响应，另以 `iztrans` / `ilaplace` 核验。 |

界面使用：实验一切换“随机数仿真／音频分析”并运行；实验二选择方程、初值和区间后点击“运行两种方法”；实验三设置阵列与角度参数后点击“计算方向图”；实验四选择离散域或连续域，检查系数后点击“运行分析”，在零极点、频率响应和冲激响应页查看结果。各窗口的导出按钮保存当前计算结果，修改参数后需要重新计算。

- [实验一接口](exp1/docs/接口说明.txt)
- [实验二接口](exp2/README.md)
- [实验三接口](exp3/README.md)
- [实验四接口](exp4/README.md)

## 验证

在独立 MATLAB 会话中从项目根目录执行：

```matlab
addpath('tests')
report = run_project_tests;        % 算法、原实验一、公共入口与 GUI 流程
designerReport = test_app_designer_roundtrip; % 在副本上验证设计器保存与运行
```

只运行算法和文件服务测试可使用 `run_project_tests(false)`。测试输出保存在 `tests/output` 与各实验的测试输出目录，不会加入版本控制。

已在 MATLAB R2024b 验证：51 项算法／文件服务测试、实验一 30 项界面流程、公共入口及实验二至四的 6 组界面检查与 27 项导出流程，以及五个 `.mlapp` 在 App Designer 中重新保存后的控件生成、启动和回调。

## 维护 App Designer 界面

公共入口与四个实验界面均以 `.mlapp` 为设计源文件，可以在 Design View 中编辑布局、在 Code View 中编辑回调。实验三的极坐标轴由启动回调创建于可编辑的网格容器，详见 [实验三说明](exp3/README.md)。以实验二为例：

```matlab
appdesigner('exp2/NumericalRootsApp.mlapp')
```

保存 `.mlapp` 后，在项目根目录同步可审阅的 `.m` 文本副本：

```matlab
addpath('tools');
export_app_sources
```

将 `.mlapp` 与对应的 `src/*.m` 审阅副本一起提交。`src/` 只用于代码审阅和版本比较，不作为应用入口。实验一的数学服务位于 `exp1/StatisticsExperimentMath.m`，其接口见 [实验一接口](exp1/docs/接口说明.txt)。

不要将 `src`、各 `expN/src` 或测试对话框替身目录加入日常路径，也不要对整个仓库使用 `addpath(genpath(...))`。测试会按需配置并恢复路径。指导书中的 GUIDE 设计环境已由 App Designer 替代，背景见 [MathWorks 说明](https://www.mathworks.com/help/matlab/creating_guis/gui-options.html)。

原实验一完整测试入口仍可使用：在 `exp1` 目录执行 `addpath('tests'); run_all_tests`。音频时间窗为左闭右开 `[t0,t1)`；统计使用全部选中样本，方差按 `N-1` 归一化，超过两个声道时分析前两路。

## 许可证

遵循 [MIT License](LICENSE)。
