function report = verify_app_designer_files
%VERIFY_APP_DESIGNER_FILES 检查设计模型、回调及同步的代码审阅副本。
%   使用 R2024b App Designer 的加载器，验证文件含可编辑的控件树。
%   同时检查每个设计控件都有代码属性，防止设计文件保存后无法运行。

    root = fileparts(fileparts(mfilename('fullpath')));
    folders = {'', 'exp1', 'exp2', 'exp3', 'exp4'};
    names = {'MatlabExperimentHub', 'StatisticsExperimentApp', ...
        'NumericalRootsApp', 'ArrayPatternApp', 'SystemStabilityApp'};
    originalFigures = findall(groot, 'Type', 'figure');
    cleanup = onCleanup(@() closeNewFigures(originalFigures)); %#ok<NASGU>
    report = struct('Passed',false, 'Apps',[]);
    entries = struct('Name',{},'Components',{},'Callbacks',{});

    for k = 1:numel(names)
        folder = fullfile(root, folders{k});
        file = fullfile(folder, [names{k} '.mlapp']);
        reader = appdesigner.internal.serialization.FileReader(file);
        source = normalizeCode(char(reader.readMATLABCodeText()));
        snapshot = normalizeCode(fileread(fullfile(folder,'src',[names{k} '.m'])));
        assert(strcmp(source,snapshot), 'AppDesignerTests:StaleExport', ...
            '%s 的文本副本未同步，请运行 tools/export_app_sources。', names{k});

        [outcome, data] = appdesigner.internal.application.loadApp(file);
        assert(strcmp(outcome.Status,'success'), 'AppDesignerTests:LoadFailed', ...
            '%s 无法在 App Designer 中加载。', names{k});
        if isfield(data,'ErroredComponents') && isfield(data.ErroredComponents,'CodeNames')
            assert(isempty(data.ErroredComponents.CodeNames), ...
                'AppDesignerTests:InvalidComponent','设计模型含无法加载的控件。');
        end

        raw = reader.readAppDesignerData();
        designFigure = raw.components.UIFigure;
        nodes = findall(designFigure,'-property','DesignTimeProperties');
        codeNames = cell(1,numel(nodes));
        assert(numel(nodes)>10, 'AppDesignerTests:EmptyDesign', ...
            '%s 的设计模型未包含完整界面。', names{k});
        for j = 1:numel(nodes)
            codeNames{j} = nodes(j).DesignTimeProperties.CodeName;
            declaration = ['(?m)^\s*' regexptranslate('escape',codeNames{j}) ...
                '[ \t]+' regexptranslate('escape',class(nodes(j))) '[ \t]*$'];
            assert(~isempty(regexp(source,declaration,'once')), ...
                'AppDesignerTests:MissingProperty', ...
                '%s 缺少设计控件 %s 的类属性声明。',names{k},codeNames{j});
        end
        assert(numel(unique(codeNames))==numel(codeNames), ...
            'AppDesignerTests:DuplicateCodeName','设计控件名称重复。');
        assert(strcmp(raw.code.StartupCallback.Name,'startupFcn'), ...
            'AppDesignerTests:MissingStartup','缺少 App Designer 初始化回调。');
        for j = 1:numel(raw.code.Callbacks)
            callbackName = raw.code.Callbacks(j).Name;
            assert(contains(source,['@' callbackName ', true)']), ...
                'AppDesignerTests:UnboundCallback', ...
                '%s 的回调 %s 未绑定到控件。',names{k},callbackName);
        end
        entries(k) = struct('Name',names{k},'Components',numel(nodes), ...
            'Callbacks',numel(raw.code.Callbacks)); %#ok<AGROW>
        delete(designFigure);
        fprintf('DESIGN PASS %s: %d components, %d callbacks\n', ...
            names{k},entries(k).Components,entries(k).Callbacks);
    end
    report.Apps = entries;
    report.Passed = true;
end

function code = normalizeCode(code)
    code = regexprep(code,'\r\n?',newline);
    code = regexprep(code,'[ \t]+(?=\n|$)','');
end

function closeNewFigures(originalFigures)
    figures = findall(groot,'Type','figure');
    for k=1:numel(figures)
        if ~any(figures(k)==originalFigures), delete(figures(k)); end
    end
end
