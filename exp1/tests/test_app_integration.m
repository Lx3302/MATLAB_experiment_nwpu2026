function report = test_app_integration(applicationFile)
% Exercise the real public component callback handles in an isolated MATLAB process.
% Dialog shims use globals only for queued return values; they never retain the app.
probeDir = fileparts(mfilename('fullpath'));
if nargin < 1
    applicationFile = fullfile(fileparts(probeDir), 'StatisticsExperimentApp.mlapp');
end
dialogDir = fullfile(probeDir, 'helpers', 'dialogs');
outputDir = fullfile(probeDir, 'output', ['lifecycle_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
mkdir(outputDir);
oldPath = path;
restorePath = onCleanup(@() path(oldPath));
restoreGlobals = onCleanup(@() clearTestGlobals());
global STATAPP_LIFECYCLE_UIGET_QUEUE STATAPP_LIFECYCLE_UIPUT_QUEUE STATAPP_LIFECYCLE_CLOSE_DURING_PUT;
STATAPP_LIFECYCLE_UIGET_QUEUE = {};
STATAPP_LIFECYCLE_UIPUT_QUEUE = {};
STATAPP_LIFECYCLE_CLOSE_DURING_PUT = [];
oldFolder = pwd;
restoreFolder = onCleanup(@() cd(oldFolder));
appDir = fileparts(applicationFile);
assert(isfolder(appDir) && isfile(applicationFile), 'Application file is missing: %s', applicationFile);
cd(appDir);
addpath(appDir, '-begin');
addpath(dialogDir, '-begin');
rehash;
clear StatisticsExperimentApp StatisticsExperimentMath
resolvedApp = which('StatisticsExperimentApp');
resolvedMath = which('StatisticsExperimentMath');
[~,~,extension] = fileparts(applicationFile);
if strcmpi(extension, '.m')
    assert(strcmpi(resolvedApp, applicationFile), 'Wrong app resolved: %s', resolvedApp);
    mathFile = fullfile(appDir, 'StatisticsExperimentMath.m');
    assert(strcmpi(resolvedMath, mathFile), 'Wrong math class resolved: %s', resolvedMath);
else
    assert(strcmpi(resolvedApp, applicationFile), 'Wrong packaged app resolved: %s', resolvedApp);
    mathFile = fullfile(appDir, 'StatisticsExperimentMath.m');
    assert(isfile(mathFile), 'StatisticsExperimentMath.m is missing beside the package.');
    assert(strcmpi(resolvedMath, mathFile), ...
        'Wrong package math class resolved: expected %s, got %s', mathFile, resolvedMath);
end
assert(contains(which('uigetfile'), dialogDir), 'uigetfile test shim is not active.');
assert(contains(which('uiputfile'), dialogDir), 'uiputfile test shim is not active.');

priorFigures = findall(groot, 'Type', 'figure');
launchError = '';
try
    if strcmpi(extension, '.mlapp')
        appdesigner.internal.service.AppManagementService.runApp(applicationFile);
    else
        eval('StatisticsExperimentApp;'); % no-output command-window constructor path
    end
catch exception
    launchError = getReport(exception, 'extended', 'hyperlinks', 'off');
end
assert(isempty(launchError), 'Application launch failed:\n%s', launchError);
allFigures = findall(groot, 'Type', 'figure');
newFigures = allFigures(~ismember(allFigures, priorFigures));
assert(numel(newFigures) == 1, 'Expected one new UIFigure; found %d.', numel(newFigures));
uiFigure = newFigures(1);
cleanupFigure = onCleanup(@() cleanupOwnedFigure(uiFigure));
assert(isprop(uiFigure, 'RunningAppInstance'), 'registerApp did not retain the running app on its UIFigure.');
assert(isvalid(uiFigure.RunningAppInstance), 'The no-output app instance was not retained.');
assert(strcmp(class(uiFigure.RunningAppInstance), 'StatisticsExperimentApp'), 'Unexpected app class on UIFigure.');
uiFigure.Visible = 'off';
report = struct('ApplicationFile', applicationFile, 'ResolvedApp', resolvedApp, ...
    'ResolvedMath', resolvedMath, 'OutputDirectory', outputDir, 'Passed', false, 'Events', {{}});
if strcmpi(extension, '.mlapp')
    record('staged MLAPP launch and RunningAppInstance retention');
else
    record('no-output source launch and RunningAppInstance retention');
end

% Simulation result exercises data and image dialogs in every supported format.
invokeButton(uiFigure, 'NavigationSimulation');
assert(strcmp(readValue(uiFigure, 'SimPage', 'Visible'), 'on'), 'Simulation navigation did not show its page.');
setValue(uiFigure, 'TermsEditField', 4);
setValue(uiFigure, 'TrialsEditField', 5000);
invokeButton(uiFigure, 'RunSimButton');
assertAlive(uiFigure, 'simulation callback');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'on'), 'Simulation result did not enable SaveDataButton.');
assertNoExtraFigures(uiFigure, priorFigures, 'simulation'); record('simulation');

queuePut(0, 0); invokeButton(uiFigure, 'SaveDataButton');
assertAlive(uiFigure, 'cancel simulation MAT save'); record('cancel simulation data save');
simMat = fullfile(outputDir, 'simulation.mat');
queuePut('simulation.mat', outputDir); invokeButton(uiFigure, 'SaveDataButton');
assertFile(simMat, 'simulation MAT');
simLoaded = load(simMat, 'result');
assert(strcmp(simLoaded.result.Kind, 'simulation'), 'Simulation MAT contains an unexpected result kind.');
assertAlive(uiFigure, 'simulation MAT save'); record('simulation MAT save');

% A close request during the modal save callback must be ignored while Busy.
busyCloseMat = fullfile(outputDir, 'busy_close.mat');
queuePut('busy_close.mat', outputDir, uiFigure); invokeButton(uiFigure, 'SaveDataButton');
assertFile(busyCloseMat, 'busy-close simulation MAT');
assertAlive(uiFigure, 'close request during busy save'); record('Busy close request ignored during save');

% A failed write must report through the callback and leave the app usable.
missingDir = fullfile(outputDir, 'directory_that_does_not_exist');
queuePut('must_fail.mat', missingDir); invokeButton(uiFigure, 'SaveDataButton');
assertAlive(uiFigure, 'failed simulation save');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'on'), 'Failed save left the app in a busy state.');
record('failed save path handled without closing app');
recoveryMat = fullfile(outputDir, 'recovered_after_failure.mat');
queuePut('recovered_after_failure.mat', outputDir); invokeButton(uiFigure, 'SaveDataButton');
assertFile(recoveryMat, 'save after failed path');
assertAlive(uiFigure, 'save after failed path'); record('successful save after failure');

simCsv = fullfile(outputDir, 'simulation.csv');
queuePut('simulation.csv', outputDir); invokeButton(uiFigure, 'SaveDataButton');
assertFile(simCsv, 'simulation CSV');
assertFile(fullfile(outputDir, 'simulation_statistics.csv'), 'simulation statistics CSV');
simTable = readtable(simCsv, 'VariableNamingRule', 'preserve');
assert(isequal(simTable.Properties.VariableNames, {'Trial','Sum'}), 'Unexpected simulation CSV columns.');
assertAlive(uiFigure, 'simulation CSV save'); record('simulation CSV save');

queuePut(0, 0); invokeButton(uiFigure, 'SaveFigureButton');
assertAlive(uiFigure, 'cancel simulation figure export'); record('cancel simulation figure export');
simPng = fullfile(outputDir, 'simulation.png');
queuePut('simulation.png', outputDir); invokeButton(uiFigure, 'SaveFigureButton');
assertFile(simPng, 'simulation PNG');
assertAlive(uiFigure, 'simulation PNG export'); assertNoExtraFigures(uiFigure, priorFigures, 'simulation PNG export'); record('simulation PNG export');
simPdf = fullfile(outputDir, 'simulation.pdf');
queuePut('simulation.pdf', outputDir); invokeButton(uiFigure, 'SaveFigureButton');
assertFile(simPdf, 'simulation PDF');
assertAlive(uiFigure, 'simulation PDF export'); assertNoExtraFigures(uiFigure, priorFigures, 'simulation PDF export'); record('simulation PDF export');

% Import cancellation, stereo analysis, invalid-window recovery, then mono/stereo reselection.
invokeButton(uiFigure, 'NavigationAudio');
assert(strcmp(readValue(uiFigure, 'AudioPage', 'Visible'), 'on'), 'Audio navigation did not show its page.');
queueGet(0, 0); invokeButton(uiFigure, 'LoadAudioButton');
assertAlive(uiFigure, 'cancel first audio import'); record('cancel audio import');
fs = 8000; t = (0:fs-1)' / fs;
stereoPath = fullfile(outputDir, 'probe_stereo.wav');
monoPath = fullfile(outputDir, 'probe_mono.wav');
audiowrite(stereoPath, [0.55*sin(2*pi*440*t), 0.4*cos(2*pi*710*t)], fs);
audiowrite(monoPath, 0.5*sin(2*pi*330*t), fs);
queueGet('probe_stereo.wav', outputDir); invokeButton(uiFigure, 'LoadAudioButton');
assertAlive(uiFigure, 'stereo import');
assert(strcmp(char(readValue(uiFigure, 'AudioFileField', 'Value')), 'probe_stereo.wav'), 'Stereo source was not selected.');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'off'), 'Import must invalidate the previous audio result.');
record('stereo import');

setValue(uiFigure, 'StartTimeField', 1.2);
invokeValueChanged(uiFigure, 'StartTimeField');
assertAlive(uiFigure, 'invalid window edit');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'off'), 'Invalid window retained stale saveable results.');
invokeButton(uiFigure, 'AnalyzeAudioButton');
assertAlive(uiFigure, 'analyze invalid window'); record('invalid window rejected without closing app');
setValue(uiFigure, 'StartTimeField', 0.1);
setValue(uiFigure, 'EndTimeField', 0.9);
invokeValueChanged(uiFigure, 'StartTimeField');
assertAlive(uiFigure, 'repair invalid window');
invokeButton(uiFigure, 'AnalyzeAudioButton');
assertAlive(uiFigure, 'analyze recovered window');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'on'), 'Valid recovery did not produce a saveable result.');
assert(~strcmp(char(readValue(uiFigure, 'RightRMSField', 'Value')), char(8212)), 'Stereo analysis did not populate channel 2 statistics.');
assertNoExtraFigures(uiFigure, priorFigures, 'stereo analysis'); record('invalid window recovery and stereo analysis');

% Verify audio save formats and cancellation callbacks while the result is active.
queuePut(0, 0); invokeButton(uiFigure, 'SaveDataButton');
assertAlive(uiFigure, 'cancel stereo data save'); record('cancel stereo data save');
audioMat = fullfile(outputDir, 'audio_stereo.mat');
queuePut('audio_stereo.mat', outputDir); invokeButton(uiFigure, 'SaveDataButton');
assertFile(audioMat, 'stereo audio MAT');
audioLoaded = load(audioMat, 'result');
assert(strcmp(audioLoaded.result.Kind, 'audio') && size(audioLoaded.result.Samples,2) == 2, 'Stereo MAT result is invalid.');
assertAlive(uiFigure, 'stereo MAT save'); record('stereo MAT save');
audioCsv = fullfile(outputDir, 'audio_stereo.csv');
queuePut('audio_stereo.csv', outputDir); invokeButton(uiFigure, 'SaveDataButton');
assertFile(audioCsv, 'stereo audio CSV');
assertFile(fullfile(outputDir, 'audio_stereo_statistics.csv'), 'stereo audio statistics CSV');
audioTable = readtable(audioCsv, 'VariableNamingRule', 'preserve');
assert(isequal(audioTable.Properties.VariableNames, {'Time_seconds','Channel1','Channel2'}), 'Unexpected stereo CSV columns.');
assertAlive(uiFigure, 'stereo CSV save'); record('stereo CSV save');
queuePut(0, 0); invokeButton(uiFigure, 'SaveFigureButton');
assertAlive(uiFigure, 'cancel stereo figure export'); record('cancel stereo figure export');
audioPng = fullfile(outputDir, 'audio_stereo.png');
queuePut('audio_stereo.png', outputDir); invokeButton(uiFigure, 'SaveFigureButton');
assertFile(audioPng, 'stereo audio PNG');
assertAlive(uiFigure, 'stereo PNG export'); assertNoExtraFigures(uiFigure, priorFigures, 'stereo PNG export'); record('stereo PNG export');
audioPdf = fullfile(outputDir, 'audio_stereo.pdf');
queuePut('audio_stereo.pdf', outputDir); invokeButton(uiFigure, 'SaveFigureButton');
assertFile(audioPdf, 'stereo audio PDF');
assertAlive(uiFigure, 'stereo PDF export'); assertNoExtraFigures(uiFigure, priorFigures, 'stereo PDF export'); record('stereo PDF export');

% Cancel preserves the selected audio; importing mono clears results and hides channel 2 data.
queueGet(0, 0); invokeButton(uiFigure, 'LoadAudioButton');
assertAlive(uiFigure, 'cancel reimport');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'on'), 'Cancel import discarded the existing result.');
record('cancel reimport preserves result');
queueGet('probe_mono.wav', outputDir); invokeButton(uiFigure, 'LoadAudioButton');
assertAlive(uiFigure, 'mono reselect');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'off'), 'Mono import retained stale analysis results.');
invokeButton(uiFigure, 'AnalyzeAudioButton');
assertAlive(uiFigure, 'mono analysis');
assert(strcmp(char(readValue(uiFigure, 'RightRMSField', 'Value')), char(8212)), 'Mono analysis should leave channel 2 statistics empty.');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'on'), 'Mono analysis did not enable saving.');
monoCsv = fullfile(outputDir, 'audio_mono.csv');
queuePut('audio_mono.csv', outputDir); invokeButton(uiFigure, 'SaveDataButton');
assertFile(monoCsv, 'mono audio CSV');
assertFile(fullfile(outputDir, 'audio_mono_statistics.csv'), 'mono audio statistics CSV');
monoTable = readtable(monoCsv, 'VariableNamingRule', 'preserve');
assert(isequal(monoTable.Properties.VariableNames, {'Time_seconds','Channel1'}), 'Unexpected mono CSV columns.');
record('mono import analysis and CSV');

queueGet('probe_stereo.wav', outputDir); invokeButton(uiFigure, 'LoadAudioButton');
assertAlive(uiFigure, 'stereo reselect after mono');
assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'off'), 'Stereo reselect retained the mono result.');
invokeButton(uiFigure, 'AnalyzeAudioButton');
assertAlive(uiFigure, 'stereo reanalysis after mono');
assert(~strcmp(char(readValue(uiFigure, 'RightRMSField', 'Value')), char(8212)), 'Stereo reanalysis did not restore channel 2 statistics.');
record('stereo reselect and reanalysis after mono');

% Repeat import cancellation, import, and analysis; only the app's explicit close request may close it.
for iteration = 1:3
    queueGet(0, 0); invokeButton(uiFigure, 'LoadAudioButton');
    assertAlive(uiFigure, sprintf('repeat import cancel %d', iteration));
    queueGet('probe_stereo.wav', outputDir); invokeButton(uiFigure, 'LoadAudioButton');
    assertAlive(uiFigure, sprintf('repeat stereo import %d', iteration));
    invokeButton(uiFigure, 'AnalyzeAudioButton');
    assertAlive(uiFigure, sprintf('repeat audio analysis %d', iteration));
    assert(strcmp(readValue(uiFigure, 'SaveDataButton', 'Enable'), 'on'), 'Repeated analysis did not restore save state.');
    assertNoExtraFigures(uiFigure, priorFigures, sprintf('repeat audio iteration %d', iteration));
    record(sprintf('repeat import/analyze iteration %d', iteration));
end

% All operations above must retain this exact user-facing UIFigure.
assertAlive(uiFigure, 'before user close');
closeCallback = uiFigure.CloseRequestFcn;
assert(isa(closeCallback, 'function_handle'), 'CloseRequestFcn is not bound.');
feval(closeCallback, uiFigure, struct('EventName','CloseRequest'));
assert(~isvalid(uiFigure), 'UIFigure remained open after its user close request.');
remaining = findall(groot, 'Type', 'figure');
unexpected = remaining(~ismember(remaining, priorFigures));
assert(isempty(unexpected), 'Unexpected figures remain after user close: %d.', numel(unexpected));
report.Passed = true;
record('explicit user close destroyed only the app UIFigure');
fprintf('PASS %s\n', applicationFile);
fprintf('Resolved app: %s\nResolved math: %s\nOutputs: %s\n', resolvedApp, resolvedMath, outputDir);
for k = 1:numel(report.Events), fprintf('  %s\n', report.Events{k}); end

    function record(name)
        report.Events{end+1} = name;
        fprintf('PASS step: %s\n', name);
    end
end

function invokeButton(uiFigure, propertyName)
app = uiFigure.RunningAppInstance;
component = app.(propertyName);
callback = component.ButtonPushedFcn;
assert(isa(callback, 'function_handle'), 'No button callback for %s.', propertyName);
feval(callback, component, struct('EventName','ButtonPushed'));
clear callback component app
end

function invokeValueChanged(uiFigure, propertyName)
app = uiFigure.RunningAppInstance;
component = app.(propertyName);
callback = component.ValueChangedFcn;
assert(isa(callback, 'function_handle'), 'No value callback for %s.', propertyName);
feval(callback, component, struct('EventName','ValueChanged'));
clear callback component app
end

function setValue(uiFigure, propertyName, value)
app = uiFigure.RunningAppInstance;
component = app.(propertyName);
component.Value = value;
clear component app
end

function value = readValue(uiFigure, propertyName, fieldName)
app = uiFigure.RunningAppInstance;
component = app.(propertyName);
value = component.(fieldName);
clear component app
end

function assertAlive(uiFigure, stage)
assert(isvalid(uiFigure), 'UIFigure was destroyed during %s.', stage);
assert(isprop(uiFigure, 'RunningAppInstance') && isvalid(uiFigure.RunningAppInstance), ...
    'RunningAppInstance was lost during %s.', stage);
end

function assertNoExtraFigures(uiFigure, priorFigures, stage)
figures = findall(groot, 'Type', 'figure');
owned = [priorFigures(:); uiFigure];
extra = figures(~ismember(figures, owned));
assert(isempty(extra), 'Unexpected figure leak after %s: %d extra figure(s).', stage, numel(extra));
end

function assertFile(path, description)
assert(isfile(path), '%s was not created: %s', description, path);
info = dir(path);
assert(info.bytes > 0, '%s is empty: %s', description, path);
end

function queueGet(file, folder)
global STATAPP_LIFECYCLE_UIGET_QUEUE;
STATAPP_LIFECYCLE_UIGET_QUEUE = {{file, folder}};
end

function queuePut(file, folder, closeDuringPut)
global STATAPP_LIFECYCLE_UIPUT_QUEUE STATAPP_LIFECYCLE_CLOSE_DURING_PUT;
STATAPP_LIFECYCLE_UIPUT_QUEUE = {{file, folder}};
if nargin < 3, closeDuringPut = []; end
STATAPP_LIFECYCLE_CLOSE_DURING_PUT = closeDuringPut;
end

function cleanupOwnedFigure(uiFigure)
if ~isvalid(uiFigure), return; end
try
    callback = uiFigure.CloseRequestFcn;
    if isa(callback, 'function_handle')
        feval(callback, uiFigure, struct('EventName','CloseRequest'));
    end
catch
end
if isvalid(uiFigure), delete(uiFigure); end
end

function clearTestGlobals
clear global STATAPP_LIFECYCLE_UIGET_QUEUE STATAPP_LIFECYCLE_UIPUT_QUEUE STATAPP_LIFECYCLE_CLOSE_DURING_PUT
end
