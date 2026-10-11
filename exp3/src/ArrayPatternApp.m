classdef ArrayPatternApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        ShellGrid               matlab.ui.container.GridLayout
        HeaderPanel             matlab.ui.container.Panel
        HeaderGrid              matlab.ui.container.GridLayout
        HeaderTitle             matlab.ui.control.Label
        ActionGrid              matlab.ui.container.GridLayout
        ExportMatButton         matlab.ui.control.Button
        ExportCsvButton         matlab.ui.control.Button
        ExportPngButton         matlab.ui.control.Button
        BodyGrid                matlab.ui.container.GridLayout
        ParameterPanel          matlab.ui.container.Panel
        ParameterGrid           matlab.ui.container.GridLayout
        Label                   matlab.ui.control.Label
        ElementCountField       matlab.ui.control.NumericEditField
        Label_1                 matlab.ui.control.Label
        SpacingField            matlab.ui.control.NumericEditField
        Label_2                 matlab.ui.control.Label
        WavelengthField         matlab.ui.control.NumericEditField
        Label_3                 matlab.ui.control.Label
        SteeringField           matlab.ui.control.NumericEditField
        Label_4                 matlab.ui.control.Label
        AngleStartField         matlab.ui.control.NumericEditField
        Label_5                 matlab.ui.control.Label
        AngleEndField           matlab.ui.control.NumericEditField
        Label_6                 matlab.ui.control.Label
        SampleCountField        matlab.ui.control.NumericEditField
        NormalizeCheckBox       matlab.ui.control.CheckBox
        Label_7                 matlab.ui.control.Label
        CartesianScaleDropDown  matlab.ui.control.DropDown
        Label_8                 matlab.ui.control.Label
        DecibelFloorField       matlab.ui.control.NumericEditField
        RunButton               matlab.ui.control.Button
        ResetButton             matlab.ui.control.Button
        ParameterHintLabel      matlab.ui.control.Label
        ResultsPanel            matlab.ui.container.Panel
        ChartGrid               matlab.ui.container.GridLayout
        CartesianPanel          matlab.ui.container.Panel
        GridLayout              matlab.ui.container.GridLayout
        CartesianAxes           matlab.ui.control.UIAxes
        PolarPanel              matlab.ui.container.Panel
        GridLayout_1            matlab.ui.container.GridLayout
        StatusLabel             matlab.ui.control.Label
    end

    properties (Access = public)
        Result struct = struct()
    end

    properties (Access = private)
        Busy logical = false
        Closing logical = false
        UpdatingFields logical = false

        PolarAxes = []

    end

    methods (Access = private)








        function applyResponsiveLayout(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure) || ...
                    isempty(app.BodyGrid) || isempty(app.ChartGrid)
                return;
            end
            compact = app.UIFigure.Position(3) < 1120;
            if compact
                app.ShellGrid.RowHeight = {96, '1x', 34};
                app.HeaderGrid.RowHeight = {26, 36};
                app.HeaderGrid.ColumnWidth = {'1x'};
                app.HeaderTitle.Layout.Row = 1;
                app.HeaderTitle.Layout.Column = 1;
                app.ActionGrid.Layout.Row = 2;
                app.ActionGrid.Layout.Column = 1;
                app.BodyGrid.ColumnWidth = {300, '1x'};
                app.BodyGrid.RowHeight = {'1x'};
                app.ParameterPanel.Layout.Row = 1;
                app.ParameterPanel.Layout.Column = 1;
                app.ResultsPanel.Layout.Row = 1;
                app.ResultsPanel.Layout.Column = 2;
                app.ChartGrid.RowHeight = {'1x', '1x'};
                app.ChartGrid.ColumnWidth = {'1x'};
                app.CartesianPanel.Layout.Row = 1;
                app.CartesianPanel.Layout.Column = 1;
                app.PolarPanel.Layout.Row = 2;
                app.PolarPanel.Layout.Column = 1;
            else
                app.ShellGrid.RowHeight = {70, '1x', 34};
                app.HeaderGrid.RowHeight = {'1x'};
                app.HeaderGrid.ColumnWidth = {'1x', 330};
                app.HeaderTitle.Layout.Row = 1;
                app.HeaderTitle.Layout.Column = 1;
                app.ActionGrid.Layout.Row = 1;
                app.ActionGrid.Layout.Column = 2;
                app.BodyGrid.ColumnWidth = {320, '1x'};
                app.BodyGrid.RowHeight = {'1x'};
                app.ParameterPanel.Layout.Row = 1;
                app.ParameterPanel.Layout.Column = 1;
                app.ResultsPanel.Layout.Row = 1;
                app.ResultsPanel.Layout.Column = 2;
                app.ChartGrid.RowHeight = {'1x'};
                app.ChartGrid.ColumnWidth = {'1x', '1x'};
                app.CartesianPanel.Layout.Row = 1;
                app.CartesianPanel.Layout.Column = 1;
                app.PolarPanel.Layout.Row = 1;
                app.PolarPanel.Layout.Column = 2;
            end
        end

        function runPattern(app)
            if ~app.beginOperation('正在计算方向图…')
                return;
            end
            app.Result = struct();
            app.renderEmpty();
            try
                result = exp3_pattern(app.collectConfig());
                app.Result = result;
                app.renderResult(result);
                app.setStatus(sprintf('计算完成 · %d 个阵元 · %d 个角度点', ...
                    result.Config.ElementCount, result.Config.SampleCount), 'success');
            catch exception
                app.Result = struct();
                app.renderEmpty();
                app.showError(exception);
            end
            app.finishOperation();
        end

        function config = collectConfig(app)
            if strcmp(app.CartesianScaleDropDown.Value, 'dB')
                scale = 'db';
            else
                scale = 'linear';
            end
            config = struct( ...
                'ElementCount', app.ElementCountField.Value, ...
                'SpacingMeters', app.SpacingField.Value, ...
                'WavelengthMeters', app.WavelengthField.Value, ...
                'SteeringAngleDeg', app.SteeringField.Value, ...
                'AngleStartDeg', app.AngleStartField.Value, ...
                'AngleEndDeg', app.AngleEndField.Value, ...
                'SampleCount', app.SampleCountField.Value, ...
                'Normalize', app.NormalizeCheckBox.Value, ...
                'CartesianScale', scale, ...
                'DecibelFloor', app.DecibelFloorField.Value);
        end

        function parametersChanged(app)
            if app.Busy || app.UpdatingFields || app.Closing
                return;
            end
            app.Result = struct();
            app.renderEmpty();
            app.setStatus('参数已修改 · 请重新计算', 'pending');
            app.updateActionState();
        end

        function resetDefaults(app)
            if app.Busy || app.Closing
                return;
            end
            defaults = exp3_defaults();
            if strcmp(defaults.CartesianScale, 'db')
                defaultScaleLabel = 'dB';
            else
                defaultScaleLabel = '线性';
            end
            app.UpdatingFields = true;
            app.ElementCountField.Value = defaults.ElementCount;
            app.SpacingField.Value = defaults.SpacingMeters;
            app.WavelengthField.Value = defaults.WavelengthMeters;
            app.SteeringField.Value = defaults.SteeringAngleDeg;
            app.AngleStartField.Value = defaults.AngleStartDeg;
            app.AngleEndField.Value = defaults.AngleEndDeg;
            app.SampleCountField.Value = defaults.SampleCount;
            app.NormalizeCheckBox.Value = defaults.Normalize;
            app.CartesianScaleDropDown.Value = defaultScaleLabel;
            app.DecibelFloorField.Value = defaults.DecibelFloor;
            app.UpdatingFields = false;
            app.Result = struct();
            app.renderEmpty();
            app.setStatus('已恢复默认参数', 'idle');
            app.updateActionState();
        end

        function renderResult(app, result)
            colors = app.theme();
            cla(app.CartesianAxes);
            plot(app.CartesianAxes, result.AngleDegrees, ...
                result.CartesianValues, 'Color', colors.ChartA, ...
                'LineWidth', 1.8);
            grid(app.CartesianAxes, 'on');
            app.CartesianAxes.XLim = [result.Config.AngleStartDeg, ...
                result.Config.AngleEndDeg];
            xlabel(app.CartesianAxes, '角度 φ / °');
            if strcmp(result.Config.CartesianScale, 'db')
                ylabel(app.CartesianAxes, '相对阵列因子 / dB（峰值 0 dB）');
                app.CartesianAxes.YLim = [result.Config.DecibelFloor, 1];
            elseif result.Config.Normalize
                ylabel(app.CartesianAxes, '归一化幅度 |B(φ)| / N');
                app.CartesianAxes.YLim = [0, max(1.05, ...
                    1.05 .* max(result.CartesianValues))];
            else
                ylabel(app.CartesianAxes, '未归一化幅度 |B(φ)|');
                app.CartesianAxes.YLim = [0, max(1, ...
                    1.05 .* max(result.CartesianValues))];
            end
            title(app.CartesianAxes, app.plotTitle(result.Config), ...
                'Interpreter', 'none', 'FontSize', 13);

            cla(app.PolarAxes);
            polarplot(app.PolarAxes, result.AngleRadians, ...
                result.PolarMagnitude, 'Color', colors.ChartA, ...
                'LineWidth', 1.8);
            if result.Config.Normalize
                rlim(app.PolarAxes, [0 1.05]);
            else
                rlim(app.PolarAxes, [0, 1.05 .* result.Config.ElementCount]);
            end
            title(app.PolarAxes, '线性幅度', 'FontName', 'Microsoft YaHei', ...
                'FontSize', 12, 'Color', colors.TextPrimary);
            app.updateActionState();
        end

        function renderEmpty(app)
            if isempty(app.CartesianAxes) || isempty(app.PolarAxes)
                return;
            end
            cla(app.CartesianAxes);
            grid(app.CartesianAxes, 'on');
            xlabel(app.CartesianAxes, '角度 φ / °');
            ylabel(app.CartesianAxes, '阵列因子');
            title(app.CartesianAxes, '设置参数后计算', ...
                'FontName', 'Microsoft YaHei', 'FontSize', 13);
            cla(app.PolarAxes);
            title(app.PolarAxes, '设置参数后计算', ...
                'FontName', 'Microsoft YaHei', 'FontSize', 12);
            app.updateActionState();
        end

        function styleCartesianAxes(app)
            colors = app.theme();
            app.CartesianAxes.Color = colors.Surface;
            app.CartesianAxes.XColor = colors.TextSecondary;
            app.CartesianAxes.YColor = colors.TextSecondary;
            app.CartesianAxes.FontName = 'Microsoft YaHei';
            app.CartesianAxes.FontSize = 12;
            app.CartesianAxes.Box = 'on';
            grid(app.CartesianAxes, 'on');
        end

        function stylePolarAxes(app)
            colors = app.theme();
            app.PolarAxes.Color = colors.Surface;
            app.PolarAxes.FontName = 'Microsoft YaHei';
            app.PolarAxes.FontSize = 11;
            app.PolarAxes.ThetaZeroLocation = 'right';
            app.PolarAxes.ThetaDir = 'counterclockwise';
            app.PolarAxes.GridColor = colors.Border;
            app.PolarAxes.GridAlpha = 0.5;
        end

        function value = plotTitle(~, config)
            value = sprintf('N=%d · d/λ=%.4g · φ₀=%.4g°', ...
                config.ElementCount, ...
                config.SpacingMeters / config.WavelengthMeters, ...
                config.SteeringAngleDeg);
        end

        function started = beginOperation(app, message)
            started = ~app.Busy && ~app.Closing && ...
                ~isempty(app.UIFigure) && isvalid(app.UIFigure);
            if ~started
                return;
            end
            app.Busy = true;
            app.setStatus(message, 'busy');
            app.updateActionState();
            drawnow limitrate nocallbacks
        end

        function finishOperation(app)
            if app.Closing || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            app.Busy = false;
            app.updateActionState();
            drawnow limitrate nocallbacks
        end

        function updateActionState(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure) || ...
                    isempty(app.RunButton)
                return;
            end
            available = ~app.Busy && ~app.Closing;
            inputs = {app.ElementCountField, app.SpacingField, ...
                app.WavelengthField, app.SteeringField, ...
                app.AngleStartField, app.AngleEndField, ...
                app.SampleCountField, app.NormalizeCheckBox, ...
                app.CartesianScaleDropDown, app.DecibelFloorField};
            for k = 1:numel(inputs)
                inputs{k}.Enable = app.onOff(available);
            end
            app.RunButton.Enable = app.onOff(available);
            app.ResetButton.Enable = app.onOff(available);
            hasResult = isfield(app.Result, 'RawMagnitude');
            canExport = available && hasResult;
            app.ExportMatButton.Enable = app.onOff(canExport);
            app.ExportCsvButton.Enable = app.onOff(canExport);
            app.ExportPngButton.Enable = app.onOff(canExport);
        end

        function setStatus(app, message, state)
            if isempty(app.StatusLabel) || ~isvalid(app.StatusLabel)
                return;
            end
            colors = app.theme();
            app.StatusLabel.Text = message;
            app.StatusLabel.Tooltip = message;
            switch state
                case 'success'
                    app.StatusLabel.FontColor = colors.Success;
                case 'pending'
                    app.StatusLabel.FontColor = colors.Warning;
                case 'error'
                    app.StatusLabel.FontColor = colors.Danger;
                case 'busy'
                    app.StatusLabel.FontColor = colors.Accent;
                otherwise
                    app.StatusLabel.FontColor = colors.TextMuted;
            end
        end

        function showError(app, exception)
            app.setStatus(['操作失败 · ' exception.message], 'error');
            if ~isempty(app.StatusLabel) && isvalid(app.StatusLabel)
                app.StatusLabel.Tooltip = sprintf('%s\n%s', ...
                    exception.message, exception.identifier);
            end
        end

        function exportMat(app)
            if ~isfield(app.Result, 'RawMagnitude') || ...
                    ~app.beginOperation('选择 MAT 文件保存位置')
                return;
            end
            try
                [file, folder] = uiputfile({'*.mat', 'MAT 结果 (*.mat)'}, ...
                    '保存阵列方向图', 'exp3_array_pattern.mat');
                if isequal(file, 0)
                    app.setStatus('已取消 MAT 导出', 'idle');
                else
                    result = app.Result;
                    outputPath = fullfile(folder, file);
                    save(outputPath, 'result', '-v7');
                    app.setStatus(['已保存 ' outputPath], 'success');
                end
            catch exception
                app.showError(exception);
            end
            app.finishOperation();
        end

        function exportCsv(app)
            if ~isfield(app.Result, 'RawMagnitude') || ...
                    ~app.beginOperation('选择 CSV 文件保存位置')
                return;
            end
            try
                [file, folder] = uiputfile({'*.csv', 'CSV 数据 (*.csv)'}, ...
                    '导出角度与方向图', 'exp3_array_pattern.csv');
                if isequal(file, 0)
                    app.setStatus('已取消 CSV 导出', 'idle');
                else
                    result = app.Result;
                    data = table(result.AngleDegrees, result.AngleRadians, ...
                        result.RawMagnitude, result.NormalizedMagnitude, ...
                        result.RelativeDb, 'VariableNames', ...
                        {'Angle_degrees', 'Angle_radians', 'Magnitude_raw', ...
                        'Magnitude_normalized', 'Relative_dB'});
                    outputPath = fullfile(folder, file);
                    writetable(data, outputPath, 'Encoding', 'UTF-8');
                    app.setStatus(['已保存 ' outputPath], 'success');
                end
            catch exception
                app.showError(exception);
            end
            app.finishOperation();
        end

        function exportPng(app)
            if ~isfield(app.Result, 'RawMagnitude') || ...
                    ~app.beginOperation('选择 PNG 文件保存位置')
                return;
            end
            try
                [file, folder] = uiputfile({'*.png', 'PNG 图像 (*.png)'}, ...
                    '导出当前方向图窗口', 'exp3_array_pattern.png');
                if isequal(file, 0)
                    app.setStatus('已取消 PNG 导出', 'idle');
                else
                    outputPath = fullfile(folder, file);
                    exportapp(app.UIFigure, outputPath);
                    app.setStatus(['已导出 ' outputPath], 'success');
                end
            catch exception
                app.showError(exception);
            end
            app.finishOperation();
        end

        function closeApp(app)
            if app.Busy
                app.setStatus('操作进行中，请完成后再关闭窗口', 'busy');
                return;
            end
            app.Closing = true;
            delete(app);
        end
    end

    methods (Static, Access = private)
        function colors = theme()
            colors = struct( ...
                'Canvas', [0.949 0.957 0.973], ...
                'Surface', [1 1 1], ...
                'SurfaceRaised', [0.970 0.976 0.985], ...
                'Border', [0.82 0.85 0.89], ...
                'TextPrimary', [0.12 0.15 0.21], ...
                'TextSecondary', [0.30 0.35 0.42], ...
                'TextMuted', [0.36 0.40 0.47], ...
                'Accent', [0.08 0.38 0.72], ...
                'AccentFill', [0.08 0.35 0.66], ...
                'Success', [0.08 0.42 0.24], ...
                'Warning', [0.52 0.34 0.04], ...
                'Danger', [0.68 0.12 0.16], ...
                'ChartA', [0.10 0.39 0.70]);
        end

        function value = onOff(condition)
            if condition
                value = 'on';
            else
                value = 'off';
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % PolarAxes is created in the editable polar plot container.
            app.PolarAxes = polaraxes(app.GridLayout_1);
            app.PolarAxes.Tag = 'PolarAxes';
            app.stylePolarAxes();
            app.applyResponsiveLayout();
            app.renderEmpty();
            app.updateActionState();
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            app.closeApp();
        end

        % Size changed function: UIFigure
        function UIFigureSizeChanged(app, event)
            app.applyResponsiveLayout();
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

        % Value changed function: ElementCountField
        function ElementCountFieldValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: SpacingField
        function SpacingFieldValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: WavelengthField
        function WavelengthFieldValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: SteeringField
        function SteeringFieldValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: AngleStartField
        function AngleStartFieldValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: AngleEndField
        function AngleEndFieldValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: SampleCountField
        function SampleCountFieldValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: NormalizeCheckBox
        function NormalizeCheckBoxValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: CartesianScaleDropDown
        function CartesianScaleDropDownValueChanged(app, event)
            app.parametersChanged();
        end

        % Value changed function: DecibelFloorField
        function DecibelFloorFieldValueChanged(app, event)
            app.parametersChanged();
        end

        % Button pushed function: RunButton
        function RunButtonButtonPushed(app, event)
            app.runPattern();
        end

        % Button pushed function: ResetButton
        function ResetButtonButtonPushed(app, event)
            app.resetDefaults();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [0.949 0.957 0.973];
            app.UIFigure.Position = [100 60 1500 1000];
            app.UIFigure.Name = '实验三 · 均匀线阵方向性';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @UIFigureSizeChanged, true);
            app.UIFigure.Tag = 'ArrayPatternAppFigure';

            % Create ShellGrid
            app.ShellGrid = uigridlayout(app.UIFigure);
            app.ShellGrid.ColumnWidth = {'1x'};
            app.ShellGrid.RowHeight = {70, '1x', 34};
            app.ShellGrid.RowSpacing = 12;
            app.ShellGrid.Padding = [16 16 14 14];
            app.ShellGrid.BackgroundColor = [0.949 0.957 0.973];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.ShellGrid);
            app.StatusLabel.Tag = 'StatusLabel';
            app.StatusLabel.WordWrap = 'on';
            app.StatusLabel.FontName = 'Microsoft YaHei';
            app.StatusLabel.FontSize = 13;
            app.StatusLabel.FontColor = [0.36 0.4 0.47];
            app.StatusLabel.Layout.Row = 3;
            app.StatusLabel.Layout.Column = 1;
            app.StatusLabel.Text = '就绪 · 设置参数后计算';

            % Create BodyGrid
            app.BodyGrid = uigridlayout(app.ShellGrid);
            app.BodyGrid.ColumnWidth = {320, '1x'};
            app.BodyGrid.RowHeight = {'1x'};
            app.BodyGrid.ColumnSpacing = 14;
            app.BodyGrid.Padding = [0 0 0 0];
            app.BodyGrid.Layout.Row = 2;
            app.BodyGrid.Layout.Column = 1;
            app.BodyGrid.BackgroundColor = [0.949 0.957 0.973];

            % Create ResultsPanel
            app.ResultsPanel = uipanel(app.BodyGrid);
            app.ResultsPanel.Title = '方向图';
            app.ResultsPanel.BackgroundColor = [1 1 1];
            app.ResultsPanel.Layout.Row = 1;
            app.ResultsPanel.Layout.Column = 2;
            app.ResultsPanel.FontName = 'Microsoft YaHei';
            app.ResultsPanel.FontWeight = 'bold';
            app.ResultsPanel.FontSize = 14;

            % Create ChartGrid
            app.ChartGrid = uigridlayout(app.ResultsPanel);
            app.ChartGrid.RowHeight = {'1x'};
            app.ChartGrid.ColumnSpacing = 12;
            app.ChartGrid.RowSpacing = 12;
            app.ChartGrid.Padding = [10 8 10 10];
            app.ChartGrid.BackgroundColor = [1 1 1];

            % Create PolarPanel
            app.PolarPanel = uipanel(app.ChartGrid);
            app.PolarPanel.Title = '极坐标（线性幅度）';
            app.PolarPanel.BackgroundColor = [1 1 1];
            app.PolarPanel.Layout.Row = 1;
            app.PolarPanel.Layout.Column = 2;
            app.PolarPanel.FontName = 'Microsoft YaHei';
            app.PolarPanel.FontSize = 13;

            % Create GridLayout_1
            app.GridLayout_1 = uigridlayout(app.PolarPanel);
            app.GridLayout_1.ColumnWidth = {'1x'};
            app.GridLayout_1.RowHeight = {'1x'};
            app.GridLayout_1.Padding = [4 4 4 4];
            app.GridLayout_1.BackgroundColor = [1 1 1];

            % Create CartesianPanel
            app.CartesianPanel = uipanel(app.ChartGrid);
            app.CartesianPanel.Title = '直角坐标';
            app.CartesianPanel.BackgroundColor = [1 1 1];
            app.CartesianPanel.Layout.Row = 1;
            app.CartesianPanel.Layout.Column = 1;
            app.CartesianPanel.FontName = 'Microsoft YaHei';
            app.CartesianPanel.FontSize = 13;

            % Create GridLayout
            app.GridLayout = uigridlayout(app.CartesianPanel);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.Padding = [4 4 4 4];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create CartesianAxes
            app.CartesianAxes = uiaxes(app.GridLayout);
            title(app.CartesianAxes, '设置参数后计算')
            xlabel(app.CartesianAxes, '角度 φ / °')
            ylabel(app.CartesianAxes, '阵列因子')
            app.CartesianAxes.FontName = 'Microsoft YaHei';
            app.CartesianAxes.XColor = [0.3 0.35 0.42];
            app.CartesianAxes.YColor = [0.3 0.35 0.42];
            app.CartesianAxes.Box = 'on';
            app.CartesianAxes.XGrid = 'on';
            app.CartesianAxes.YGrid = 'on';
            app.CartesianAxes.ZGrid = 'on';
            app.CartesianAxes.Layout.Row = 1;
            app.CartesianAxes.Layout.Column = 1;
            app.CartesianAxes.Tag = 'CartesianAxes';

            % Create ParameterPanel
            app.ParameterPanel = uipanel(app.BodyGrid);
            app.ParameterPanel.Title = '阵列参数';
            app.ParameterPanel.BackgroundColor = [1 1 1];
            app.ParameterPanel.Layout.Row = 1;
            app.ParameterPanel.Layout.Column = 1;
            app.ParameterPanel.FontName = 'Microsoft YaHei';
            app.ParameterPanel.FontWeight = 'bold';
            app.ParameterPanel.Scrollable = 'on';
            app.ParameterPanel.FontSize = 14;

            % Create ParameterGrid
            app.ParameterGrid = uigridlayout(app.ParameterPanel);
            app.ParameterGrid.ColumnWidth = {122, '1x'};
            app.ParameterGrid.RowHeight = {36, 36, 36, 36, 36, 36, 36, 32, 36, 36, 42, 48};
            app.ParameterGrid.ColumnSpacing = 8;
            app.ParameterGrid.RowSpacing = 6;
            app.ParameterGrid.Padding = [14 12 14 12];
            app.ParameterGrid.Scrollable = 'on';
            app.ParameterGrid.BackgroundColor = [1 1 1];

            % Create ParameterHintLabel
            app.ParameterHintLabel = uilabel(app.ParameterGrid);
            app.ParameterHintLabel.Tag = 'ParameterHintLabel';
            app.ParameterHintLabel.WordWrap = 'on';
            app.ParameterHintLabel.FontName = 'Microsoft YaHei';
            app.ParameterHintLabel.FontColor = [0.3 0.35 0.42];
            app.ParameterHintLabel.Layout.Row = 12;
            app.ParameterHintLabel.Layout.Column = [1 2];
            app.ParameterHintLabel.Text = 'φ 从阵列轴起算；未归一化峰值为 N。';

            % Create ResetButton
            app.ResetButton = uibutton(app.ParameterGrid, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonButtonPushed, true);
            app.ResetButton.Tag = 'ResetButton';
            app.ResetButton.BackgroundColor = [0.97 0.976 0.985];
            app.ResetButton.FontName = 'Microsoft YaHei';
            app.ResetButton.FontSize = 13;
            app.ResetButton.FontColor = [0.12 0.15 0.21];
            app.ResetButton.Layout.Row = 11;
            app.ResetButton.Layout.Column = 2;
            app.ResetButton.Text = '恢复默认';

            % Create RunButton
            app.RunButton = uibutton(app.ParameterGrid, 'push');
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonButtonPushed, true);
            app.RunButton.Tag = 'RunButton';
            app.RunButton.BackgroundColor = [0.08 0.35 0.66];
            app.RunButton.FontName = 'Microsoft YaHei';
            app.RunButton.FontSize = 13;
            app.RunButton.FontWeight = 'bold';
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.Layout.Row = 11;
            app.RunButton.Layout.Column = 1;
            app.RunButton.Text = '计算方向图';

            % Create DecibelFloorField
            app.DecibelFloorField = uieditfield(app.ParameterGrid, 'numeric');
            app.DecibelFloorField.Limits = [-200 -1];
            app.DecibelFloorField.ValueChangedFcn = createCallbackFcn(app, @DecibelFloorFieldValueChanged, true);
            app.DecibelFloorField.Tag = 'DecibelFloorField';
            app.DecibelFloorField.FontName = 'Microsoft YaHei';
            app.DecibelFloorField.FontSize = 13;
            app.DecibelFloorField.BackgroundColor = [0.97 0.976 0.985];
            app.DecibelFloorField.Tooltip = '相对 dB 显示下限，可设为 -200 到 -1 dB。';
            app.DecibelFloorField.Layout.Row = 10;
            app.DecibelFloorField.Layout.Column = 2;
            app.DecibelFloorField.Value = -40;

            % Create Label_8
            app.Label_8 = uilabel(app.ParameterGrid);
            app.Label_8.FontName = 'Microsoft YaHei';
            app.Label_8.FontSize = 13;
            app.Label_8.FontColor = [0.12 0.15 0.21];
            app.Label_8.Layout.Row = 10;
            app.Label_8.Layout.Column = 1;
            app.Label_8.Text = 'dB 下限';

            % Create CartesianScaleDropDown
            app.CartesianScaleDropDown = uidropdown(app.ParameterGrid);
            app.CartesianScaleDropDown.Items = {'线性', 'dB'};
            app.CartesianScaleDropDown.ValueChangedFcn = createCallbackFcn(app, @CartesianScaleDropDownValueChanged, true);
            app.CartesianScaleDropDown.Tag = 'CartesianScaleDropDown';
            app.CartesianScaleDropDown.Tooltip = 'dB 按 N 归一化，峰值为 0 dB。';
            app.CartesianScaleDropDown.FontName = 'Microsoft YaHei';
            app.CartesianScaleDropDown.FontSize = 13;
            app.CartesianScaleDropDown.BackgroundColor = [1 1 1];
            app.CartesianScaleDropDown.Layout.Row = 9;
            app.CartesianScaleDropDown.Layout.Column = 2;
            app.CartesianScaleDropDown.Value = '线性';

            % Create Label_7
            app.Label_7 = uilabel(app.ParameterGrid);
            app.Label_7.FontName = 'Microsoft YaHei';
            app.Label_7.FontSize = 13;
            app.Label_7.FontColor = [0.12 0.15 0.21];
            app.Label_7.Layout.Row = 9;
            app.Label_7.Layout.Column = 1;
            app.Label_7.Text = '直角坐标尺度';

            % Create NormalizeCheckBox
            app.NormalizeCheckBox = uicheckbox(app.ParameterGrid);
            app.NormalizeCheckBox.ValueChangedFcn = createCallbackFcn(app, @NormalizeCheckBoxValueChanged, true);
            app.NormalizeCheckBox.Tag = 'NormalizeCheckBox';
            app.NormalizeCheckBox.Tooltip = '默认显示未归一化幅度，峰值为 N；dB 曲线始终以 N 为参考。';
            app.NormalizeCheckBox.Text = '线性归一化（幅度除以 N）';
            app.NormalizeCheckBox.FontName = 'Microsoft YaHei';
            app.NormalizeCheckBox.FontSize = 13;
            app.NormalizeCheckBox.FontColor = [0.12 0.15 0.21];
            app.NormalizeCheckBox.Layout.Row = 8;
            app.NormalizeCheckBox.Layout.Column = [1 2];

            % Create SampleCountField
            app.SampleCountField = uieditfield(app.ParameterGrid, 'numeric');
            app.SampleCountField.Limits = [2 200001];
            app.SampleCountField.ValueChangedFcn = createCallbackFcn(app, @SampleCountFieldValueChanged, true);
            app.SampleCountField.Tag = 'SampleCountField';
            app.SampleCountField.FontName = 'Microsoft YaHei';
            app.SampleCountField.FontSize = 13;
            app.SampleCountField.BackgroundColor = [0.97 0.976 0.985];
            app.SampleCountField.Tooltip = '角度采样点数，最大 200001。';
            app.SampleCountField.Layout.Row = 7;
            app.SampleCountField.Layout.Column = 2;
            app.SampleCountField.Value = 3601;

            % Create Label_6
            app.Label_6 = uilabel(app.ParameterGrid);
            app.Label_6.FontName = 'Microsoft YaHei';
            app.Label_6.FontSize = 13;
            app.Label_6.FontColor = [0.12 0.15 0.21];
            app.Label_6.Layout.Row = 7;
            app.Label_6.Layout.Column = 1;
            app.Label_6.Text = '采样点数';

            % Create AngleEndField
            app.AngleEndField = uieditfield(app.ParameterGrid, 'numeric');
            app.AngleEndField.Limits = [0 360];
            app.AngleEndField.ValueChangedFcn = createCallbackFcn(app, @AngleEndFieldValueChanged, true);
            app.AngleEndField.Tag = 'AngleEndField';
            app.AngleEndField.FontName = 'Microsoft YaHei';
            app.AngleEndField.FontSize = 13;
            app.AngleEndField.BackgroundColor = [0.97 0.976 0.985];
            app.AngleEndField.Tooltip = '绘图角度范围的终点，必须大于起点。';
            app.AngleEndField.Layout.Row = 6;
            app.AngleEndField.Layout.Column = 2;
            app.AngleEndField.Value = 360;

            % Create Label_5
            app.Label_5 = uilabel(app.ParameterGrid);
            app.Label_5.FontName = 'Microsoft YaHei';
            app.Label_5.FontSize = 13;
            app.Label_5.FontColor = [0.12 0.15 0.21];
            app.Label_5.Layout.Row = 6;
            app.Label_5.Layout.Column = 1;
            app.Label_5.Text = '角度终点 / °';

            % Create AngleStartField
            app.AngleStartField = uieditfield(app.ParameterGrid, 'numeric');
            app.AngleStartField.Limits = [0 360];
            app.AngleStartField.ValueChangedFcn = createCallbackFcn(app, @AngleStartFieldValueChanged, true);
            app.AngleStartField.Tag = 'AngleStartField';
            app.AngleStartField.FontName = 'Microsoft YaHei';
            app.AngleStartField.FontSize = 13;
            app.AngleStartField.BackgroundColor = [0.97 0.976 0.985];
            app.AngleStartField.Tooltip = '绘图角度范围的起点。';
            app.AngleStartField.Layout.Row = 5;
            app.AngleStartField.Layout.Column = 2;

            % Create Label_4
            app.Label_4 = uilabel(app.ParameterGrid);
            app.Label_4.FontName = 'Microsoft YaHei';
            app.Label_4.FontSize = 13;
            app.Label_4.FontColor = [0.12 0.15 0.21];
            app.Label_4.Layout.Row = 5;
            app.Label_4.Layout.Column = 1;
            app.Label_4.Text = '角度起点 / °';

            % Create SteeringField
            app.SteeringField = uieditfield(app.ParameterGrid, 'numeric');
            app.SteeringField.Limits = [0 360];
            app.SteeringField.ValueChangedFcn = createCallbackFcn(app, @SteeringFieldValueChanged, true);
            app.SteeringField.Tag = 'SteeringField';
            app.SteeringField.FontName = 'Microsoft YaHei';
            app.SteeringField.FontSize = 13;
            app.SteeringField.BackgroundColor = [0.97 0.976 0.985];
            app.SteeringField.Tooltip = '相位转向方向；90° 为宽侧方向。';
            app.SteeringField.Layout.Row = 4;
            app.SteeringField.Layout.Column = 2;
            app.SteeringField.Value = 90;

            % Create Label_3
            app.Label_3 = uilabel(app.ParameterGrid);
            app.Label_3.FontName = 'Microsoft YaHei';
            app.Label_3.FontSize = 13;
            app.Label_3.FontColor = [0.12 0.15 0.21];
            app.Label_3.Layout.Row = 4;
            app.Label_3.Layout.Column = 1;
            app.Label_3.Text = '指向角 φ₀ / °';

            % Create WavelengthField
            app.WavelengthField = uieditfield(app.ParameterGrid, 'numeric');
            app.WavelengthField.Limits = [0 Inf];
            app.WavelengthField.ValueChangedFcn = createCallbackFcn(app, @WavelengthFieldValueChanged, true);
            app.WavelengthField.Tag = 'WavelengthField';
            app.WavelengthField.FontName = 'Microsoft YaHei';
            app.WavelengthField.FontSize = 13;
            app.WavelengthField.BackgroundColor = [0.97 0.976 0.985];
            app.WavelengthField.Tooltip = '工作波长，必须大于 0。';
            app.WavelengthField.Layout.Row = 3;
            app.WavelengthField.Layout.Column = 2;
            app.WavelengthField.Value = 1;

            % Create Label_2
            app.Label_2 = uilabel(app.ParameterGrid);
            app.Label_2.FontName = 'Microsoft YaHei';
            app.Label_2.FontSize = 13;
            app.Label_2.FontColor = [0.12 0.15 0.21];
            app.Label_2.Layout.Row = 3;
            app.Label_2.Layout.Column = 1;
            app.Label_2.Text = '波长 λ / m';

            % Create SpacingField
            app.SpacingField = uieditfield(app.ParameterGrid, 'numeric');
            app.SpacingField.Limits = [0 Inf];
            app.SpacingField.ValueChangedFcn = createCallbackFcn(app, @SpacingFieldValueChanged, true);
            app.SpacingField.Tag = 'SpacingField';
            app.SpacingField.FontName = 'Microsoft YaHei';
            app.SpacingField.FontSize = 13;
            app.SpacingField.BackgroundColor = [0.97 0.976 0.985];
            app.SpacingField.Tooltip = '相邻阵元中心间距，必须大于 0。';
            app.SpacingField.Layout.Row = 2;
            app.SpacingField.Layout.Column = 2;
            app.SpacingField.Value = 0.5;

            % Create Label_1
            app.Label_1 = uilabel(app.ParameterGrid);
            app.Label_1.FontName = 'Microsoft YaHei';
            app.Label_1.FontSize = 13;
            app.Label_1.FontColor = [0.12 0.15 0.21];
            app.Label_1.Layout.Row = 2;
            app.Label_1.Layout.Column = 1;
            app.Label_1.Text = '间距 d / m';

            % Create ElementCountField
            app.ElementCountField = uieditfield(app.ParameterGrid, 'numeric');
            app.ElementCountField.Limits = [1 512];
            app.ElementCountField.ValueChangedFcn = createCallbackFcn(app, @ElementCountFieldValueChanged, true);
            app.ElementCountField.Tag = 'ElementCountField';
            app.ElementCountField.FontName = 'Microsoft YaHei';
            app.ElementCountField.FontSize = 13;
            app.ElementCountField.BackgroundColor = [0.97 0.976 0.985];
            app.ElementCountField.Tooltip = '正整数，最大 512。';
            app.ElementCountField.Layout.Row = 1;
            app.ElementCountField.Layout.Column = 2;
            app.ElementCountField.Value = 8;

            % Create Label
            app.Label = uilabel(app.ParameterGrid);
            app.Label.FontName = 'Microsoft YaHei';
            app.Label.FontSize = 13;
            app.Label.FontColor = [0.12 0.15 0.21];
            app.Label.Layout.Row = 1;
            app.Label.Layout.Column = 1;
            app.Label.Text = '阵元数 N';

            % Create HeaderPanel
            app.HeaderPanel = uipanel(app.ShellGrid);
            app.HeaderPanel.BorderType = 'none';
            app.HeaderPanel.BackgroundColor = [1 1 1];
            app.HeaderPanel.Layout.Row = 1;
            app.HeaderPanel.Layout.Column = 1;

            % Create HeaderGrid
            app.HeaderGrid = uigridlayout(app.HeaderPanel);
            app.HeaderGrid.ColumnWidth = {'1x', 330};
            app.HeaderGrid.RowHeight = {'1x'};
            app.HeaderGrid.ColumnSpacing = 12;
            app.HeaderGrid.Padding = [14 4 10 4];
            app.HeaderGrid.BackgroundColor = [1 1 1];

            % Create ActionGrid
            app.ActionGrid = uigridlayout(app.HeaderGrid);
            app.ActionGrid.ColumnWidth = {96, 96, 96};
            app.ActionGrid.RowHeight = {'1x'};
            app.ActionGrid.ColumnSpacing = 8;
            app.ActionGrid.Padding = [0 2 0 2];
            app.ActionGrid.Layout.Row = 1;
            app.ActionGrid.Layout.Column = 2;
            app.ActionGrid.BackgroundColor = [1 1 1];

            % Create ExportPngButton
            app.ExportPngButton = uibutton(app.ActionGrid, 'push');
            app.ExportPngButton.ButtonPushedFcn = createCallbackFcn(app, @ExportPngButtonButtonPushed, true);
            app.ExportPngButton.Tag = 'ExportPngButton';
            app.ExportPngButton.BackgroundColor = [0.97 0.976 0.985];
            app.ExportPngButton.FontName = 'Microsoft YaHei';
            app.ExportPngButton.FontSize = 13;
            app.ExportPngButton.FontColor = [0.12 0.15 0.21];
            app.ExportPngButton.Enable = 'off';
            app.ExportPngButton.Layout.Row = 1;
            app.ExportPngButton.Layout.Column = 3;
            app.ExportPngButton.Text = '导出 PNG';

            % Create ExportCsvButton
            app.ExportCsvButton = uibutton(app.ActionGrid, 'push');
            app.ExportCsvButton.ButtonPushedFcn = createCallbackFcn(app, @ExportCsvButtonButtonPushed, true);
            app.ExportCsvButton.Tag = 'ExportCsvButton';
            app.ExportCsvButton.BackgroundColor = [0.97 0.976 0.985];
            app.ExportCsvButton.FontName = 'Microsoft YaHei';
            app.ExportCsvButton.FontSize = 13;
            app.ExportCsvButton.FontColor = [0.12 0.15 0.21];
            app.ExportCsvButton.Enable = 'off';
            app.ExportCsvButton.Layout.Row = 1;
            app.ExportCsvButton.Layout.Column = 2;
            app.ExportCsvButton.Text = '导出 CSV';

            % Create ExportMatButton
            app.ExportMatButton = uibutton(app.ActionGrid, 'push');
            app.ExportMatButton.ButtonPushedFcn = createCallbackFcn(app, @ExportMatButtonButtonPushed, true);
            app.ExportMatButton.Tag = 'ExportMatButton';
            app.ExportMatButton.BackgroundColor = [0.97 0.976 0.985];
            app.ExportMatButton.FontName = 'Microsoft YaHei';
            app.ExportMatButton.FontSize = 13;
            app.ExportMatButton.FontColor = [0.12 0.15 0.21];
            app.ExportMatButton.Enable = 'off';
            app.ExportMatButton.Layout.Row = 1;
            app.ExportMatButton.Layout.Column = 1;
            app.ExportMatButton.Text = '导出 MAT';

            % Create HeaderTitle
            app.HeaderTitle = uilabel(app.HeaderGrid);
            app.HeaderTitle.FontName = 'Microsoft YaHei';
            app.HeaderTitle.FontSize = 22;
            app.HeaderTitle.FontWeight = 'bold';
            app.HeaderTitle.FontColor = [0.12 0.15 0.21];
            app.HeaderTitle.Layout.Row = 1;
            app.HeaderTitle.Layout.Column = 1;
            app.HeaderTitle.Text = '均匀线阵方向性';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ArrayPatternApp

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