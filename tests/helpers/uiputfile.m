function [file, folder, filterIndex] = uiputfile(varargin) %#ok<INUSD>
%UIPUTFILE Scoped chooser stub used only by test_project_gui.
% The caller puts this helper folder at the beginning of the MATLAB path and
% restores the prior path when the GUI integration test exits.
global MATLAB_PROJECT_GUI_TEST_UIPUTFILE
if isempty(MATLAB_PROJECT_GUI_TEST_UIPUTFILE) || ...
        ~isfield(MATLAB_PROJECT_GUI_TEST_UIPUTFILE, 'Action')
    error('ProjectGuiTest:UnconfiguredSaveDialog', ...
        'Configure MATLAB_PROJECT_GUI_TEST_UIPUTFILE before invoking export.');
end
config = MATLAB_PROJECT_GUI_TEST_UIPUTFILE;
if ~isfield(config, 'Calls') || isempty(config.Calls)
    config.Calls = 0;
end
config.Calls = config.Calls + 1;
MATLAB_PROJECT_GUI_TEST_UIPUTFILE = config;

if isfield(config, 'OnInvoke') && ~isempty(config.OnInvoke)
    feval(config.OnInvoke);
end

filterIndex = 1;
switch lower(char(string(config.Action)))
    case 'success'
        file = config.File;
        folder = config.Folder;
    case 'cancel'
        file = 0;
        folder = 0;
    case 'failure'
        file = config.File;
        folder = config.Folder;
    otherwise
        error('ProjectGuiTest:InvalidSaveDialogAction', ...
            'Unknown save dialog action: %s.', char(string(config.Action)));
end
end
