function verify_staged_app(stage)
%VERIFY_STAGED_APP Validate the real MLAPP, custom parameters and design model.
    root = fileparts(fileparts(mfilename('fullpath')));
    if nargin == 0, stage = root; end
    oldDirectory = pwd;
    directoryCleanup = onCleanup(@() cd(oldDirectory));
    oldPath = path;
    pathCleanup = onCleanup(@() path(oldPath));
    cd(stage); addpath(stage);
    expectedApp = fullfile(pwd, 'StatisticsExperimentApp.mlapp');
    assert(strcmpi(which('StatisticsExperimentApp'), expectedApp));
    assert(strcmpi(which('StatisticsExperimentMath'), fullfile(pwd,'StatisticsExperimentMath.m')));
    app = StatisticsExperimentApp;
    appCleanup = onCleanup(@() delete(app));
    app.UIFigure.Visible = 'off';
    for count = [100 10000]
        app.TrialsEditField.Value = count;
        press(app.RunSimButton);
        assert(strcmp(app.StateLabel.Text, '已完成'), app.StatusLabel.Text);
        assert(str2double(app.SimCountField.Value) == count);
        histogram = findobj(app.SimAxes, 'Type', 'histogram');
        assert(abs(sum(histogram.Values .* diff(histogram.BinEdges))-1) < 1e-10);
        assert(numel(findobj(app.SimAxes, 'Type', 'line')) == 2);
    end
    app.TermsEditField.Value = 10000;
    press(app.RunSimButton);
    assert(strcmp(app.StateLabel.Text,'已完成'), app.StatusLabel.Text);
    assert(str2double(app.TheoryMeanField.Value) == 5000);
    app.TermsEditField.Value = 100;
    app.SimBinModeDropDown.Value = '区间宽度';
    feval(app.SimBinModeDropDown.ValueChangedFcn, app.SimBinModeDropDown, []);
    app.SimBinValueField.Value = 0.5;
    press(app.RunSimButton);
    histogram = findobj(app.SimAxes, 'Type', 'histogram');
    assert(max(abs(diff(histogram.BinEdges)-0.5)) < 1e-10);
    assert(strcmp(app.SaveDataButton.Enable,'on'));
    assert(str2double(app.SimWidthField.Value) == 0.5);
    clear appCleanup;

    lastwarn('');
    [outcome, data] = appdesigner.internal.application.loadApp(expectedApp);
    assert(strcmp(outcome.Status,'success'));
    if isfield(data,'ErroredComponents') && isfield(data.ErroredComponents,'CodeNames')
        assert(isempty(data.ErroredComponents.CodeNames));
    end
    [message,~] = lastwarn; assert(isempty(message));
    reader = appdesigner.internal.serialization.FileReader(expectedApp);
    embeddedCode = char(reader.readMATLABCodeText());
    exportedCode = fileread(fullfile(stage,'src','StatisticsExperimentApp.m'));
    embeddedCode = regexprep(regexprep(embeddedCode,'\r\n?',newline), '[ \t]+(?=\n|$)', '');
    exportedCode = regexprep(regexprep(exportedCode,'\r\n?',newline), '[ \t]+(?=\n|$)', '');
    assert(strcmp(embeddedCode, exportedCode), ...
        'The source snapshot is stale; run tools/export_frontend.m after saving the MLAPP.');
    raw = reader.readAppDesignerData();
    assert(strcmp(raw.code.StartupCallback.Name, 'startupFcn'));
    assert(numel(raw.code.Callbacks) == 13);
    delete(raw.components.UIFigure);
    fprintf('PASS actual MLAPP: N=100/10000, m=10000, width=0.5, Design View and callbacks\n');
end

function press(button)
    feval(button.ButtonPushedFcn, button, []);
end
