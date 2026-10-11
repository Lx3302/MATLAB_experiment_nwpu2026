function report = test_project_gui(outputFolder)
%TEST_PROJECT_GUI Exercise the project hub and experiment 2-4 user interfaces.
%   report = test_project_gui(outputFolder) drives public UI callbacks, checks
%   export behavior through a scoped uiputfile shim, and writes screenshots
%   and a MAT report under outputFolder. The function restores the caller's
%   path and current folder and deletes only figures it creates.

if nargin < 1 || isempty(outputFolder)
    outputFolder = fullfile(fileparts(mfilename('fullpath')), 'output');
end
outputFolder = char(string(outputFolder));
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

projectRoot = fileparts(fileparts(mfilename('fullpath')));
helperFolder = fullfile(fileparts(mfilename('fullpath')), 'helpers');
originalPath = path;
originalFolder = pwd;
originalFigures = findall(groot, 'Type', 'figure');
global MATLAB_PROJECT_GUI_TEST_UIPUTFILE
originalSaveDialogState = MATLAB_PROJECT_GUI_TEST_UIPUTFILE;
restoreSession = onCleanup(@() restoreGuiTestSession( ...
    originalPath, originalFolder, originalFigures, originalSaveDialogState)); %#ok<NASGU>

addpath(projectRoot, helperFolder, fullfile(projectRoot, 'exp1'), ...
    fullfile(projectRoot, 'exp2'), fullfile(projectRoot, 'exp3'), ...
    fullfile(projectRoot, 'exp4'), '-begin');
clear uiputfile
rehash;
assert(strcmpi(which('uiputfile'), fullfile(helperFolder, 'uiputfile.m')), ...
    'ProjectGuiTest:SaveDialogShimNotActive', ...
    'The scoped save-dialog shim did not take precedence on the MATLAB path.');

report = struct('Passed', false, 'MATLABRelease', version('-release'), ...
    'CreatedAt', char(datetime('now')), 'Checks', {{}}, ...
    'Screenshots', {{}}, 'Exports', {{}}, 'HubFocusObservable', false, 'Error', '');
baselineOutputEntries = directoryEntries(outputFolder);
baselineProjectEntries = directoryEntries(projectRoot);

try
    %% Shared hub lifecycle and independent launcher.
    figureCountBeforeHub = numel(findall(groot, 'Type', 'figure'));
    hub = run_experiments();
    hubFigure = hub.UIFigure;
    assert(isgraphics(hubFigure), 'ProjectGuiTest:HubMissingFigure', ...
        'run_experiments did not return a visible hub figure.');
    assert(numel(findall(groot, 'Type', 'figure')) == figureCountBeforeHub + 1, ...
        'ProjectGuiTest:HubOpenedChildrenUnexpectedly', ...
        'Opening the hub must not construct child experiment windows.');

    child1 = hub.openExperiment(1);
    child2 = hub.openExperiment(2);
    child2Figure = child2.UIFigure;
    assert(isgraphics(child1.UIFigure) && isgraphics(child2Figure), ...
        'ProjectGuiTest:HubChildMissingFigure', ...
        'The hub did not return valid child figures.');
    figureCountAfterTwo = numel(findall(groot, 'Type', 'figure'));
    child2Figure.Visible = 'off';
    reopened2 = hub.openExperiment(2);
    assert(isequal(reopened2, child2) && isequal(reopened2.UIFigure, child2Figure), ...
        'ProjectGuiTest:HubDidNotReuseChild', ...
        'Opening an already-open experiment must reuse its app object and figure.');
    assert(strcmp(child2Figure.Visible, 'on'), ...
        'ProjectGuiTest:HubDidNotShowChild', ...
        'Reopening an experiment must make its existing window visible.');
    currentFigure = get(groot, 'CurrentFigure');
    report.HubFocusObservable = ~isempty(currentFigure) && ...
        isequal(currentFigure, child2Figure);
    assert(numel(findall(groot, 'Type', 'figure')) == figureCountAfterTwo, ...
        'ProjectGuiTest:HubDuplicatedChild', ...
        'Reopening an experiment created an extra figure.');

    child3 = hub.openExperiment(3);
    child4 = hub.openExperiment(4);
    assert(isgraphics(child3.UIFigure) && isgraphics(child4.UIFigure), ...
        'ProjectGuiTest:HubNewChildrenMissing', ...
        'The hub did not construct experiments 3 and 4.');
    assert(~isempty(findall(groot, 'Tag', 'exp2.MainWindow')) && ...
        ~isempty(findall(child3.UIFigure, 'Tag', 'RunButton')) && ...
        ~isempty(findall(groot, 'Tag', 'SystemStabilityAppFigure')), ...
        'ProjectGuiTest:MissingNewAppTags', ...
        'One or more new experiment windows are missing their public figure tags.');

    % Child construction must not write result files before the user runs or exports.
    assert(isequal(directoryEntries(outputFolder), baselineOutputEntries), ...
        'ProjectGuiTest:ConstructorWroteOutput', ...
        'Constructing the hub and child apps created files in the test output folder.');
    assert(isequal(directoryEntries(projectRoot), baselineProjectEntries), ...
        'ProjectGuiTest:ConstructorWroteProjectFiles', ...
        'Constructing the hub and child apps wrote files into the project root.');
    report.Screenshots{end+1} = captureApp(hubFigure, outputFolder, ...
        'hub_default_1080x720.png', [100 100 1080 720]);

    hub.UIFigure.CloseRequestFcn(hubFigure, []);
    assert(~isgraphics(hubFigure), 'ProjectGuiTest:HubCloseFailed', ...
        'Closing the hub did not close its own figure.');
    assert(isgraphics(child1.UIFigure) && isgraphics(child2Figure) && ...
        isgraphics(child3.UIFigure) && isgraphics(child4.UIFigure), ...
        'ProjectGuiTest:HubClosedChildren', ...
        'Closing the hub must leave its already-open experiment windows alive.');
    report.Checks{end+1} = 'hub construction, child reuse/focus, and independent child lifetime';

    independent2 = launch_experiment(2);
    assert(isgraphics(independent2.UIFigure) && ...
        ~isequal(independent2.UIFigure, child2Figure), ...
        'ProjectGuiTest:IndependentLaunchReusedHubChild', ...
        'launch_experiment(2) must construct an independent app window.');
    assert(isequal(pwd, originalFolder), 'ProjectGuiTest:LauncherChangedFolder', ...
        'The independent launcher changed the current folder.');
    report.Checks{end+1} = 'independent launch and current-folder preservation';

    %% Experiment 2: presets, custom complex Newton input, dirty state, parser, exports.
    app2 = child2;
    assert(isstruct(app2.Result) && isempty(fieldnames(app2.Result)), ...
        'ProjectGuiTest:Exp2ConstructorRanAnalysis', ...
        'Experiment 2 should start without a stale calculation result.');
    exp2RequiredTags = {'exp2.Run', 'exp2.Preset', 'exp2.Coefficients', ...
        'exp2.InitialReal', 'exp2.InitialImag', 'exp2.BracketLeft', ...
        'exp2.BracketRight', 'exp2.ExportMat', 'exp2.ExportCsv', ...
        'exp2.ExportPng', 'exp2.Status', 'exp2.ResultTab', ...
        'exp2.HistoryTab', 'exp2.SummaryTable', 'exp2.HistoryTable', ...
        'exp2.HeaderActions'};
    assertTags(app2.UIFigure, exp2RequiredTags);
    assertExportsDisabled(app2.UIFigure, ...
        {'exp2.ExportMat', 'exp2.ExportCsv', 'exp2.ExportPng'});

    % Both documented equation presets run through the actual button callbacks.
    invokeButton(app2.UIFigure, 'exp2.Run');
    assert(app2.Result.config.presetIndex == 1 && app2.Result.newton.converged && ...
        app2.Result.bisection.converged, 'ProjectGuiTest:Exp2PresetOne', ...
        'The first equation preset did not produce converged Newton and bisection results.');
    assertExportsEnabled(app2.UIFigure, ...
        {'exp2.ExportMat', 'exp2.ExportCsv', 'exp2.ExportPng'});
    setControlValue(app2.UIFigure, 'exp2.Preset', '方程 f₂', 'ValueChangedFcn');
    assertExportsDisabled(app2.UIFigure, ...
        {'exp2.ExportMat', 'exp2.ExportCsv', 'exp2.ExportPng'});
    assert(isstruct(app2.Result) && isempty(fieldnames(app2.Result)), ...
        'ProjectGuiTest:Exp2DirtyResultNotCleared', ...
        'Changing an experiment 2 parameter retained a stale result.');
    invokeButton(app2.UIFigure, 'exp2.Run');
    assert(app2.Result.config.presetIndex == 2 && app2.Result.newton.converged && ...
        app2.Result.bisection.converged, 'ProjectGuiTest:Exp2PresetTwo', ...
        'The second equation preset did not produce converged Newton and bisection results.');

    % A complex Newton initial value is valid even when bisection has no sign change.
    setControlValue(app2.UIFigure, 'exp2.Coefficients', '1, 0, 1', 'ValueChangedFcn');
    setControlValue(app2.UIFigure, 'exp2.InitialReal', 0, 'ValueChangedFcn');
    setControlValue(app2.UIFigure, 'exp2.InitialImag', 0.8, 'ValueChangedFcn');
    setControlValue(app2.UIFigure, 'exp2.BracketLeft', -2, 'ValueChangedFcn');
    setControlValue(app2.UIFigure, 'exp2.BracketRight', 2, 'ValueChangedFcn');
    invokeButton(app2.UIFigure, 'exp2.Run');
    assert(app2.Result.newton.converged && ...
        abs(abs(app2.Result.newton.x) - 1) < 1e-7, ...
        'ProjectGuiTest:Exp2ComplexNewton', ...
        'Newton did not converge to a complex root from a complex initial value.');
    assert(~app2.Result.bisection.converged && ...
        strcmp(app2.Result.bisection.status, 'invalid-bracket'), ...
        'ProjectGuiTest:Exp2InvalidBisection', ...
        'The no-sign-change interval was not reported as an invalid bisection bracket.');
    summaryTable2 = getControl(app2.UIFigure, 'exp2.SummaryTable');
    assert(~isempty(app2.Result.newton.history) && ~isempty(summaryTable2.Data), ...
        'ProjectGuiTest:Exp2PartialResultLost', ...
        'An invalid bisection result should retain the valid Newton result and summary.');

    % Arithmetic text is rejected as input instead of being evaluated.
    setControlValue(app2.UIFigure, 'exp2.Coefficients', '1, 1+1, 1', 'ValueChangedFcn');
    invokeButton(app2.UIFigure, 'exp2.Run');
    assert(contains(controlText(app2.UIFigure, 'exp2.Status'), '系数只能是数字'), ...
        'ProjectGuiTest:Exp2ExpressionAccepted', ...
        'Experiment 2 accepted expression syntax in the coefficient field.');
    assert(isstruct(app2.Result) && isempty(fieldnames(app2.Result)), ...
        'ProjectGuiTest:Exp2InvalidInputStaleResult', ...
        'Invalid experiment 2 input retained the prior result.');
    assertExportsDisabled(app2.UIFigure, ...
        {'exp2.ExportMat', 'exp2.ExportCsv', 'exp2.ExportPng'});
    setControlValue(app2.UIFigure, 'exp2.Coefficients', '1, 0, 1', 'ValueChangedFcn');
    invokeButton(app2.UIFigure, 'exp2.Run');
    assert(app2.Result.newton.converged, 'ProjectGuiTest:Exp2Recovery', ...
        'Experiment 2 did not recover after invalid coefficient text was corrected.');

    exp2Tabs = getControl(app2.UIFigure, 'exp2.WorkspaceTabs');
    exp2Tabs.SelectedTab = getControl(app2.UIFigure, 'exp2.ResultTab');
    report.Screenshots{end+1} = captureApp(app2.UIFigure, outputFolder, ...
        'exp2_results_1320x860.png', [100 80 1320 860]);
    exp2Tabs.SelectedTab = getControl(app2.UIFigure, 'exp2.HistoryTab');
    report.Screenshots{end+1} = captureApp(app2.UIFigure, outputFolder, ...
        'exp2_history_1024x768.png', [100 60 1024 768]);
    actions2 = getControl(app2.UIFigure, 'exp2.HeaderActions');
    assert(actions2.Layout.Row == 2, 'ProjectGuiTest:Exp2CompactHeaderLayout', ...
        'The experiment 2 header did not switch to its compact two-row layout.');
    exportRecords = exerciseExports(app2.UIFigure, 'exp2', ...
        {'exp2.ExportMat', 'exp2.ExportCsv', 'exp2.ExportPng'}, outputFolder, ...
        @() assertBusyExp2CloseGuard(app2));
    report.Exports = [report.Exports exportRecords];
    report.Checks{end+1} = 'experiment 2 presets, complex Newton, validation, recovery, layout, and exports';

    %% Experiment 3: raw and normalized/dB plots, invalid range recovery, exports.
    app3 = child3;
    exp3RequiredTags = {'RunButton', 'ElementCountField', 'AngleStartField', ...
        'AngleEndField', 'SampleCountField', 'NormalizeCheckBox', ...
        'CartesianScaleDropDown', 'StatusLabel', 'CartesianAxes', 'PolarAxes', ...
        'ExportMatButton', 'ExportCsvButton', 'ExportPngButton', ...
        'ArrayPatternAppFigure'};
    assertTags(app3.UIFigure, exp3RequiredTags);
    assert(isstruct(app3.Result) && isempty(fieldnames(app3.Result)), ...
        'ProjectGuiTest:Exp3ConstructorRanAnalysis', ...
        'Experiment 3 should start without a calculation result.');
    assertExportsDisabled(app3.UIFigure, ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'});
    invokeButton(app3.UIFigure, 'RunButton');
    assert(app3.Result.Config.ElementCount == 8 && ...
        ~app3.Result.Config.Normalize && ...
        abs(max(app3.Result.RawMagnitude) - 8) < 1e-10, ...
        'ProjectGuiTest:Exp3DefaultRawBroadside', ...
        'The default experiment 3 broadside pattern should peak at the raw N=8 amplitude.');
    assertExportsEnabled(app3.UIFigure, ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'});
    report.Screenshots{end+1} = captureApp(app3.UIFigure, outputFolder, ...
        'exp3_raw_broadside_1500x1000.png', [100 60 1500 1000]);
    report.Screenshots{end+1} = captureApp(app3.UIFigure, outputFolder, ...
        'exp3_compact_1024x768.png', [100 60 1024 768]);

    setControlValue(app3.UIFigure, 'ElementCountField', 1, 'ValueChangedFcn');
    setControlValue(app3.UIFigure, 'NormalizeCheckBox', true, 'ValueChangedFcn');
    setControlValue(app3.UIFigure, 'CartesianScaleDropDown', 'dB', 'ValueChangedFcn');
    assert(isstruct(app3.Result) && isempty(fieldnames(app3.Result)), ...
        'ProjectGuiTest:Exp3DirtyResultNotCleared', ...
        'Changing experiment 3 parameters did not invalidate the displayed result.');
    assertExportsDisabled(app3.UIFigure, ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'});
    invokeButton(app3.UIFigure, 'RunButton');
    assert(app3.Result.Config.ElementCount == 1 && ...
        app3.Result.Config.Normalize && strcmp(app3.Result.Config.CartesianScale, 'db') && ...
        max(abs(app3.Result.NormalizedMagnitude - 1)) < 1e-12 && ...
        max(abs(app3.Result.RelativeDb)) < 1e-10, ...
        'ProjectGuiTest:Exp3SingleElementNormalizedDb', ...
        'The N=1 normalized/dB display did not produce unity magnitude and 0 dB.');

    setControlValue(app3.UIFigure, 'AngleStartField', 200, 'ValueChangedFcn');
    setControlValue(app3.UIFigure, 'AngleEndField', 100, 'ValueChangedFcn');
    invokeButton(app3.UIFigure, 'RunButton');
    assert(isstruct(app3.Result) && isempty(fieldnames(app3.Result)) && ...
        contains(controlText(app3.UIFigure, 'StatusLabel'), '失败'), ...
        'ProjectGuiTest:Exp3InvalidRangeNotReported', ...
        'An invalid angle range was not rejected with a recoverable UI error.');
    assertExportsDisabled(app3.UIFigure, ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'});
    setControlValue(app3.UIFigure, 'AngleStartField', 0, 'ValueChangedFcn');
    setControlValue(app3.UIFigure, 'AngleEndField', 360, 'ValueChangedFcn');
    invokeButton(app3.UIFigure, 'RunButton');
    assert(isfield(app3.Result, 'RawMagnitude') && ...
        app3.Result.Config.ElementCount == 1, ...
        'ProjectGuiTest:Exp3RangeRecovery', ...
        'Experiment 3 did not recover after the angle range was corrected.');
    exportRecords = exerciseExports(app3.UIFigure, 'exp3', ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'}, outputFolder, ...
        @() assertBusyExp3CloseGuard(app3));
    report.Exports = [report.Exports exportRecords];
    report.Checks{end+1} = 'experiment 3 raw peak, N=1 normalization/dB, range recovery, and exports';

    %% Experiment 4: numeric and symbolic analysis in both domains, input recovery, exports.
    app4 = child4;
    exp4RequiredTags = {'RunAnalysisButton', 'DomainDropDown', 'NumeratorField', ...
        'DenominatorField', 'SymbolicCheckBox', 'StatusLabel', 'ResultTabs', ...
        'ZeroPoleTab', 'FrequencyTab', 'ImpulseTab', 'PoleZeroTable', ...
        'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'};
    assertTags(app4.UIFigure, exp4RequiredTags);
    symbolicCheckBox4 = getControl(app4.UIFigure, 'SymbolicCheckBox');
    assert(strcmp(app4.Result.domain, 'continuous') && ...
        strcmp(app4.Result.stability.classification, 'stable'), ...
        'ProjectGuiTest:Exp4ContinuousDefault', ...
        'The default continuous experiment 4 preset should be stable.');
    assert(symbolicCheckBox4.Value && app4.Result.symbolic.success, ...
        'ProjectGuiTest:Exp4ContinuousSymbolic', ...
        'The default continuous analysis did not produce a symbolic response.');
    app4Tabs = getControl(app4.UIFigure, 'ResultTabs');
    app4Tabs.SelectedTab = getControl(app4.UIFigure, 'FrequencyTab');
    report.Screenshots{end+1} = captureApp(app4.UIFigure, outputFolder, ...
        'exp4_continuous_frequency_1300x850.png', [80 60 1300 850]);

    setControlValue(app4.UIFigure, 'DomainDropDown', 'discrete', 'ValueChangedFcn');
    assertExportsDisabled(app4.UIFigure, ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'});
    guardTimer = timer('ExecutionMode', 'singleShot', 'StartDelay', 0.01, ...
        'TimerFcn', @recordExp4BusyCloseAttempt);
    guardTimer.UserData = struct('Figure', app4.UIFigure, 'Fired', false, ...
        'Survived', false, 'Status', '', 'Error', '');
    guardTimerCleanup = onCleanup(@() disposeGuiTestTimer(guardTimer)); %#ok<NASGU>
    start(guardTimer);
    invokeButton(app4.UIFigure, 'RunAnalysisButton');
    closeState = guardTimer.UserData;
    assert(closeState.Fired && closeState.Survived && ...
        contains(closeState.Status, '分析完成前无法关闭'), ...
        'ProjectGuiTest:Exp4BusyCloseGuard', ...
        'Experiment 4 did not reject a close request while analysis was busy.');
    clear guardTimerCleanup;
    assert(strcmp(app4.Result.domain, 'discrete') && ...
        strcmp(app4.Result.stability.classification, 'unstable') && ...
        ~app4.Result.stability.isStable, ...
        'ProjectGuiTest:Exp4DiscreteDefaultUnstable', ...
        'The original default discrete denominator should remain unstable.');
    assert(symbolicCheckBox4.Value && app4.Result.symbolic.success, ...
        'ProjectGuiTest:Exp4DiscreteSymbolic', ...
        'The discrete numeric/symbolic analysis did not produce its symbolic response.');
    app4Tabs.SelectedTab = getControl(app4.UIFigure, 'ImpulseTab');
    report.Screenshots{end+1} = captureApp(app4.UIFigure, outputFolder, ...
        'exp4_discrete_impulse_1024x768.png', [80 60 1024 768]);

    % The input parser accepts decimal coefficient tokens, not MATLAB expressions.
    setControlValue(app4.UIFigure, 'NumeratorField', '[0, 1+1, 0]', 'ValueChangedFcn');
    invokeButton(app4.UIFigure, 'RunAnalysisButton');
    detailsControl4 = getControl(app4.UIFigure, 'SymbolicDetails');
    details4 = detailsControl4.Value;
    assert(contains(controlText(app4.UIFigure, 'StatusLabel'), '分析失败') && ...
        contains(strjoin(cellstr(string(details4)), ' '), '只接受有限十进制数'), ...
        'ProjectGuiTest:Exp4ExpressionAccepted', ...
        'Experiment 4 accepted expression syntax in the coefficient field.');
    assertExportsDisabled(app4.UIFigure, ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'});

    % Switching domain restores a valid preset; the corrected run below
    % exercises recovery from both malformed text and an invalid range.
    setControlValue(app4.UIFigure, 'DomainDropDown', 'continuous', 'ValueChangedFcn');
    setControlValue(app4.UIFigure, 'FrequencyMaxField', 0, 'ValueChangedFcn');
    invokeButton(app4.UIFigure, 'RunAnalysisButton');
    details4 = getControl(app4.UIFigure, 'SymbolicDetails').Value;
    assert(contains(controlText(app4.UIFigure, 'StatusLabel'), '分析失败') && ...
        ~isempty(strjoin(cellstr(string(details4)), ' ')), ...
        'ProjectGuiTest:Exp4InvalidFrequencyRange', ...
        'Experiment 4 did not report an invalid frequency range.');
    assertExportsDisabled(app4.UIFigure, ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'});
    setControlValue(app4.UIFigure, 'FrequencyMaxField', 50, 'ValueChangedFcn');
    invokeButton(app4.UIFigure, 'RunAnalysisButton');
    assert(strcmp(app4.Result.domain, 'continuous') && ...
        strcmp(app4.Result.stability.classification, 'stable') && ...
        app4.Result.symbolic.success, ...
        'ProjectGuiTest:Exp4RangeRecovery', ...
        'Experiment 4 did not recover after its frequency range was corrected.');
    exportRecords = exerciseExports(app4.UIFigure, 'exp4', ...
        {'ExportMatButton', 'ExportCsvButton', 'ExportPngButton'}, outputFolder);
    report.Exports = [report.Exports exportRecords];
    report.Checks{end+1} = 'experiment 4 discrete/continuous numeric and symbolic runs, validation, recovery, and exports';

    %% Final resource and session checks.
    assert(isgraphics(child1.UIFigure) && isgraphics(child2Figure) && ...
        isgraphics(child3.UIFigure) && isgraphics(child4.UIFigure), ...
        'ProjectGuiTest:ChildClosedUnexpectedly', ...
        'An experiment window closed while exercising a sibling window.');
    clear restoreSession;
    assert(strcmp(path, originalPath), 'ProjectGuiTest:PathNotRestored', ...
        'The GUI test did not restore the caller''s MATLAB search path.');
    assert(strcmp(pwd, originalFolder), 'ProjectGuiTest:FolderNotRestored', ...
        'The GUI test did not restore the caller''s current folder.');
    report.Checks{end+1} = 'created-window cleanup and exact path/folder restoration';
    report.Passed = true;
catch exception
    report.Passed = false;
    report.Error = getReport(exception, 'extended', 'hyperlinks', 'off');
    try
        save(fullfile(outputFolder, 'project_gui_report.mat'), 'report');
    catch
        % Preserve the original GUI assertion even if the report cannot be saved.
    end
    rethrow(exception);
end

report.CreatedAt = char(datetime('now'));
save(fullfile(outputFolder, 'project_gui_report.mat'), 'report');
fprintf('PROJECT GUI CHECKS PASSED: %d checks, %d screenshots, %d export flows.\n', ...
    numel(report.Checks), numel(report.Screenshots), numel(report.Exports));
end

function handles = assertTags(parent, tags)
handles = cell(size(tags));
for k = 1:numel(tags)
    found = findall(parent, 'Tag', tags{k});
    assert(numel(found) == 1, 'ProjectGuiTest:MissingTag', ...
        'Expected exactly one UI control tagged "%s"; found %d.', tags{k}, numel(found));
    handles{k} = found(1);
end
end

function control = getControl(parent, tag)
found = findall(parent, 'Tag', tag);
assert(numel(found) == 1, 'ProjectGuiTest:MissingTag', ...
    'Expected exactly one UI control tagged "%s"; found %d.', tag, numel(found));
control = found(1);
end

function invokeButton(parent, tag)
button = getControl(parent, tag);
assert(strcmpi(button.Enable, 'on'), 'ProjectGuiTest:DisabledButton', ...
    'The requested user action "%s" is disabled.', tag);
callback = button.ButtonPushedFcn;
assert(~isempty(callback), 'ProjectGuiTest:MissingButtonCallback', ...
    'The requested user action "%s" has no callback.', tag);
feval(callback, button, []);
drawnow;
end

function setControlValue(parent, tag, value, callbackProperty)
control = getControl(parent, tag);
if strcmp(callbackProperty, 'ButtonPushedFcn')
    callback = control.ButtonPushedFcn;
    assert(~isempty(callback), 'ProjectGuiTest:MissingButtonCallback', ...
        'The requested button "%s" has no callback.', tag);
    feval(callback, control, []);
else
    control.Value = value;
    callback = control.(callbackProperty);
    assert(~isempty(callback), 'ProjectGuiTest:MissingValueCallback', ...
        'The requested value control "%s" has no %s callback.', tag, callbackProperty);
    feval(callback, control, []);
end
drawnow;
end

function text = controlText(parent, tag)
control = getControl(parent, tag);
text = char(string(control.Text));
end

function assertExportsDisabled(parent, tags)
for k = 1:numel(tags)
    control = getControl(parent, tags{k});
    assert(strcmpi(control.Enable, 'off'), 'ProjectGuiTest:ExportShouldBeDisabled', ...
        'Export action "%s" should be disabled.', tags{k});
end
end

function assertExportsEnabled(parent, tags)
for k = 1:numel(tags)
    control = getControl(parent, tags{k});
    assert(strcmpi(control.Enable, 'on'), 'ProjectGuiTest:ExportShouldBeEnabled', ...
        'Export action "%s" should be enabled.', tags{k});
end
end

function pathName = captureApp(fig, outputFolder, fileName, position)
assert(isgraphics(fig), 'ProjectGuiTest:ScreenshotFigureMissing', ...
    'Cannot capture a deleted app window.');
fig.Position = position;
fig.Visible = 'on';
figure(fig);
drawnow;
% uifigure 的标题和指数标注需要等待浏览器布局完成后再截图。
pause(1);
pathName = fullfile(outputFolder, fileName);
exportapp(fig, pathName);
assert(isfile(pathName), 'ProjectGuiTest:ScreenshotMissing', ...
    'exportapp did not create %s.', pathName);
info = imfinfo(pathName);
assert(info.Width > 0 && info.Height > 0, 'ProjectGuiTest:InvalidScreenshot', ...
    'The exported UI screenshot is empty.');
end

function records = exerciseExports(parent, prefix, tags, outputFolder, onFirstDialog)
if nargin < 5
    onFirstDialog = [];
end
records = {};
extensions = {'.mat', '.csv', '.png'};
actions = {'success', 'cancel', 'failure'};
for format = 1:numel(extensions)
    for actionIndex = 1:numel(actions)
        action = actions{actionIndex};
        fileName = sprintf('gui_%s_%s_%s%s', prefix, action, ...
            extensions{format}(2:end), extensions{format});
        if strcmp(action, 'failure')
            folder = fullfile(outputFolder, 'missing_parent_for_export_test');
            assert(~isfolder(folder), 'ProjectGuiTest:FailureFolderExists', ...
                'The intentional export-failure folder unexpectedly exists.');
        else
            folder = outputFolder;
        end
        target = fullfile(folder, fileName);
        if isfile(target)
            delete(target);
        end
        dialogState = struct('Action', action, 'File', fileName, ...
            'Folder', folder, 'Calls', 0, 'OnInvoke', []);
        if format == 1 && actionIndex == 1 && ~isempty(onFirstDialog)
            dialogState.OnInvoke = onFirstDialog;
        end
        setSaveDialogState(dialogState);
        button = getControl(parent, tags{format});
        assert(strcmpi(button.Enable, 'on'), 'ProjectGuiTest:ExportButtonUnavailable', ...
            'Export action "%s" must be enabled before its %s flow.', ...
            tags{format}, action);
        callback = button.ButtonPushedFcn;
        feval(callback, button, []);
        drawnow;
        state = getSaveDialogState();
        assert(state.Calls == 1, 'ProjectGuiTest:SaveDialogNotCalled', ...
            'Export action "%s" did not request exactly one destination.', tags{format});

        switch action
            case 'success'
                assert(isfile(target), 'ProjectGuiTest:ExportFileMissing', ...
                    'Successful %s export did not create %s.', extensions{format}, target);
                validateExportFile(target, extensions{format});
                if format == 1 && actionIndex == 1 && ~isempty(onFirstDialog)
                    assert(isgraphics(parent), 'ProjectGuiTest:BusyCloseGuardFailed', ...
                        'The close request issued during export destroyed the active window.');
                end
            case 'cancel'
                assert(~isfile(target), 'ProjectGuiTest:CancelledExportWroteFile', ...
                    'Cancelling an export created %s.', target);
            case 'failure'
                status = statusTextForApp(parent);
                assert(contains(status, '失败') || contains(status, '导出失败'), ...
                    'ProjectGuiTest:FailedExportNotReported', ...
                    'A failed export did not leave a recoverable error in the app status.');
                assert(~isfile(target), 'ProjectGuiTest:FailedExportWroteFile', ...
                    'A failed export created %s.', target);
        end
        reportExport = struct('App', prefix, 'Format', extensions{format}, ...
            'Action', action, 'Target', target);
        records{end+1} = reportExport; %#ok<AGROW>
    end
end
assertExportsEnabled(parent, tags);
end

function validateExportFile(target, extension)
switch extension
    case '.mat'
        variables = whos('-file', target);
        assert(~isempty(variables), 'ProjectGuiTest:EmptyMatExport', ...
            'The MAT export has no variables.');
    case '.csv'
        text = fileread(target);
        assert(~isempty(strtrim(text)) && contains(text, newline), ...
            'ProjectGuiTest:EmptyCsvExport', ...
            'The CSV export is empty or has no tabular rows.');
    case '.png'
        info = imfinfo(target);
        assert(info.Width > 50 && info.Height > 50, ...
            'ProjectGuiTest:EmptyPngExport', ...
            'The exported plot image is unexpectedly small.');
end
end

function value = directoryEntries(folder)
listing = dir(folder);
names = {listing.name};
names = names(~ismember(names, {'.', '..'}));
value = sort(names);
end

function setSaveDialogState(value)
global MATLAB_PROJECT_GUI_TEST_UIPUTFILE
MATLAB_PROJECT_GUI_TEST_UIPUTFILE = value;
end

function value = getSaveDialogState()
global MATLAB_PROJECT_GUI_TEST_UIPUTFILE
value = MATLAB_PROJECT_GUI_TEST_UIPUTFILE;
end

function text = statusTextForApp(fig)
status = findall(fig, 'Tag', 'exp2.Status');
if isempty(status), status = findall(fig, 'Tag', 'StatusLabel'); end
assert(numel(status) == 1, 'ProjectGuiTest:MissingStatus', ...
    'Could not locate the app status label.');
text = char(string(status.Text));
end

function assertBusyExp2CloseGuard(app)
assert(strcmpi(getControl(app.UIFigure, 'exp2.Run').Enable, 'off') && ...
    strcmpi(getControl(app.UIFigure, 'exp2.Preset').Enable, 'off'), ...
    'ProjectGuiTest:Exp2BusyControlsEnabled', ...
    'Experiment 2 inputs and run actions remained enabled during export.');
app.UIFigure.CloseRequestFcn(app.UIFigure, []);
assert(isgraphics(app.UIFigure) && ...
    contains(controlText(app.UIFigure, 'exp2.Status'), '完成后才能关闭'), ...
    'ProjectGuiTest:Exp2BusyCloseGuard', ...
    'Experiment 2 did not reject a close request while an export was busy.');
end

function assertBusyExp3CloseGuard(app)
app.UIFigure.CloseRequestFcn(app.UIFigure, []);
assert(isgraphics(app.UIFigure) && ...
    contains(controlText(app.UIFigure, 'StatusLabel'), '操作进行中'), ...
    'ProjectGuiTest:Exp3BusyCloseGuard', ...
    'Experiment 3 did not reject a close request while an export was busy.');
end

function recordExp4BusyCloseAttempt(timerObject, ~)
state = timerObject.UserData;
state.Fired = true;
try
    fig = state.Figure;
    if isgraphics(fig)
        fig.CloseRequestFcn(fig, []);
        state.Survived = isgraphics(fig);
        status = findall(fig, 'Tag', 'StatusLabel');
        if numel(status) == 1
            state.Status = char(string(status.Text));
        end
    end
catch exception
    state.Error = exception.message;
end
timerObject.UserData = state;
end

function disposeGuiTestTimer(timerObject)
try
    if isvalid(timerObject)
        if strcmpi(timerObject.Running, 'on')
            stop(timerObject);
        end
        delete(timerObject);
    end
catch
end
end

function restoreGuiTestSession(originalPath, originalFolder, originalFigures, originalSaveDialogState)
global MATLAB_PROJECT_GUI_TEST_UIPUTFILE
currentFigures = findall(groot, 'Type', 'figure');
for k = 1:numel(currentFigures)
    current = currentFigures(k);
    existed = false;
    for j = 1:numel(originalFigures)
        if isequal(current, originalFigures(j))
            existed = true;
            break;
        end
    end
    if ~existed && isgraphics(current)
        try
            delete(current);
        catch
            % Keep cleanup focused on test-created figures; never touch user figures.
        end
    end
end
MATLAB_PROJECT_GUI_TEST_UIPUTFILE = originalSaveDialogState;
try
    path(originalPath);
catch
end
try
    if ~strcmp(pwd, originalFolder)
        cd(originalFolder);
    end
catch
end
clear uiputfile
end
