# 实验二：非线性方程求根

本模块分别用 Newton 法和二分法求解指导书中的多项式，并以 `roots` 返回的全部根作数值校验。界面是 App Designer 文件 `NumericalRootsApp.mlapp`；求解函数是独立数值 API，可直接从 MATLAB 命令行调用，不需要创建界面。

## 运行界面

在 MATLAB R2024b 中切换到 `exp2` 目录，然后运行：

```matlab
app = NumericalRootsApp;
```

编辑界面请使用 App Designer：

```matlab
appdesigner('NumericalRootsApp.mlapp')
```

保存 `.mlapp` 后，在项目根目录运行 `addpath('tools'); export_app_sources`，同步生成的 `exp2/src/NumericalRootsApp.m` 仅用于审阅和差异比较。运行应用时不要将 `src` 加入路径。

左侧可选方程预设，或编辑按降幂排列的实系数，例如 `1, -5, -12, 76, -79`。Newton 初值的实部和虚部分开输入；二分法使用两个实端点。两种方法每次一起运行。图像页显示函数曲线、实根和迭代残差；结果页列出近似根、方法状态及 `roots(coefficients)` 的复根验证；迭代页显示逐步数据。

运行完成后可保存完整 MAT 结果、当前方法的迭代 CSV 或函数图 PNG。参数修改后需重新运行，避免把旧结果误当作新参数的计算结果。输入系数只接受有限实数，按逗号、空格或分号分隔，不执行 MATLAB 表达式。

## GUI-free API

```matlab
config = exp2_defaults(1);  % 1: f1；2: f2
result = exp2_solve(config);

f = @(x) x.^2 + 1;
df = @(x) 2 .* x;
options = struct('xTolerance', 1e-10, ...
    'residualTolerance', 1e-10, 'maxIterations', 100);
newton = newton_root(f, df, 1 + 1i, options);
bisection = bisect_root(@(x) x.^2 - 2, [1 2], options);
```

`exp2_defaults` 返回两个方程预设和一组可直接运行的配置。`exp2_solve` 根据降幂系数创建多项式及其导数函数句柄，再分别调用 Newton 和二分法。Newton 支持复数初值；二分法要求实函数值和有限实端点，并检查端点根、端点顺序和异号条件。

| 配置字段 | 含义与单位 | f₁ 默认值 | f₂ 默认值 |
| --- | --- | --- | --- |
| `coefficients` | 按 x 降幂排列的有限实数系数 | `[1 -5 -12 76 -79]` | `[1 -8 17 -10]` |
| `initialX` | Newton 复初值；实部和虚部单位均为 x | `1.8 + 0i` | `2.1 + 0i` |
| `bracket` | 二分法实区间 `[a b]`，单位为 x | `[1.7 1.8]` | `[1.9 2.1]` |
| `xTolerance` | 相对 x 容差，无量纲 | `1e-10` | `1e-10` |
| `residualTolerance` | 绝对函数残差容差，单位与 f(x) 相同 | `1e-10` | `1e-10` |
| `maxIterations` | 每种方法最多迭代次数 | `100` | `100` |
| `plotBounds` | 函数图的实数 x 范围 | `[-5 6]` | `[0 6]` |

二分法在残差满足容差**或**半区间宽度满足相对 x 容差时报告收敛；Newton 以残差容差作为成功条件，步长已很小但残差仍超限时报告停滞。两种方法的 `status` 和 `message` 会分别说明收敛、端点同号、导数为零、停滞、非有限值或达到迭代上限等情况。

GUI 返回 App 对象，窗口句柄为 `app.UIFigure`；`app.Result` 保存最近一次完整计算的结果，运行前为空，运行后与 `exp2_solve` 返回的结果结构一致。修改输入后旧结果失效，需重新运行才能导出。

结果结构体包含标准化后的 `config`、`newton`、`bisection`、`verificationRoots` 和对应的 `verificationResiduals`。两个算法结果各自保留 `x`、`fValue`、`residual`、`iterations`、`converged`、`status`、`message` 和 `history`。状态不会把失败误报成收敛；Newton 的小步长但大残差会报告停滞，二分法端点函数值同号会报告无效区间。每条 `history` 记录迭代编号、当前点、函数值、残差、步长或半区间和二分端点。

方程为：

```text
f1(x) = x^4 - 5x^3 - 12x^2 + 76x - 79
f2(x) = x^3 - 8x^2 + 17x - 10
```

## 测试

从 `exp2` 目录运行 MATLAB 单元测试：

```matlab
addpath('tests')
results = runtests('tests/test_exp2.m');
assertSuccess(results)
```

测试覆盖两个预设方程、已知三次方程根、二分端点根与无效区间、复数 Newton 初值、导数为零、迭代上限、单方法失败时保留另一方法结果，以及非法系数校验。
