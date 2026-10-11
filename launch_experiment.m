function app = launch_experiment(number)
%LAUNCH_EXPERIMENT 独立启动一个实验，返回包含 UIFigure 的 App 对象。
%   app = launch_experiment(number)，number 为 1、2、3、4。
%   只将对应 exp 文件夹加入当前 MATLAB 会话路径，不修改永久搜索路径。
    validateattributes(number, {'numeric'}, ...
        {'scalar','real','finite','integer','>=',1,'<=',4}, mfilename, 'number');
    projectRoot = fileparts(mfilename('fullpath'));
    folder = fullfile(projectRoot, sprintf('exp%d', number));
    names = {'StatisticsExperimentApp', 'NumericalRootsApp', ...
        'ArrayPatternApp', 'SystemStabilityApp'};
    entry = names{number};
    expected = fullfile(folder, [entry '.mlapp']);
    if ~isfile(expected)
        error('ExperimentHub:MissingModule', '未找到实验 %d 的程序：%s', number, folder);
    end
    addpath(folder, '-begin');
    resolved = which(entry);
    if ~strcmpi(resolved, expected)
        error('ExperimentHub:ShadowedEntry', ...
            '入口 %s 被其他目录遮蔽。请移除同名类路径后重新运行。', entry);
    end
    app = feval(entry);
end
