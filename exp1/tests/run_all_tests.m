function report = run_all_tests
%RUN_ALL_TESTS Validate the cloned package without machine-specific paths.
%   Run in a dedicated MATLAB session; only this app's figures are closed.
    testDirectory = fileparts(mfilename('fullpath'));
    experimentRoot = fileparts(testDirectory);
    oldPath = path;
    pathCleanup = onCleanup(@() path(oldPath));
    oldFolder = pwd;
    folderCleanup = onCleanup(@() cd(oldFolder));
    addpath(experimentRoot, testDirectory);
    cd(experimentRoot);
    outputDirectory = fullfile(testDirectory, 'output');
    if ~isfolder(outputDirectory), mkdir(outputDirectory); end

    unitResults = runtests({fullfile(testDirectory,'test_math_core.m'), ...
        fullfile(testDirectory,'test_backend_services.m')});
    assert(all([unitResults.Passed]), 'A math or backend service test failed.');
    verify_staged_app(experimentRoot);
    guiReport = test_app_integration(fullfile(experimentRoot,'StatisticsExperimentApp.mlapp'));
    assert(guiReport.Passed);
    report = struct('UnitTestCount',numel(unitResults), 'AllPassed',true, ...
        'GuiReport',guiReport, 'MATLABRelease',version('-release'));
    save(fullfile(outputDirectory,'verification.mat'), 'report');
    fprintf('ALL CHECKS PASSED: %d math/service tests plus MLAPP and GUI flows.\n', ...
        report.UnitTestCount);
end
