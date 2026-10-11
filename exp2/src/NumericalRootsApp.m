classdef NumericalRootsApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        ShellGrid               matlab.ui.container.GridLayout
        exp2_Header             matlab.ui.container.Panel
        HeaderGrid              matlab.ui.container.GridLayout
        HeaderTitle             matlab.ui.control.Label
        StatusLabel             matlab.ui.control.Label
        HeaderActions           matlab.ui.container.GridLayout
        RunButton               matlab.ui.control.Button
        ExportMatButton         matlab.ui.control.Button
        ExportCsvButton         matlab.ui.control.Button
        ExportPngButton         matlab.ui.control.Button
        exp2_SettingsPanel      matlab.ui.container.Panel
        GridLayout              matlab.ui.container.GridLayout
        Label                   matlab.ui.control.Label
        PresetDropDown          matlab.ui.control.DropDown
        Label_1                 matlab.ui.control.Label
        CoefficientsField       matlab.ui.control.EditField
        Label_2                 matlab.ui.control.Label
        InitialRealField        matlab.ui.control.NumericEditField
        Label_3                 matlab.ui.control.Label
        InitialImagField        matlab.ui.control.NumericEditField
        Label_4                 matlab.ui.control.Label
        BracketLeftField        matlab.ui.control.NumericEditField
        Label_5                 matlab.ui.control.Label
        BracketRightField       matlab.ui.control.NumericEditField
        Label_6                 matlab.ui.control.Label
        XToleranceField         matlab.ui.control.NumericEditField
        Label_7                 matlab.ui.control.Label
        ResidualToleranceField  matlab.ui.control.NumericEditField
        Label_8                 matlab.ui.control.Label
        MaxIterationsField      matlab.ui.control.NumericEditField
        Label_9                 matlab.ui.control.Label
        PlotLeftField           matlab.ui.control.NumericEditField
        Label_10                matlab.ui.control.Label
        PlotRightField          matlab.ui.control.NumericEditField
        GridLayout_1            matlab.ui.container.GridLayout
        ResetButton             matlab.ui.control.Button
        exp2_ParameterHint      matlab.ui.control.Label
        exp2_WorkspaceTabs      matlab.ui.container.TabGroup
        exp2_PlotTab            matlab.ui.container.Tab
        GridLayout_2            matlab.ui.container.GridLayout
        FunctionAxes            matlab.ui.control.UIAxes
        ConvergenceAxes         matlab.ui.control.UIAxes
        exp2_ResultTab          matlab.ui.container.Tab
        GridLayout_3            matlab.ui.container.GridLayout
        Panel                   matlab.ui.container.Panel
        GridLayout_4            matlab.ui.container.GridLayout
        SummaryTable            matlab.ui.control.Table
        Panel_1                 matlab.ui.container.Panel
        GridLayout_5            matlab.ui.container.GridLayout
        VerificationTable       matlab.ui.control.Table
        exp2_HistoryTab         matlab.ui.container.Tab
        GridLayout_6            matlab.ui.container.GridLayout
        HistoryMethodDropDown   matlab.ui.control.DropDown
        HistoryTable            matlab.ui.control.Table
    end

    properties (Access = public)
        Result = struct()
    end

    properties (Access = private)
        Defaults
        IsBusy = false
        IsDirty = true
        Closing = false
    end

    methods (Access = private)














        function handlePresetChanged(app)
            presetIndex = find(strcmp({app.Defaults.presets.name}, ...
                app.PresetDropDown.Value), 1);
            if isempty(presetIndex)
                app.markDirty();
                return;
            end
            app.loadPreset(presetIndex);
            app.markDirty();
        end

        function loadPreset(app, presetIndex)
            preset = app.Defaults.presets(presetIndex);
            app.PresetDropDown.Value = preset.name;
            app.CoefficientsField.Value = strjoin( ...
                arrayfun(@(value) sprintf('%.15g', value), ...
                preset.coefficients, 'UniformOutput', false), ', ');
            app.InitialRealField.Value = preset.initialX;
            app.InitialImagField.Value = 0;
            app.BracketLeftField.Value = preset.bracket(1);
            app.BracketRightField.Value = preset.bracket(2);
            app.PlotLeftField.Value = preset.plotBounds(1);
            app.PlotRightField.Value = preset.plotBounds(2);
        end

        function resetDefaults(app)
            app.Defaults = exp2_defaults();
            app.loadPreset(1);
            app.XToleranceField.Value = app.Defaults.xTolerance;
            app.ResidualToleranceField.Value = app.Defaults.residualTolerance;
            app.MaxIterationsField.Value = app.Defaults.maxIterations;
            app.Result = struct();
            app.IsDirty = true;
            app.clearDisplay();
            app.StatusLabel.Text = '已恢复默认参数';
            app.syncExportButtons();
        end

        function markDirty(app)
            if app.IsBusy || isempty(app.StatusLabel) || ~isvalid(app.StatusLabel)
                return;
            end
            app.IsDirty = true;
            app.Result = struct();
            app.clearDisplay();
            app.StatusLabel.Text = '参数已修改，需重新运行';
            app.StatusLabel.FontColor = [0.58 0.36 0.07];
            app.syncExportButtons();
        end

        function coefficientsEdited(app)
            % 手动输入系数后明确标为自定义，避免预设名称误指当前方程。
            app.PresetDropDown.Value = '自定义';
            app.markDirty();
        end

        function runAnalysis(app)
            if app.IsBusy || app.Closing
                return;
            end
            try
                config = app.collectConfiguration();
            catch exception
                app.StatusLabel.Text = exception.message;
                app.StatusLabel.FontColor = [0.72 0.18 0.18];
                return;
            end

            app.beginBusy();
            app.StatusLabel.Text = '计算中…';
            app.StatusLabel.FontColor = [0.12 0.39 0.82];
            drawnow;
            cleanup = onCleanup(@() app.finishRun()); %#ok<NASGU>
            try
                app.Result = exp2_solve(config);
                app.IsDirty = false;
                app.renderResult();
                app.updateCompletionStatus();
            catch exception
                app.StatusLabel.Text = ['计算失败：' exception.message];
                app.StatusLabel.FontColor = [0.72 0.18 0.18];
            end
        end

        function finishRun(app)
            app.IsBusy = false;
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure) && ...
                    ~isempty(app.RunButton) && isvalid(app.RunButton)
                app.setInputEnabled('on');
                app.syncExportButtons();
            end
        end

        function handleClose(app)
            if app.IsBusy
                app.StatusLabel.Text = '计算完成后才能关闭窗口';
                app.StatusLabel.FontColor = [0.58 0.36 0.07];
                return;
            end
            delete(app);
        end

        function config = collectConfiguration(app)
            config = app.Defaults;
            config.coefficients = app.parseCoefficients(app.CoefficientsField.Value);
            config.initialX = complex(app.InitialRealField.Value, app.InitialImagField.Value);
            config.bracket = [app.BracketLeftField.Value, app.BracketRightField.Value];
            config.xTolerance = app.XToleranceField.Value;
            config.residualTolerance = app.ResidualToleranceField.Value;
            config.maxIterations = app.MaxIterationsField.Value;
            config.plotBounds = [app.PlotLeftField.Value, app.PlotRightField.Value];

            presetIndex = find(strcmp({app.Defaults.presets.name}, ...
                app.PresetDropDown.Value), 1);
            if isempty(presetIndex)
                config.presetIndex = 0;
            else
                config.presetIndex = presetIndex;
            end
            matchedPreset = [];
            if ~isempty(presetIndex) && ...
                    isequal(config.coefficients, app.Defaults.presets(presetIndex).coefficients)
                matchedPreset = app.Defaults.presets(presetIndex);
            end
            if isempty(matchedPreset)
                config.equationName = '自定义多项式';
                config.formula = app.formatPolynomial(config.coefficients);
            else
                config.equationName = matchedPreset.name;
                config.formula = matchedPreset.formula;
            end
        end

        function coefficients = parseCoefficients(~, inputText)
            if isstring(inputText)
                inputText = char(inputText);
            end
            inputText = strtrim(inputText);
            if isempty(inputText)
                error('exp2:EmptyCoefficients', '请输入多项式系数。');
            end
            tokens = regexp(inputText, '[,;\s]+', 'split');
            numberPattern = ...
                '^[-+]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?$';
            coefficients = zeros(1, numel(tokens));
            for index = 1:numel(tokens)
                if isempty(regexp(tokens{index}, numberPattern, 'once'))
                    error('exp2:InvalidCoefficients', ...
                        '系数只能是数字，请使用逗号、空格或分号分隔。');
                end
                coefficients(index) = str2double(tokens{index});
            end
            if any(isnan(coefficients) | isinf(coefficients))
                error('exp2:InvalidCoefficients', '系数必须是有限实数。');
            end
        end

        function renderResult(app)
            result = app.Result;
            methods = {result.newton, result.bisection};
            methodLabels = {'Newton', '二分法'};
            rows = cell(2, 6);
            for index = 1:2
                item = methods{index};
                rows(index, :) = { ...
                    methodLabels{index}, ...
                    app.formatComplex(item.x), ...
                    app.formatComplex(item.fValue), ...
                    app.formatNumber(item.residual), ...
                    item.iterations, ...
                    app.statusText(item.status)};
            end
            app.SummaryTable.Data = rows;

            rootCount = numel(result.verificationRoots);
            rootRows = cell(rootCount, 4);
            for index = 1:rootCount
                rootValue = result.verificationRoots(index);
                rootRows(index, :) = { ...
                    app.formatComplex(rootValue), ...
                    app.formatNumber(real(rootValue)), ...
                    app.formatNumber(imag(rootValue)), ...
                    app.formatNumber(result.verificationResiduals(index))};
            end
            if rootCount == 0 && ~isempty(result.verificationMessage)
                rootRows = {['校验失败：' result.verificationMessage], '', '', ''};
            end
            app.VerificationTable.Data = rootRows;
            app.plotResult();
            app.refreshHistory();
            app.syncExportButtons();
        end

        function plotResult(app)
            result = app.Result;
            x = linspace(result.config.plotBounds(1), result.config.plotBounds(2), 1200);
            y = polyval(result.coefficients, x);
            cla(app.FunctionAxes);
            plot(app.FunctionAxes, x, y, ...
                'Color', [0.10 0.37 0.78], ...
                'LineWidth', 1.8, ...
                'DisplayName', 'f(x)');
            hold(app.FunctionAxes, 'on');
            yline(app.FunctionAxes, 0, '-', ...
                'Color', [0.38 0.42 0.49], ...
                'HandleVisibility', 'on', ...
                'DisplayName', 'y = 0');

            realRootMask = abs(imag(result.verificationRoots)) <= ...
                1e-9 .* max(1, abs(real(result.verificationRoots)));
            realRoots = real(result.verificationRoots(realRootMask));
            inView = realRoots >= result.config.plotBounds(1) & ...
                realRoots <= result.config.plotBounds(2);
            if any(inView)
                plot(app.FunctionAxes, reshape(realRoots(inView), 1, []), ...
                    zeros(1, nnz(inView)), 'o', ...
                    'Color', [0.15 0.58 0.36], ...
                    'MarkerFaceColor', [0.15 0.58 0.36], ...
                    'LineStyle', 'none', ...
                    'DisplayName', 'roots(coeff) 实根');
            end
            app.plotMethodMarker(result.newton, 'Newton', [0.82 0.34 0.12], ...
                result.config.plotBounds);
            app.plotMethodMarker(result.bisection, '二分法', [0.58 0.30 0.72], ...
                result.config.plotBounds);
            hold(app.FunctionAxes, 'off');
            grid(app.FunctionAxes, 'on');
            xlabel(app.FunctionAxes, 'x');
            ylabel(app.FunctionAxes, 'f(x)');
            title(app.FunctionAxes, result.formula, ...
                'Interpreter', 'none', ...
                'FontWeight', 'normal');
            legend(app.FunctionAxes, 'show', 'Location', 'best');
            app.styleAxes(app.FunctionAxes);

            cla(app.ConvergenceAxes);
            hold(app.ConvergenceAxes, 'on');
            app.plotResidualHistory(result.newton, 'Newton', [0.10 0.37 0.78]);
            app.plotResidualHistory(result.bisection, '二分法', [0.86 0.43 0.17]);
            hold(app.ConvergenceAxes, 'off');
            grid(app.ConvergenceAxes, 'on');
            xlabel(app.ConvergenceAxes, '迭代次数 k');
            ylabel(app.ConvergenceAxes, '|f(x_k)|');
            title(app.ConvergenceAxes, '残差变化', 'FontWeight', 'normal');
            if ~isempty(result.newton.history) || ~isempty(result.bisection.history)
                legend(app.ConvergenceAxes, 'show', 'Location', 'best');
            else
                text(app.ConvergenceAxes, 0.5, 0.5, '暂无迭代数据', ...
                    'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', ...
                    'Color', [0.4 0.43 0.49]);
            end
            app.styleAxes(app.ConvergenceAxes);
        end

        function plotMethodMarker(app, method, label, color, bounds)
            if ~method.converged || ~isreal(method.x) || ...
                    method.x < bounds(1) || method.x > bounds(2)
                return;
            end
            plot(app.FunctionAxes, real(method.x), real(method.fValue), 's', ...
                'Color', color, ...
                'MarkerFaceColor', color, ...
                'LineStyle', 'none', ...
                'DisplayName', [label ' 结果']);
        end

        function plotResidualHistory(app, method, label, color)
            if isempty(method.history)
                return;
            end
            iterations = [method.history.iteration];
            residuals = [method.history.residual];
            valid = ~isnan(residuals) & ~isinf(residuals);
            if any(valid)
                semilogy(app.ConvergenceAxes, iterations(valid), ...
                    max(residuals(valid), realmin), '-o', ...
                    'Color', color, ...
                    'MarkerSize', 4, ...
                    'DisplayName', label);
            end
        end

        function styleAxes(~, axesHandle)
            axesHandle.FontName = 'Microsoft YaHei UI';
            axesHandle.FontSize = 11;
            axesHandle.XColor = [0.28 0.32 0.39];
            axesHandle.YColor = [0.28 0.32 0.39];
            axesHandle.Box = 'on';
            axesHandle.Color = [1 1 1];
        end

        function refreshHistory(app)
            if isempty(app.Result) || ~isfield(app.Result, 'newton')
                app.HistoryTable.Data = cell(0, 7);
                return;
            end
            if strcmp(app.HistoryMethodDropDown.Value, 'Newton')
                history = app.Result.newton.history;
            else
                history = app.Result.bisection.history;
            end
            rows = cell(numel(history), 7);
            for index = 1:numel(history)
                rows(index, :) = { ...
                    history(index).iteration, ...
                    app.formatComplex(history(index).x), ...
                    app.formatComplex(history(index).fValue), ...
                    app.formatNumber(history(index).residual), ...
                    app.formatNumber(history(index).step), ...
                    app.formatNumber(history(index).lower), ...
                    app.formatNumber(history(index).upper)};
            end
            app.HistoryTable.Data = rows;
        end

        function clearDisplay(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            app.SummaryTable.Data = cell(0, 6);
            app.VerificationTable.Data = cell(0, 4);
            app.HistoryTable.Data = cell(0, 7);
            cla(app.FunctionAxes);
            cla(app.ConvergenceAxes);
            text(app.FunctionAxes, 0.5, 0.5, '运行后显示函数图与根位置', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Color', [0.4 0.43 0.49]);
            text(app.ConvergenceAxes, 0.5, 0.5, '运行后显示迭代残差', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Color', [0.4 0.43 0.49]);
            app.styleAxes(app.FunctionAxes);
            app.styleAxes(app.ConvergenceAxes);
        end

        function updateCompletionStatus(app)
            if app.Result.newton.converged && app.Result.bisection.converged
                app.StatusLabel.Text = '两种方法均已收敛';
                app.StatusLabel.FontColor = [0.12 0.48 0.30];
            elseif app.Result.newton.converged || app.Result.bisection.converged
                app.StatusLabel.Text = '部分方法收敛；查看各方法状态';
                app.StatusLabel.FontColor = [0.58 0.36 0.07];
            else
                app.StatusLabel.Text = '未收敛；查看方法状态与迭代过程';
                app.StatusLabel.FontColor = [0.72 0.18 0.18];
            end
        end

        function syncExportButtons(app)
            hasResult = isstruct(app.Result) && isfield(app.Result, 'newton');
            enabled = hasResult && ~app.IsDirty && ~app.IsBusy;
            state = 'off';
            if enabled
                state = 'on';
            end
            controls = {app.ExportMatButton, app.ExportCsvButton, app.ExportPngButton};
            for index = 1:numel(controls)
                control = controls{index};
                if ~isempty(control) && isvalid(control)
                    control.Enable = state;
                end
            end
        end

        function exportMat(app)
            if ~app.canExport()
                return;
            end
            app.beginBusy();
            cleanup = onCleanup(@() app.finishRun()); %#ok<NASGU>
            try
                [file, folder] = uiputfile('*.mat', ...
                    '保存完整求根结果', 'exp2_results.mat');
                if isequal(file, 0)
                    app.StatusLabel.Text = '已取消导出';
                    return;
                end
                result = app.Result; %#ok<NASGU>
                save(fullfile(folder, file), 'result');
                app.StatusLabel.Text = 'MAT 结果已保存';
                app.StatusLabel.FontColor = [0.12 0.48 0.30];
            catch exception
                app.StatusLabel.Text = ['保存失败：' exception.message];
                app.StatusLabel.FontColor = [0.72 0.18 0.18];
            end
        end

        function exportCsv(app)
            if ~app.canExport()
                return;
            end
            app.beginBusy();
            cleanup = onCleanup(@() app.finishRun()); %#ok<NASGU>
            try
                [file, folder] = uiputfile('*.csv', ...
                    '导出当前迭代历史', 'exp2_iterations.csv');
                if isequal(file, 0)
                    app.StatusLabel.Text = '已取消导出';
                    return;
                end
                if strcmp(app.HistoryMethodDropDown.Value, 'Newton')
                    method = app.Result.newton;
                    methodName = 'Newton';
                else
                    method = app.Result.bisection;
                    methodName = 'Bisection';
                end
                history = method.history;
                output = cell(numel(history) + 1, 10);
                output(1, :) = {'method', 'iteration', 'x_real', 'x_imag', ...
                    'f_real', 'f_imag', 'residual', 'step', 'lower', 'upper'};
                for index = 1:numel(history)
                    output(index + 1, :) = { ...
                        methodName, history(index).iteration, ...
                        real(history(index).x), imag(history(index).x), ...
                        real(history(index).fValue), imag(history(index).fValue), ...
                        history(index).residual, history(index).step, ...
                        history(index).lower, history(index).upper};
                end
                writecell(output, fullfile(folder, file));
                app.StatusLabel.Text = '迭代 CSV 已保存';
                app.StatusLabel.FontColor = [0.12 0.48 0.30];
            catch exception
                app.StatusLabel.Text = ['导出失败：' exception.message];
                app.StatusLabel.FontColor = [0.72 0.18 0.18];
            end
        end

        function exportPng(app)
            if ~app.canExport()
                return;
            end
            app.beginBusy();
            cleanup = onCleanup(@() app.finishRun()); %#ok<NASGU>
            try
                [file, folder] = uiputfile('*.png', ...
                    '导出函数图', 'exp2_function.png');
                if isequal(file, 0)
                    app.StatusLabel.Text = '已取消导出';
                    return;
                end
                exportgraphics(app.FunctionAxes, fullfile(folder, file), ...
                    'Resolution', 200);
                app.StatusLabel.Text = '函数图 PNG 已保存';
                app.StatusLabel.FontColor = [0.12 0.48 0.30];
            catch exception
                app.StatusLabel.Text = ['导出失败：' exception.message];
                app.StatusLabel.FontColor = [0.72 0.18 0.18];
            end
        end

        function tf = canExport(app)
            tf = isstruct(app.Result) && isfield(app.Result, 'newton') && ...
                ~app.IsDirty && ~app.IsBusy;
        end

        function beginBusy(app)
            app.IsBusy = true;
            app.setInputEnabled('off');
            app.syncExportButtons();
        end

        function setInputEnabled(app, state)
            controls = {app.RunButton, app.ResetButton, app.PresetDropDown, ...
                app.CoefficientsField, app.InitialRealField, app.InitialImagField, ...
                app.BracketLeftField, app.BracketRightField, app.XToleranceField, ...
                app.ResidualToleranceField, app.MaxIterationsField, ...
                app.PlotLeftField, app.PlotRightField, app.HistoryMethodDropDown};
            for k = 1:numel(controls)
                controls{k}.Enable = state;
            end
        end

        function resizeLayout(app)
            if app.UIFigure.Position(3) < 1200
                app.ShellGrid.RowHeight = {102,'1x'};
                app.HeaderGrid.RowHeight = {28,40};
                app.HeaderGrid.ColumnWidth = {'1x',220};
                app.HeaderTitle.Layout.Row = 1;
                app.HeaderTitle.Layout.Column = 1;
                app.StatusLabel.Layout.Row = 1;
                app.StatusLabel.Layout.Column = 2;
                app.HeaderActions.Layout.Row = 2;
                app.HeaderActions.Layout.Column = [1 2];
                app.HeaderActions.ColumnWidth = {'1x',95,95,105};
            else
                app.ShellGrid.RowHeight = {72,'1x'};
                app.HeaderGrid.RowHeight = {'1x'};
                app.HeaderGrid.ColumnWidth = {'1x',205,470};
                app.HeaderTitle.Layout.Row = 1;
                app.HeaderTitle.Layout.Column = 1;
                app.StatusLabel.Layout.Row = 1;
                app.StatusLabel.Layout.Column = 2;
                app.HeaderActions.Layout.Row = 1;
                app.HeaderActions.Layout.Column = 3;
                app.HeaderActions.ColumnWidth = {150,95,95,95};
            end
            if app.UIFigure.Position(4) < 680
                rows = app.ShellGrid.RowHeight;
                app.ShellGrid.RowHeight = {rows{1},550};
                app.ShellGrid.Scrollable = 'on';
            else
                app.ShellGrid.Scrollable = 'off';
            end
        end

        function update = statusText(~, status)
            switch status
                case 'converged'
                    update = '收敛';
                case 'derivative-zero'
                    update = '导数为零';
                case 'nonfinite-value'
                    update = '非有限值';
                case 'stagnated'
                    update = '步长停滞';
                case 'max-iterations'
                    update = '达到迭代上限';
                case 'invalid-bracket'
                    update = '区间无效或无符号变化';
                case 'evaluation-error'
                    update = '函数求值失败';
                otherwise
                    update = status;
            end
        end

        function value = formatComplex(~, number)
            if ~(isnumeric(number) && isscalar(number)) || ...
                    isnan(real(number)) || isinf(real(number)) || ...
                    isnan(imag(number)) || isinf(imag(number))
                value = '—';
            elseif abs(imag(number)) <= 1e-12 * max(1, abs(real(number)))
                value = sprintf('%.10g', real(number));
            else
                value = sprintf('%.8g %+.8gi', real(number), imag(number));
            end
        end

        function value = formatNumber(~, number)
            if ~(isnumeric(number) && isscalar(number)) || isnan(number) || isinf(number)
                value = '—';
            else
                value = sprintf('%.6g', number);
            end
        end

        function textValue = formatPolynomial(~, coefficients)
            degree = numel(coefficients) - 1;
            terms = cell(1, numel(coefficients));
            for index = 1:numel(coefficients)
                power = degree - index + 1;
                if power == 0
                    terms{index} = sprintf('%g', coefficients(index));
                elseif power == 1
                    terms{index} = sprintf('(%g)x', coefficients(index));
                else
                    terms{index} = sprintf('(%g)x^%d', coefficients(index), power);
                end
            end
            textValue = strjoin(terms, ' + ');
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.Defaults = exp2_defaults();
            app.loadPreset(1);
            app.clearDisplay();
            app.syncExportButtons();
            app.resizeLayout();
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            app.handleClose();
        end

        % Size changed function: UIFigure
        function UIFigureSizeChanged(app, event)
            app.resizeLayout();
        end

        % Button pushed function: RunButton
        function RunButtonButtonPushed(app, event)
            app.runAnalysis();
        end

        % Button pushed function: ExportMatButton
        function ExportMatButtonButtonPushed(app, event)
            app.exportMat();
        end

        % Button pushed function: ExportCsvButton
        function ExportCsvButtonButtonPushed(app, event)
            app.exportCsv();
        end

        % Button pushed function: ExportPngButton
        function ExportPngButtonButtonPushed(app, event)
            app.exportPng();
        end

        % Value changed function: PresetDropDown
        function PresetDropDownValueChanged(app, event)
            app.handlePresetChanged();
        end

        % Value changed function: CoefficientsField
        function CoefficientsFieldValueChanged(app, event)
            app.coefficientsEdited();
        end

        % Value changed function: InitialRealField
        function InitialRealFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: InitialImagField
        function InitialImagFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: BracketLeftField
        function BracketLeftFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: BracketRightField
        function BracketRightFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: XToleranceField
        function XToleranceFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: ResidualToleranceField
        function ResidualToleranceFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: MaxIterationsField
        function MaxIterationsFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: PlotLeftField
        function PlotLeftFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: PlotRightField
        function PlotRightFieldValueChanged(app, event)
            app.markDirty();
        end

        % Button pushed function: ResetButton
        function ResetButtonButtonPushed(app, event)
            app.resetDefaults();
        end

        % Value changed function: HistoryMethodDropDown
        function HistoryMethodDropDownValueChanged(app, event)
            app.refreshHistory();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [0.95 0.96 0.98];
            app.UIFigure.Position = [100 80 1320 860];
            app.UIFigure.Name = '实验二 · 非线性方程求根';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @UIFigureSizeChanged, true);
            app.UIFigure.Tag = 'exp2.MainWindow';

            % Create ShellGrid
            app.ShellGrid = uigridlayout(app.UIFigure);
            app.ShellGrid.ColumnWidth = {330, '1x'};
            app.ShellGrid.RowHeight = {72, '1x'};
            app.ShellGrid.ColumnSpacing = 12;
            app.ShellGrid.RowSpacing = 12;
            app.ShellGrid.Padding = [16 14 16 16];
            app.ShellGrid.Tag = 'exp2.Shell';

            % Create exp2_WorkspaceTabs
            app.exp2_WorkspaceTabs = uitabgroup(app.ShellGrid);
            app.exp2_WorkspaceTabs.Tag = 'exp2.WorkspaceTabs';
            app.exp2_WorkspaceTabs.Layout.Row = 2;
            app.exp2_WorkspaceTabs.Layout.Column = 2;

            % Create exp2_PlotTab
            app.exp2_PlotTab = uitab(app.exp2_WorkspaceTabs);
            app.exp2_PlotTab.Title = '图像';
            app.exp2_PlotTab.Tag = 'exp2.PlotTab';

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.exp2_PlotTab);
            app.GridLayout_2.ColumnWidth = {'1x'};
            app.GridLayout_2.RowHeight = {'1.2x', '1x'};
            app.GridLayout_2.RowSpacing = 12;
            app.GridLayout_2.Padding = [12 12 12 12];

            % Create ConvergenceAxes
            app.ConvergenceAxes = uiaxes(app.GridLayout_2);
            app.ConvergenceAxes.FontName = 'Microsoft YaHei UI';
            app.ConvergenceAxes.XColor = [0.28 0.32 0.39];
            app.ConvergenceAxes.YColor = [0.28 0.32 0.39];
            app.ConvergenceAxes.Box = 'on';
            app.ConvergenceAxes.FontSize = 11;
            app.ConvergenceAxes.Layout.Row = 2;
            app.ConvergenceAxes.Layout.Column = 1;
            app.ConvergenceAxes.Tag = 'exp2.ConvergenceAxes';

            % Create FunctionAxes
            app.FunctionAxes = uiaxes(app.GridLayout_2);
            app.FunctionAxes.FontName = 'Microsoft YaHei UI';
            app.FunctionAxes.XColor = [0.28 0.32 0.39];
            app.FunctionAxes.YColor = [0.28 0.32 0.39];
            app.FunctionAxes.Box = 'on';
            app.FunctionAxes.FontSize = 11;
            app.FunctionAxes.Layout.Row = 1;
            app.FunctionAxes.Layout.Column = 1;
            app.FunctionAxes.Tag = 'exp2.FunctionAxes';

            % Create exp2_ResultTab
            app.exp2_ResultTab = uitab(app.exp2_WorkspaceTabs);
            app.exp2_ResultTab.Title = '结果与验证';
            app.exp2_ResultTab.Tag = 'exp2.ResultTab';

            % Create GridLayout_3
            app.GridLayout_3 = uigridlayout(app.exp2_ResultTab);
            app.GridLayout_3.ColumnWidth = {'1x'};
            app.GridLayout_3.RowHeight = {'1x', '1.2x'};
            app.GridLayout_3.RowSpacing = 12;
            app.GridLayout_3.Padding = [12 12 12 12];

            % Create Panel_1
            app.Panel_1 = uipanel(app.GridLayout_3);
            app.Panel_1.Title = 'roots(coefficients) 验证（包含复根）';
            app.Panel_1.BackgroundColor = [1 1 1];
            app.Panel_1.Layout.Row = 2;
            app.Panel_1.Layout.Column = 1;
            app.Panel_1.FontName = 'Microsoft YaHei UI';

            % Create GridLayout_5
            app.GridLayout_5 = uigridlayout(app.Panel_1);
            app.GridLayout_5.ColumnWidth = {'1x'};
            app.GridLayout_5.RowHeight = {'1x'};
            app.GridLayout_5.Padding = [0 0 0 0];

            % Create VerificationTable
            app.VerificationTable = uitable(app.GridLayout_5);
            app.VerificationTable.ColumnName = {'根 z'; 'Re(z)'; 'Im(z)'; '残差 abs(f)'};
            app.VerificationTable.ColumnEditable = [false false false false];
            app.VerificationTable.Tag = 'exp2.VerificationTable';
            app.VerificationTable.Layout.Row = 1;
            app.VerificationTable.Layout.Column = 1;

            % Create Panel
            app.Panel = uipanel(app.GridLayout_3);
            app.Panel.Title = '迭代结果';
            app.Panel.BackgroundColor = [1 1 1];
            app.Panel.Layout.Row = 1;
            app.Panel.Layout.Column = 1;
            app.Panel.FontName = 'Microsoft YaHei UI';

            % Create GridLayout_4
            app.GridLayout_4 = uigridlayout(app.Panel);
            app.GridLayout_4.ColumnWidth = {'1x'};
            app.GridLayout_4.RowHeight = {'1x'};
            app.GridLayout_4.Padding = [0 0 0 0];

            % Create SummaryTable
            app.SummaryTable = uitable(app.GridLayout_4);
            app.SummaryTable.ColumnName = {'方法'; '近似根'; 'f(x)'; '残差 abs(f)'; '迭代数'; '状态'};
            app.SummaryTable.ColumnEditable = [false false false false false false];
            app.SummaryTable.Tag = 'exp2.SummaryTable';
            app.SummaryTable.Layout.Row = 1;
            app.SummaryTable.Layout.Column = 1;

            % Create exp2_HistoryTab
            app.exp2_HistoryTab = uitab(app.exp2_WorkspaceTabs);
            app.exp2_HistoryTab.Title = '迭代过程';
            app.exp2_HistoryTab.Tag = 'exp2.HistoryTab';

            % Create GridLayout_6
            app.GridLayout_6 = uigridlayout(app.exp2_HistoryTab);
            app.GridLayout_6.ColumnWidth = {'1x'};
            app.GridLayout_6.RowHeight = {42, '1x'};
            app.GridLayout_6.RowSpacing = 8;
            app.GridLayout_6.Padding = [12 12 12 12];

            % Create HistoryTable
            app.HistoryTable = uitable(app.GridLayout_6);
            app.HistoryTable.ColumnName = {'k'; 'xₖ'; 'f(xₖ)'; '残差 abs(f)'; '步长/半区间'; '下界'; '上界'};
            app.HistoryTable.ColumnEditable = [false false false false false false false];
            app.HistoryTable.Tag = 'exp2.HistoryTable';
            app.HistoryTable.Layout.Row = 2;
            app.HistoryTable.Layout.Column = 1;

            % Create HistoryMethodDropDown
            app.HistoryMethodDropDown = uidropdown(app.GridLayout_6);
            app.HistoryMethodDropDown.Items = {'Newton', '二分法'};
            app.HistoryMethodDropDown.ValueChangedFcn = createCallbackFcn(app, @HistoryMethodDropDownValueChanged, true);
            app.HistoryMethodDropDown.Tag = 'exp2.HistoryMethod';
            app.HistoryMethodDropDown.FontName = 'Microsoft YaHei UI';
            app.HistoryMethodDropDown.Layout.Row = 1;
            app.HistoryMethodDropDown.Layout.Column = 1;
            app.HistoryMethodDropDown.Value = 'Newton';

            % Create exp2_SettingsPanel
            app.exp2_SettingsPanel = uipanel(app.ShellGrid);
            app.exp2_SettingsPanel.Title = '计算参数';
            app.exp2_SettingsPanel.BackgroundColor = [1 1 1];
            app.exp2_SettingsPanel.Tag = 'exp2.SettingsPanel';
            app.exp2_SettingsPanel.Layout.Row = 2;
            app.exp2_SettingsPanel.Layout.Column = 1;
            app.exp2_SettingsPanel.FontName = 'Microsoft YaHei UI';
            app.exp2_SettingsPanel.FontWeight = 'bold';
            app.exp2_SettingsPanel.Scrollable = 'on';
            app.exp2_SettingsPanel.FontSize = 15;

            % Create GridLayout
            app.GridLayout = uigridlayout(app.exp2_SettingsPanel);
            app.GridLayout.ColumnWidth = {128, '1x'};
            app.GridLayout.RowHeight = {36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36};
            app.GridLayout.ColumnSpacing = 8;
            app.GridLayout.RowSpacing = 5;
            app.GridLayout.Padding = [14 12 14 12];
            app.GridLayout.Scrollable = 'on';

            % Create exp2_ParameterHint
            app.exp2_ParameterHint = uilabel(app.GridLayout);
            app.exp2_ParameterHint.Tag = 'exp2.ParameterHint';
            app.exp2_ParameterHint.FontName = 'Microsoft YaHei UI';
            app.exp2_ParameterHint.FontSize = 11;
            app.exp2_ParameterHint.FontColor = [0.34 0.39 0.47];
            app.exp2_ParameterHint.Layout.Row = 13;
            app.exp2_ParameterHint.Layout.Column = [1 2];
            app.exp2_ParameterHint.Text = 'Newton 初值可含虚部；二分法只接受实区间。';

            % Create GridLayout_1
            app.GridLayout_1 = uigridlayout(app.GridLayout);
            app.GridLayout_1.RowHeight = {'1x'};
            app.GridLayout_1.ColumnSpacing = 8;
            app.GridLayout_1.Padding = [0 0 0 0];
            app.GridLayout_1.Layout.Row = 12;
            app.GridLayout_1.Layout.Column = [1 2];

            % Create ResetButton
            app.ResetButton = uibutton(app.GridLayout_1, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonButtonPushed, true);
            app.ResetButton.Tag = 'exp2.Reset';
            app.ResetButton.FontName = 'Microsoft YaHei UI';
            app.ResetButton.Layout.Row = 1;
            app.ResetButton.Layout.Column = [1 2];
            app.ResetButton.Text = '恢复默认';

            % Create PlotRightField
            app.PlotRightField = uieditfield(app.GridLayout, 'numeric');
            app.PlotRightField.ValueChangedFcn = createCallbackFcn(app, @PlotRightFieldValueChanged, true);
            app.PlotRightField.Tag = 'exp2.PlotRight';
            app.PlotRightField.FontName = 'Consolas';
            app.PlotRightField.FontSize = 14;
            app.PlotRightField.Layout.Row = 11;
            app.PlotRightField.Layout.Column = 2;
            app.PlotRightField.Value = 6;

            % Create Label_10
            app.Label_10 = uilabel(app.GridLayout);
            app.Label_10.HorizontalAlignment = 'right';
            app.Label_10.FontName = 'Microsoft YaHei UI';
            app.Label_10.FontSize = 14;
            app.Label_10.FontColor = [0.22 0.27 0.34];
            app.Label_10.Layout.Row = 11;
            app.Label_10.Layout.Column = 1;
            app.Label_10.Text = '绘图 x 最大值';

            % Create PlotLeftField
            app.PlotLeftField = uieditfield(app.GridLayout, 'numeric');
            app.PlotLeftField.ValueChangedFcn = createCallbackFcn(app, @PlotLeftFieldValueChanged, true);
            app.PlotLeftField.Tag = 'exp2.PlotLeft';
            app.PlotLeftField.FontName = 'Consolas';
            app.PlotLeftField.FontSize = 14;
            app.PlotLeftField.Layout.Row = 10;
            app.PlotLeftField.Layout.Column = 2;
            app.PlotLeftField.Value = -5;

            % Create Label_9
            app.Label_9 = uilabel(app.GridLayout);
            app.Label_9.HorizontalAlignment = 'right';
            app.Label_9.FontName = 'Microsoft YaHei UI';
            app.Label_9.FontSize = 14;
            app.Label_9.FontColor = [0.22 0.27 0.34];
            app.Label_9.Layout.Row = 10;
            app.Label_9.Layout.Column = 1;
            app.Label_9.Text = '绘图 x 最小值';

            % Create MaxIterationsField
            app.MaxIterationsField = uieditfield(app.GridLayout, 'numeric');
            app.MaxIterationsField.ValueChangedFcn = createCallbackFcn(app, @MaxIterationsFieldValueChanged, true);
            app.MaxIterationsField.Tag = 'exp2.MaxIterations';
            app.MaxIterationsField.FontName = 'Consolas';
            app.MaxIterationsField.FontSize = 14;
            app.MaxIterationsField.Layout.Row = 9;
            app.MaxIterationsField.Layout.Column = 2;
            app.MaxIterationsField.Value = 100;

            % Create Label_8
            app.Label_8 = uilabel(app.GridLayout);
            app.Label_8.HorizontalAlignment = 'right';
            app.Label_8.FontName = 'Microsoft YaHei UI';
            app.Label_8.FontSize = 14;
            app.Label_8.FontColor = [0.22 0.27 0.34];
            app.Label_8.Layout.Row = 9;
            app.Label_8.Layout.Column = 1;
            app.Label_8.Text = '最大迭代次数';

            % Create ResidualToleranceField
            app.ResidualToleranceField = uieditfield(app.GridLayout, 'numeric');
            app.ResidualToleranceField.ValueChangedFcn = createCallbackFcn(app, @ResidualToleranceFieldValueChanged, true);
            app.ResidualToleranceField.Tag = 'exp2.ResidualTolerance';
            app.ResidualToleranceField.FontName = 'Consolas';
            app.ResidualToleranceField.FontSize = 14;
            app.ResidualToleranceField.Layout.Row = 8;
            app.ResidualToleranceField.Layout.Column = 2;
            app.ResidualToleranceField.Value = 1e-10;

            % Create Label_7
            app.Label_7 = uilabel(app.GridLayout);
            app.Label_7.HorizontalAlignment = 'right';
            app.Label_7.FontName = 'Microsoft YaHei UI';
            app.Label_7.FontSize = 14;
            app.Label_7.FontColor = [0.22 0.27 0.34];
            app.Label_7.Layout.Row = 8;
            app.Label_7.Layout.Column = 1;
            app.Label_7.Text = '残差容差';

            % Create XToleranceField
            app.XToleranceField = uieditfield(app.GridLayout, 'numeric');
            app.XToleranceField.ValueChangedFcn = createCallbackFcn(app, @XToleranceFieldValueChanged, true);
            app.XToleranceField.Tag = 'exp2.XTolerance';
            app.XToleranceField.FontName = 'Consolas';
            app.XToleranceField.FontSize = 14;
            app.XToleranceField.Layout.Row = 7;
            app.XToleranceField.Layout.Column = 2;
            app.XToleranceField.Value = 1e-10;

            % Create Label_6
            app.Label_6 = uilabel(app.GridLayout);
            app.Label_6.HorizontalAlignment = 'right';
            app.Label_6.FontName = 'Microsoft YaHei UI';
            app.Label_6.FontSize = 14;
            app.Label_6.FontColor = [0.22 0.27 0.34];
            app.Label_6.Layout.Row = 7;
            app.Label_6.Layout.Column = 1;
            app.Label_6.Text = '相对 x 容差';

            % Create BracketRightField
            app.BracketRightField = uieditfield(app.GridLayout, 'numeric');
            app.BracketRightField.ValueChangedFcn = createCallbackFcn(app, @BracketRightFieldValueChanged, true);
            app.BracketRightField.Tag = 'exp2.BracketRight';
            app.BracketRightField.FontName = 'Consolas';
            app.BracketRightField.FontSize = 14;
            app.BracketRightField.Layout.Row = 6;
            app.BracketRightField.Layout.Column = 2;
            app.BracketRightField.Value = 1.8;

            % Create Label_5
            app.Label_5 = uilabel(app.GridLayout);
            app.Label_5.HorizontalAlignment = 'right';
            app.Label_5.FontName = 'Microsoft YaHei UI';
            app.Label_5.FontSize = 14;
            app.Label_5.FontColor = [0.22 0.27 0.34];
            app.Label_5.Layout.Row = 6;
            app.Label_5.Layout.Column = 1;
            app.Label_5.Text = '二分右端点';

            % Create BracketLeftField
            app.BracketLeftField = uieditfield(app.GridLayout, 'numeric');
            app.BracketLeftField.ValueChangedFcn = createCallbackFcn(app, @BracketLeftFieldValueChanged, true);
            app.BracketLeftField.Tag = 'exp2.BracketLeft';
            app.BracketLeftField.FontName = 'Consolas';
            app.BracketLeftField.FontSize = 14;
            app.BracketLeftField.Layout.Row = 5;
            app.BracketLeftField.Layout.Column = 2;
            app.BracketLeftField.Value = 1.7;

            % Create Label_4
            app.Label_4 = uilabel(app.GridLayout);
            app.Label_4.HorizontalAlignment = 'right';
            app.Label_4.FontName = 'Microsoft YaHei UI';
            app.Label_4.FontSize = 14;
            app.Label_4.FontColor = [0.22 0.27 0.34];
            app.Label_4.Layout.Row = 5;
            app.Label_4.Layout.Column = 1;
            app.Label_4.Text = '二分左端点';

            % Create InitialImagField
            app.InitialImagField = uieditfield(app.GridLayout, 'numeric');
            app.InitialImagField.ValueChangedFcn = createCallbackFcn(app, @InitialImagFieldValueChanged, true);
            app.InitialImagField.Tag = 'exp2.InitialImag';
            app.InitialImagField.FontName = 'Consolas';
            app.InitialImagField.FontSize = 14;
            app.InitialImagField.Layout.Row = 4;
            app.InitialImagField.Layout.Column = 2;

            % Create Label_3
            app.Label_3 = uilabel(app.GridLayout);
            app.Label_3.HorizontalAlignment = 'right';
            app.Label_3.FontName = 'Microsoft YaHei UI';
            app.Label_3.FontSize = 14;
            app.Label_3.FontColor = [0.22 0.27 0.34];
            app.Label_3.Layout.Row = 4;
            app.Label_3.Layout.Column = 1;
            app.Label_3.Text = '初值 Im(x₀)';

            % Create InitialRealField
            app.InitialRealField = uieditfield(app.GridLayout, 'numeric');
            app.InitialRealField.ValueChangedFcn = createCallbackFcn(app, @InitialRealFieldValueChanged, true);
            app.InitialRealField.Tag = 'exp2.InitialReal';
            app.InitialRealField.FontName = 'Consolas';
            app.InitialRealField.FontSize = 14;
            app.InitialRealField.Layout.Row = 3;
            app.InitialRealField.Layout.Column = 2;
            app.InitialRealField.Value = 1.8;

            % Create Label_2
            app.Label_2 = uilabel(app.GridLayout);
            app.Label_2.HorizontalAlignment = 'right';
            app.Label_2.FontName = 'Microsoft YaHei UI';
            app.Label_2.FontSize = 14;
            app.Label_2.FontColor = [0.22 0.27 0.34];
            app.Label_2.Layout.Row = 3;
            app.Label_2.Layout.Column = 1;
            app.Label_2.Text = '初值 Re(x₀)';

            % Create CoefficientsField
            app.CoefficientsField = uieditfield(app.GridLayout, 'text');
            app.CoefficientsField.ValueChangedFcn = createCallbackFcn(app, @CoefficientsFieldValueChanged, true);
            app.CoefficientsField.Tag = 'exp2.Coefficients';
            app.CoefficientsField.FontName = 'Consolas';
            app.CoefficientsField.Tooltip = '按 x 的降幂输入有限实数，以逗号、空格或分号分隔。';
            app.CoefficientsField.Layout.Row = 2;
            app.CoefficientsField.Layout.Column = 2;
            app.CoefficientsField.Value = '1, -5, -12, 76, -79';

            % Create Label_1
            app.Label_1 = uilabel(app.GridLayout);
            app.Label_1.HorizontalAlignment = 'right';
            app.Label_1.FontName = 'Microsoft YaHei UI';
            app.Label_1.FontSize = 14;
            app.Label_1.FontColor = [0.22 0.27 0.34];
            app.Label_1.Layout.Row = 2;
            app.Label_1.Layout.Column = 1;
            app.Label_1.Text = '系数（降幂）';

            % Create PresetDropDown
            app.PresetDropDown = uidropdown(app.GridLayout);
            app.PresetDropDown.Items = {'方程 f₁', '方程 f₂', '自定义'};
            app.PresetDropDown.ValueChangedFcn = createCallbackFcn(app, @PresetDropDownValueChanged, true);
            app.PresetDropDown.Tag = 'exp2.Preset';
            app.PresetDropDown.FontName = 'Microsoft YaHei UI';
            app.PresetDropDown.Layout.Row = 1;
            app.PresetDropDown.Layout.Column = 2;
            app.PresetDropDown.Value = '方程 f₁';

            % Create Label
            app.Label = uilabel(app.GridLayout);
            app.Label.HorizontalAlignment = 'right';
            app.Label.FontName = 'Microsoft YaHei UI';
            app.Label.FontSize = 14;
            app.Label.FontColor = [0.22 0.27 0.34];
            app.Label.Layout.Row = 1;
            app.Label.Layout.Column = 1;
            app.Label.Text = '方程';

            % Create exp2_Header
            app.exp2_Header = uipanel(app.ShellGrid);
            app.exp2_Header.BackgroundColor = [1 1 1];
            app.exp2_Header.Tag = 'exp2.Header';
            app.exp2_Header.Layout.Row = 1;
            app.exp2_Header.Layout.Column = [1 2];

            % Create HeaderGrid
            app.HeaderGrid = uigridlayout(app.exp2_Header);
            app.HeaderGrid.ColumnWidth = {'1x', 205, 470};
            app.HeaderGrid.RowHeight = {'1x'};
            app.HeaderGrid.Padding = [16 8 12 8];

            % Create HeaderActions
            app.HeaderActions = uigridlayout(app.HeaderGrid);
            app.HeaderActions.ColumnWidth = {150, 95, 95, 95};
            app.HeaderActions.RowHeight = {'1x'};
            app.HeaderActions.ColumnSpacing = 8;
            app.HeaderActions.Padding = [0 0 0 0];
            app.HeaderActions.Tag = 'exp2.HeaderActions';
            app.HeaderActions.Layout.Row = 1;
            app.HeaderActions.Layout.Column = 3;

            % Create ExportPngButton
            app.ExportPngButton = uibutton(app.HeaderActions, 'push');
            app.ExportPngButton.ButtonPushedFcn = createCallbackFcn(app, @ExportPngButtonButtonPushed, true);
            app.ExportPngButton.Tag = 'exp2.ExportPng';
            app.ExportPngButton.FontName = 'Microsoft YaHei UI';
            app.ExportPngButton.Enable = 'off';
            app.ExportPngButton.Layout.Row = 1;
            app.ExportPngButton.Layout.Column = 4;
            app.ExportPngButton.Text = '函数图 PNG';

            % Create ExportCsvButton
            app.ExportCsvButton = uibutton(app.HeaderActions, 'push');
            app.ExportCsvButton.ButtonPushedFcn = createCallbackFcn(app, @ExportCsvButtonButtonPushed, true);
            app.ExportCsvButton.Tag = 'exp2.ExportCsv';
            app.ExportCsvButton.FontName = 'Microsoft YaHei UI';
            app.ExportCsvButton.Enable = 'off';
            app.ExportCsvButton.Layout.Row = 1;
            app.ExportCsvButton.Layout.Column = 3;
            app.ExportCsvButton.Text = '迭代 CSV';

            % Create ExportMatButton
            app.ExportMatButton = uibutton(app.HeaderActions, 'push');
            app.ExportMatButton.ButtonPushedFcn = createCallbackFcn(app, @ExportMatButtonButtonPushed, true);
            app.ExportMatButton.Tag = 'exp2.ExportMat';
            app.ExportMatButton.FontName = 'Microsoft YaHei UI';
            app.ExportMatButton.Enable = 'off';
            app.ExportMatButton.Layout.Row = 1;
            app.ExportMatButton.Layout.Column = 2;
            app.ExportMatButton.Text = '导出 MAT';

            % Create RunButton
            app.RunButton = uibutton(app.HeaderActions, 'push');
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonButtonPushed, true);
            app.RunButton.Tag = 'exp2.Run';
            app.RunButton.BackgroundColor = [0.12 0.39 0.82];
            app.RunButton.FontName = 'Microsoft YaHei UI';
            app.RunButton.FontSize = 14;
            app.RunButton.FontWeight = 'bold';
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.Layout.Row = 1;
            app.RunButton.Layout.Column = 1;
            app.RunButton.Text = '运行两种方法';

            % Create StatusLabel
            app.StatusLabel = uilabel(app.HeaderGrid);
            app.StatusLabel.Tag = 'exp2.Status';
            app.StatusLabel.HorizontalAlignment = 'center';
            app.StatusLabel.FontName = 'Microsoft YaHei UI';
            app.StatusLabel.FontSize = 13;
            app.StatusLabel.FontColor = [0.31 0.36 0.44];
            app.StatusLabel.Layout.Row = 1;
            app.StatusLabel.Layout.Column = 2;
            app.StatusLabel.Text = '待运行';

            % Create HeaderTitle
            app.HeaderTitle = uilabel(app.HeaderGrid);
            app.HeaderTitle.Tag = 'exp2.Title';
            app.HeaderTitle.FontName = 'Microsoft YaHei UI';
            app.HeaderTitle.FontSize = 20;
            app.HeaderTitle.FontWeight = 'bold';
            app.HeaderTitle.FontColor = [0.12 0.17 0.25];
            app.HeaderTitle.Layout.Row = 1;
            app.HeaderTitle.Layout.Column = 1;
            app.HeaderTitle.Text = '非线性方程求根';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = NumericalRootsApp

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end