function report = test_app_designer_roundtrip
%TEST_APP_DESIGNER_ROUNDTRIP 在副本上验证设计器保存、代码重生成和启动。
%   需 MATLAB R2024b 桌面组件。原始 MLAPP 不会被覆盖；输出写入
%   tests/output/designer_roundtrip。建议在独立 MATLAB 会话中运行。

    root = fileparts(fileparts(mfilename('fullpath')));
    folders = {'', 'exp1', 'exp2', 'exp3', 'exp4'};
    names = {'MatlabExperimentHub','StatisticsExperimentApp', ...
        'NumericalRootsApp','ArrayPatternApp','SystemStabilityApp'};
    originalPath = path;
    originalFolder = pwd;
    environment = appdesigner.internal.application.getAppDesignEnvironment();
    designerWasOpen = environment.isAppDesignerOpen();
    cleanup = onCleanup(@() restoreSession(originalFolder,originalPath, ...
        environment,designerWasOpen)); %#ok<NASGU>
    addpath(root,fullfile(root,'exp1'),fullfile(root,'exp2'), ...
        fullfile(root,'exp3'),fullfile(root,'exp4'));
    entries = struct('Name',{},'ComponentCount',{},'CallbackCount',{},'SavedCopy',{});

    for index = 1:numel(names)
        name = names{index};
        source = fullfile(root,folders{index},[name '.mlapp']);
        destination = fullfile(root,'tests','output','designer_roundtrip',sprintf('app%d',index));
        if ~isfolder(destination), mkdir(destination); end
        copy = fullfile(destination,[name '.mlapp']);
        copyfile(source,copy);
        entries(index) = checkOneCopy(copy,name,index); %#ok<AGROW>
        cd(originalFolder);
    end
    report = struct('Passed',true,'MATLABRelease',version('-release'),'Apps',entries);
    save(fullfile(root,'tests','output','designer_roundtrip','verification.mat'),'report');

end

function entry = checkOneCopy(copy,name,index)
    document = [];
    running = [];
    modelFigure = [];
    try
        document = appdesigner.internal.document.AppDocument.open(copy,'Visible',false);

        % The frontend save synchronizes generated code with the design canvas.
        % AppModel.save alone bypasses that synchronization and is not a user save.
        document.save();
        reader = appdesigner.internal.serialization.FileReader(copy);
        code = char(reader.readMATLABCodeText());
        raw = reader.readAppDesignerData();
        modelFigure = raw.components.UIFigure;
        components = findall(modelFigure,'-property','DesignTimeProperties');
        for k=1:numel(components)
            codeName = components(k).DesignTimeProperties.CodeName;
            declaration = ['(?m)^\s*' regexptranslate('escape',codeName) ...
                '[ \t]+' regexptranslate('escape',class(components(k))) '[ \t]*$'];
            assert(~isempty(regexp(code,declaration,'once')), ...
                'DesignerRoundtrip:MissingProperty', ...
                '%s 保存后缺少控件属性 %s。',name,codeName);
        end
        cd(fileparts(copy));
        assert(strcmpi(which(name),copy), ...
            'DesignerRoundtrip:ShadowedCopy','测试副本未成为实际运行入口。');
        % Run the saved design through the same public constructor used by
        % launch_experiment, after the editor has released the document.
        document.closeNoPrompt();
        document = [];
        running = feval(name);
        assert(isgraphics(running.UIFigure), 'DesignerRoundtrip:RunFailed', ...
            '%s 重新保存后未能启动。',name);
        running.UIFigure.Visible = 'off';
        for k=1:numel(components)
            codeName = components(k).DesignTimeProperties.CodeName;
            runtimeComponent = running.(codeName);
            % Startup callbacks may update tags, text or layout. The design
            % property must still resolve to a live component of the same type.
            assert(isgraphics(runtimeComponent) && isa(runtimeComponent,class(components(k))), ...
                'DesignerRoundtrip:MissingRuntimeComponent', ...
                '%s 保存后未正确创建控件 %s。',name,codeName);
        end
        exerciseCallback(running,index);
        entry = struct('Name',name,'ComponentCount',numel(components), ...
            'CallbackCount',numel(raw.code.Callbacks),'SavedCopy',copy);
        fprintf('DESIGNER ROUNDTRIP PASS %s: %d components, %d callbacks\n', ...
            name,entry.ComponentCount,entry.CallbackCount);
    catch exception
        closeCopy(running,modelFigure,document);
        rethrow(exception);
    end
    closeCopy(running,modelFigure,document);
end

function closeCopy(running,modelFigure,document)
    % Close created objects while their supporting folders are still on path.
    if ~isempty(running) && isvalid(running), delete(running); end
    if ~isempty(modelFigure) && isgraphics(modelFigure), delete(modelFigure); end
    if ~isempty(document) && isvalid(document), document.closeNoPrompt(); end
end

function restoreSession(originalFolder,originalPath,environment,designerWasOpen)
    cd(originalFolder);
    path(originalPath);
    % The client closes asynchronously; finish that work before returning.
    if ~designerWasOpen && isvalid(environment) ...
            && environment.isAppDesignerOpen()
        environment.requestToCloseAppDesigner();
        started = tic;
        while isvalid(environment) && environment.isAppDesignerOpen() && toc(started) < 10
            pause(0.1);
        end
    end
end

function exerciseCallback(running,index)
    switch index
        case 1
            press(running.SelectExperiment2);
            assert(contains(running.Heading.Text,'实验二'));
        case 2
            press(running.RunSimButton);
            assert(strcmp(running.StateLabel.Text,'已完成'));
        case 3
            press(running.RunButton);
            result=running.Result;
            assert(result.newton.converged);
        case 4
            press(running.RunButton);
            result=running.Result;
            assert(result.Config.ElementCount==8);
        case 5
            result=running.Result;
            assert(strcmp(result.config.domain,'continuous'));
    end
end

function press(button)
    callback = button.ButtonPushedFcn;
    callback(button,[]);
    drawnow;
end
