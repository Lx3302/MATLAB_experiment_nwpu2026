# MATLAB 实验 · NWPU 2026

实验一统计仿真与音频分析 GUI，使用 MATLAB App Designer 构建。

## 运行

已在 **MATLAB R2024b** 验证。克隆仓库后，在 MATLAB 中切换到仓库根目录：

```matlab
cd exp1
StatisticsExperimentApp
```

要编辑界面和回调：

```matlab
appdesigner('StatisticsExperimentApp.mlapp')
```

`StatisticsExperimentApp.mlapp` 和 `StatisticsExperimentMath.m` 必须保持在同一目录。
无需安装额外统计工具箱；音频解码格式以当前 MATLAB 环境支持的格式为准。

## 实验功能

- 随机变量求和：独立生成 `m` 个 `U(0,1)` 变量并求和，重复 `N` 次；`m`、`N` 均可自定义。
- 拟合对比：同时显示经验概率密度、样本参数高斯拟合及理论参数高斯近似。
- 分箱设置：选择区间数或实际区间宽度；总随机数数量上限为 `1e8`，区间数上限为 `5000`。
- 音频分析：左右声道分别处理，支持输入起止秒数，预览所选时间段后点击“开始分析”。
- 结果展示：均值、样本方差、标准差和 RMS 分别显示；窗口缩小时切换为可滚动布局。
- 数据与图像：保存完整 MAT 结果或 CSV 样本和统计表；导出 PNG / PDF 分析图。

时间段采用左闭右开区间 `[t0,t1)`，统计使用全部选中样本；仅波形预览抽取数据。
方差使用 `N-1` 归一化。单声道文件保留单声道，超过两声道时分析前两个声道。

## 项目结构

```text
exp1/
├── StatisticsExperimentApp.mlapp   # App Designer 主文件
├── StatisticsExperimentMath.m      # 计算、音频读取、保存与导出接口
├── src/StatisticsExperimentApp.m   # 与 .mlapp 同步的文本源码，供 Git 审阅
├── docs/接口说明.txt                # 参数、单位、结构体和职责边界
├── tests/                         # 数学、服务、GUI 回调和设计器模型检查
└── tools/export_frontend.m         # 保存 .mlapp 后同步导出文本源码
```

## 修改与提交

界面和回调以 `.mlapp` 为准，算法和文件功能在 `StatisticsExperimentMath.m` 中维护。
App Designer 保存后，在 `exp1` 目录执行：

```matlab
addpath('tools')
export_frontend
```

导出统一使用 LF 换行并清理行尾空白。同时提交 `.mlapp` 与导出的 `.m`，让 Git 能审阅
前端代码变化。不要把 `src` 或测试对话框
替身目录加入日常运行路径，也不要对整个仓库使用 `addpath(genpath(...))`，以免同名类或
测试函数遮蔽正式入口。测试脚本会按需配置并恢复路径。

提交信息采用 Conventional Commits，例如 `feat(exp1): add audio window analysis`、
`fix(exp1): preserve app window after export`。备份、测试输出、录音和临时日志不进入版本库。

## 验证

建议在独立 MATLAB 会话中，从仓库根目录执行：

```matlab
addpath(fullfile(pwd, 'exp1', 'tests'))
run_all_tests
```

检查包含 18 项数学和服务测试、真实 `.mlapp` 的自定义样本数/区间宽度、App Designer
模型加载与源码同步，以及保存成功/取消/失败恢复、忙碌时关闭保护、单/双声道切换和
重复导入分析。GUI 回调测试使用自动生成的 WAV 数据和确定性的文件对话框替身。
测试结果保存在被 Git 忽略的 `exp1/tests/output/`。

测试范围为 MATLAB 中的模型加载和回调执行；不包含对 App Designer 编辑器的自动点击操作。

## 许可证

遵循仓库的 [MIT License](LICENSE)。
