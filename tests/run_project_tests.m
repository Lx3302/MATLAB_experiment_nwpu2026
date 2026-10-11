function report = run_project_tests(includeGUI)
%RUN_PROJECT_TESTS 运行实验一至四的算法测试及公共入口集成测试。
%   report = run_project_tests(false) 只运行算法/文件服务测试。
%   在独立 MATLAB 会话中运行。输出写入 tests/output，不修改正式输入文件。
    if nargin < 1, includeGUI = true; end
    validateattributes(includeGUI, {'logical','numeric'}, {'scalar'});
    testFolder = fileparts(mfilename('fullpath'));
    root = fileparts(testFolder);
    originalPath = path;
    restorePath = onCleanup(@() path(originalPath));
    originalFolder = pwd;
    restoreFolder = onCleanup(@() cd(originalFolder));
    cd(root);
    folders = cellfun(@(k) fullfile(root,k), {'exp1','exp2','exp3','exp4'}, ...
        'UniformOutput',false);
    addpath(root,testFolder,folders{:});
    output = fullfile(testFolder,'output');
    if ~isfolder(output), mkdir(output); end
    testFiles = {fullfile(root,'exp1','tests','test_math_core.m'), ...
        fullfile(root,'exp1','tests','test_backend_services.m'), ...
        fullfile(root,'exp2','tests','test_exp2.m'), ...
        fullfile(root,'exp3','tests','test_exp3.m'), ...
        fullfile(root,'exp4','tests','test_exp4.m')};
    results = runtests(testFiles);
    report = struct('MATLABRelease',version('-release'), ...
        'CreatedAt',char(datetime('now')), 'UnitTestCount',numel(results), ...
        'UnitPassed',sum([results.Passed]), 'AllPassed',false, ...
        'GUIRequested',logical(includeGUI));
    report.UnitResults = table(results);
    save(fullfile(output,'verification.mat'),'report');
    assert(all([results.Passed]), 'ProjectTests:UnitFailure', ...
        '有算法或服务测试失败，请查看 tests/output/verification.mat。');

    if includeGUI
        report.AppDesigner = verify_app_designer_files;
        % 各模块单元测试自行清理路径，此处显式恢复正式模块入口。
        addpath(folders{:}, fullfile(root,'exp1','tests'));
        verify_staged_app(fullfile(root,'exp1'));
        report.Experiment1GUI = test_app_integration( ...
            fullfile(root,'exp1','StatisticsExperimentApp.mlapp'));
        report.ProjectGUI = test_project_gui(output);
        assert(report.Experiment1GUI.Passed && report.ProjectGUI.Passed, ...
            'ProjectTests:GUIFailure','界面集成测试未通过。');
    end
    report.AllPassed = true;
    save(fullfile(output,'verification.mat'),'report');
    fprintf('PROJECT CHECKS PASSED: %d tests; GUI=%d; MATLAB %s.\n', ...
        report.UnitTestCount,includeGUI,report.MATLABRelease);
end
