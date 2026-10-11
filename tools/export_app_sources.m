function outputFiles = export_app_sources
%EXPORT_APP_SOURCES 导出五个 MLAPP 的可审阅 MATLAB 文本。
%   在 App Designer 保存设计文件后运行本函数，并一起提交 .mlapp 与
%   src/*.m。文本副本只用于版本比较，不要加入日常 MATLAB 搜索路径。
%   本工具使用 MATLAB R2024b 的 App Designer 序列化接口。

    root = fileparts(fileparts(mfilename('fullpath')));
    folders = {'', 'exp1', 'exp2', 'exp3', 'exp4'};
    names = {'MatlabExperimentHub', 'StatisticsExperimentApp', ...
        'NumericalRootsApp', 'ArrayPatternApp', 'SystemStabilityApp'};
    outputFiles = cell(size(names));

    for k = 1:numel(names)
        folder = fullfile(root, folders{k});
        source = fullfile(folder, [names{k} '.mlapp']);
        assert(isfile(source), 'AppSources:MissingApp', ...
            '未找到 App Designer 源文件：%s', source);
        reader = appdesigner.internal.serialization.FileReader(source);
        code = char(reader.readMATLABCodeText());
        code = regexprep(code, '\r\n?', newline);
        code = regexprep(code, '[ \t]+(?=\n|$)', '');

        destination = fullfile(folder, 'src');
        if ~isfolder(destination), mkdir(destination); end
        outputFiles{k} = fullfile(destination, [names{k} '.m']);
        writeUtf8(outputFiles{k}, code);
        fprintf('Exported %s\n', outputFiles{k});
    end
end

function writeUtf8(filename, content)
    [file, message] = fopen(filename, 'w', 'n', 'UTF-8');
    assert(file >= 0, 'AppSources:WriteFailed', '%s', message);
    cleanup = onCleanup(@() fclose(file)); %#ok<NASGU>
    fprintf(file, '%s', content);
end
