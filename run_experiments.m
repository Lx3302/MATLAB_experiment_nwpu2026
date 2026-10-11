function app = run_experiments
%RUN_EXPERIMENTS 打开实验一至四的公共入口。
%   app = run_experiments 返回公共界面对象；关闭公共界面不关闭独立实验。
%   不使用 genpath，避免 exp1/src 与测试替身遮蔽正式 App Designer 类。
    app = MatlabExperimentHub;
end
