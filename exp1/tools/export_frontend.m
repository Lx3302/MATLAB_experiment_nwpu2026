function outputFile = export_frontend
%EXPORT_FRONTEND Synchronize the reviewable source with the saved MLAPP.
%   Run after saving StatisticsExperimentApp.mlapp in App Designer.
%   This export uses a MATLAB R2024b App Designer serialization API. It
%   does not rebuild the app or modify its binary design model.
    experimentRoot = fileparts(fileparts(mfilename('fullpath')));
    appFile = fullfile(experimentRoot, 'StatisticsExperimentApp.mlapp');
    reader = appdesigner.internal.serialization.FileReader(appFile);
    code = char(reader.readMATLABCodeText());
    code = regexprep(code, '\r\n?', newline);
    code = regexprep(code, '[ \t]+(?=\n|$)', '');
    sourceDirectory = fullfile(experimentRoot, 'src');
    if ~isfolder(sourceDirectory), mkdir(sourceDirectory); end
    outputFile = fullfile(sourceDirectory, 'StatisticsExperimentApp.m');
    file = fopen(outputFile, 'w', 'n', 'UTF-8');
    assert(file ~= -1, 'Cannot write source export: %s', outputFile);
    cleanup = onCleanup(@() fclose(file));
    fprintf(file, '%s', code);
    fprintf('Source synchronized: %s\n', outputFile);
end
