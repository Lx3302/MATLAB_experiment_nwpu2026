classdef SystemStabilityApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        GridLayout            matlab.ui.container.GridLayout
        Panel                 matlab.ui.container.Panel
        GridLayout_1          matlab.ui.container.GridLayout
        AppTitle              matlab.ui.control.Label
        StatusLabel           matlab.ui.control.Label
        GridLayout_2          matlab.ui.container.GridLayout
        ParameterPanel        matlab.ui.container.Panel
        GridLayout_3          matlab.ui.container.GridLayout
        ModelSectionLabel     matlab.ui.control.Label
        DomainLabel           matlab.ui.control.Label
        DomainDropDown        matlab.ui.control.DropDown
        NumeratorLabel        matlab.ui.control.Label
        NumeratorField        matlab.ui.control.EditField
        DenominatorLabel      matlab.ui.control.Label
        DenominatorField      matlab.ui.control.EditField
        AnalysisSectionLabel  matlab.ui.control.Label
        ToleranceLabel        matlab.ui.control.Label
        ToleranceField        matlab.ui.control.NumericEditField
        FrequencyMinLabel     matlab.ui.control.Label
        FrequencyMinField     matlab.ui.control.NumericEditField
        FrequencyMaxLabel     matlab.ui.control.Label
        FrequencyMaxField     matlab.ui.control.NumericEditField
        FrequencyPointsLabel  matlab.ui.control.Label
        FrequencyPointsField  matlab.ui.control.NumericEditField
        ImpulseSectionLabel   matlab.ui.control.Label
        SampleCountLabel      matlab.ui.control.Label
        SampleCountField      matlab.ui.control.NumericEditField
        MaxTimeLabel          matlab.ui.control.Label
        MaxTimeField          matlab.ui.control.NumericEditField
        SymbolicCheckBox      matlab.ui.control.CheckBox
        ActionsSectionLabel   matlab.ui.control.Label
        RunButton             matlab.ui.control.Button
        ResetPresetButton     matlab.ui.control.Button
        ExportMatButton       matlab.ui.control.Button
        ExportCsvButton       matlab.ui.control.Button
        ExportPngButton       matlab.ui.control.Button
        ParameterHint         matlab.ui.control.Label
        ResultPanel           matlab.ui.container.Panel
        GridLayout_4          matlab.ui.container.GridLayout
        Tabs                  matlab.ui.container.TabGroup
        ZeroPoleTab           matlab.ui.container.Tab
        GridLayout_5          matlab.ui.container.GridLayout
        ZeroPoleTable         matlab.ui.control.Table
        ZeroAxes              matlab.ui.control.UIAxes
        FrequencyTab          matlab.ui.container.Tab
        GridLayout_6          matlab.ui.container.GridLayout
        FrequencyNote         matlab.ui.control.Label
        FrequencyAxes         matlab.ui.control.UIAxes
        ImpulseTab            matlab.ui.container.Tab
        GridLayout_7          matlab.ui.container.GridLayout
        SymbolicDetails       matlab.ui.control.TextArea
        ImpulseAxes           matlab.ui.control.UIAxes
    end

    properties (SetAccess = public)
        Result
    end

    properties (Access = private)
        Config
        ResultIsCurrent = false
        IsBusy = false
    end

    methods (Access = private)
        function config = completeConfig(~, config)
            if ~isstruct(config)
                error('exp4:InvalidConfig', 'GUI configuration must be a structure.');
            end
            if ~isfield(config, 'domain')
                config.domain = 'continuous';
            end
            domain = lower(char(string(config.domain)));
            if strcmp(domain, 'z')
                domain = 'discrete';
            elseif strcmp(domain, 's')
                domain = 'continuous';
            end
            defaults = exp4_defaults(domain);
            fields = fieldnames(defaults);
            for k = 1:numel(fields)
                name = fields{k};
                if ~isfield(config, name)
                    config.(name) = defaults.(name);
                end
            end
            config.domain = domain;
        end











        function applyConfigToControls(app, config)
            domain = lower(char(string(config.domain)));
            app.DomainDropDown.Value = domain;
            app.NumeratorField.Value = app.formatVector(config.numerator);
            app.DenominatorField.Value = app.formatVector(config.denominator);
            app.ToleranceField.Value = config.stabilityTolerance;
            app.FrequencyMinField.Value = config.frequencyMin;
            app.FrequencyMaxField.Value = config.frequencyMax;
            app.FrequencyPointsField.Value = config.frequencyPoints;
            app.SampleCountField.Value = config.sampleCount;
            app.MaxTimeField.Value = config.maxTime;
            app.SymbolicCheckBox.Value = config.symbolic;
            if strcmp(domain, 'discrete')
                app.FrequencyMaxField.Value = min(config.frequencyMax, pi);
            end
            app.updateDomainLabels();
            app.setExportState(false);
        end

        function onDomainChanged(app)
            domain = app.DomainDropDown.Value;
            config = exp4_defaults(domain);
            app.Config = config;
            app.applyConfigToControls(config);
            app.markDirty();
        end

        function resetPreset(app)
            config = exp4_defaults(app.DomainDropDown.Value);
            app.Config = config;
            app.applyConfigToControls(config);
            app.runAnalysis();
        end

        function runAnalysis(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            app.ResultIsCurrent = false;
            app.setExportState(false);
            if ~app.beginBusy('正在计算…')
                return;
            end
            busyCleanup = onCleanup(@() app.endBusy()); %#ok<NASGU>
            try
                config = struct();
                config.domain = app.DomainDropDown.Value;
                config.numerator = app.parseCoefficientVector(app.NumeratorField.Value);
                config.denominator = app.parseCoefficientVector(app.DenominatorField.Value);
                config.stabilityTolerance = app.ToleranceField.Value;
                config.frequencyMin = app.FrequencyMinField.Value;
                config.frequencyMax = app.FrequencyMaxField.Value;
                config.frequencyPoints = app.FrequencyPointsField.Value;
                config.sampleCount = app.SampleCountField.Value;
                config.maxTime = app.MaxTimeField.Value;
                config.symbolic = app.SymbolicCheckBox.Value;
                app.Result = exp4_analyze(config);
                app.Config = app.Result.config;
                app.renderResult();
                app.updateStatus();
                app.ResultIsCurrent = true;
                app.setExportState(true);
            catch exception
                app.StatusLabel.Text = '分析失败；请查看详情后重试';
                app.StatusLabel.FontColor = [0.66, 0.39, 0.05];
                app.setDetails({exception.message});
            end
        end

        function started = beginBusy(app, statusText)
            started = false;
            if app.IsBusy || isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            app.IsBusy = true;
            app.ParameterPanel.Enable = 'off';
            app.RunButton.Enable = 'off';
            app.UIFigure.Pointer = 'watch';
            app.StatusLabel.Text = statusText;
            app.StatusLabel.FontColor = [0.12, 0.39, 0.76];
            drawnow;
            started = true;
        end

        function endBusy(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                app.IsBusy = false;
                return;
            end
            app.IsBusy = false;
            app.UIFigure.Pointer = 'arrow';
            app.ParameterPanel.Enable = 'on';
            app.updateDomainLabels();
            app.RunButton.Enable = 'on';
            app.setExportState(app.ResultIsCurrent);
        end

        function requestClose(app)
            if app.IsBusy
                app.StatusLabel.Text = '分析完成前无法关闭';
                app.StatusLabel.FontColor = [0.66, 0.39, 0.05];
                return;
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                app.UIFigure.CloseRequestFcn = '';
                delete(app.UIFigure);
            end
        end

        function markDirty(app)
            if app.IsBusy
                return;
            end
            app.ResultIsCurrent = false;
            app.setExportState(false);
            app.StatusLabel.Text = '参数已修改；运行分析以更新结果';
            app.StatusLabel.FontColor = [0.34, 0.40, 0.48];
        end

        function setExportState(app, enabled)
            if ~enabled
                state = 'off';
            else
                state = 'on';
            end
            handles = {app.ExportMatButton, app.ExportCsvButton, app.ExportPngButton};
            for k = 1:numel(handles)
                if ~isempty(handles{k}) && isvalid(handles{k})
                    handles{k}.Enable = state;
                end
            end
        end

        function updateDomainLabels(app)
            isDiscrete = strcmp(app.DomainDropDown.Value, 'discrete');
            app.FrequencyMinLabel.Text = 'ω 下限';
            app.FrequencyMaxLabel.Text = 'ω 上限';
            if isDiscrete
                app.SampleCountLabel.Text = '样本数 N';
                app.MaxTimeLabel.Text = '终止时间';
                app.MaxTimeLabel.Enable = 'off';
                app.MaxTimeField.Enable = 'off';
            else
                app.SampleCountLabel.Text = '采样点数';
                app.MaxTimeLabel.Text = '终止时间 (s)';
                app.MaxTimeLabel.Enable = 'on';
                app.MaxTimeField.Enable = 'on';
            end
        end

        function renderResult(app)
            app.renderZeroPolePlot();
            app.renderFrequencyPlot();
            app.renderImpulsePlot();
            app.renderPoleTable();
        end

        function renderZeroPolePlot(app)
            ax = app.ZeroAxes;
            cla(ax);
            hold(ax, 'on');
            grid(ax, 'on');
            if strcmp(app.Result.domain, 'discrete')
                angle = linspace(0, 2*pi, 361);
                plot(ax, cos(angle), sin(angle), '--', 'Color', [0.45, 0.55, 0.68], ...
                    'LineWidth', 1.2, 'DisplayName', '单位圆');
                xlabel(ax, '实部');
                ylabel(ax, '虚部');
            else
                xline(ax, 0, '--', 'Color', [0.45, 0.55, 0.68], ...
                    'LineWidth', 1.2, 'DisplayName', '虚轴');
                xlabel(ax, '实部（s^{-1}）');
                ylabel(ax, '虚部（s^{-1}）');
            end
            if ~isempty(app.Result.zeros)
                plot(ax, real(app.Result.zeros), imag(app.Result.zeros), 'o', ...
                    'Color', [0.12, 0.39, 0.76], 'MarkerSize', 9, ...
                    'LineWidth', 1.7, 'LineStyle', 'none', 'DisplayName', '零点');
            end
            if ~isempty(app.Result.poles)
                plot(ax, real(app.Result.poles), imag(app.Result.poles), 'x', ...
                    'Color', [0.76, 0.24, 0.22], 'MarkerSize', 10, ...
                    'LineWidth', 1.8, 'LineStyle', 'none', 'DisplayName', '极点');
            end
            title(ax, '零点与极点', 'FontWeight', 'bold');
            legend(ax, 'Location', 'best');
            axis(ax, 'equal');
            hold(ax, 'off');
        end

        function renderFrequencyPlot(app)
            ax = app.FrequencyAxes;
            cla(ax);
            plot(ax, app.Result.frequency.axis, app.Result.frequency.magnitudeDb, ...
                'Color', [0.12, 0.39, 0.76], 'LineWidth', 1.7);
            grid(ax, 'on');
            title(ax, app.Result.frequency.title, 'FontWeight', 'bold');
            xlabel(ax, app.Result.frequency.axisLabel);
            ylabel(ax, '幅度 (dB)');
            app.FrequencyNote.Text = app.Result.frequency.note;
        end

        function renderImpulsePlot(app)
            ax = app.ImpulseAxes;
            cla(ax);
            hold(ax, 'on');
            plot(ax, app.Result.impulse.axis, app.Result.impulse.numerical, ...
                'Color', [0.12, 0.39, 0.76], 'LineWidth', 1.7, ...
                'DisplayName', '数值响应');
            if isfield(app.Result.symbolic, 'success') && app.Result.symbolic.success
                plot(ax, app.Result.impulse.axis, app.Result.symbolic.samples, '--', ...
                    'Color', [0.83, 0.42, 0.12], 'LineWidth', 1.4, ...
                    'DisplayName', '符号逆变换');
            end
            hold(ax, 'off');
            grid(ax, 'on');
            xlabel(ax, app.Result.impulse.axisLabel);
            ylabel(ax, '幅度');
            title(ax, app.Result.impulse.title, 'FontWeight', 'bold');
            if app.Result.impulse.deltaWeight ~= 0
                title(ax, sprintf('%s；δ(t) 权重 = %.6g', ...
                    app.Result.impulse.title, app.Result.impulse.deltaWeight), 'FontWeight', 'bold');
            end
            legend(ax, 'Location', 'best');
            detailLines = {app.Result.symbolic.message};
            if ~isempty(app.Result.symbolic.expression)
                detailLines{end+1} = ['符号表达式：', app.Result.symbolic.expression]; %#ok<AGROW>
            end
            app.setDetails(detailLines);
        end

        function renderPoleTable(app)
            rows = cell(0, 4);
            for k = 1:numel(app.Result.zeros)
                value = app.Result.zeros(k);
                rows(end+1, :) = {'零点', sprintf('%.7g', real(value)), ...
                    sprintf('%.7g', imag(value)), sprintf('%.7g', abs(value))}; %#ok<AGROW>
            end
            for k = 1:numel(app.Result.poles)
                value = app.Result.poles(k);
                rows(end+1, :) = {'极点', sprintf('%.7g', real(value)), ...
                    sprintf('%.7g', imag(value)), sprintf('%.7g', abs(value))}; %#ok<AGROW>
            end
            app.ZeroPoleTable.Data = rows;
        end

        function updateStatus(app)
            stability = app.Result.stability;
            switch stability.classification
                case 'stable'
                    text = '稳定';
                    color = [0.10, 0.48, 0.30];
                case 'boundary'
                    text = '边界极点：不稳定';
                    color = [0.66, 0.39, 0.05];
                otherwise
                    text = '不稳定';
                    color = [0.72, 0.20, 0.20];
            end
            if strcmp(app.Result.domain, 'discrete')
                metric = stability.maximumPoleRadius;
                app.StatusLabel.Text = sprintf('分母判稳 %s  ·  最大极点模 %.6g', text, metric);
            else
                metric = stability.rightmostPoleRealPart;
                app.StatusLabel.Text = sprintf('分母判稳 %s  ·  最右极点实部 %.6g', text, metric);
            end
            app.StatusLabel.FontColor = color;
        end

        function exportMat(app)
            if isempty(app.Result) || ~app.ResultIsCurrent
                app.StatusLabel.Text = '参数已修改；请先运行分析';
                return;
            end
            if ~app.beginBusy('正在选择 MAT 保存位置…')
                return;
            end
            busyCleanup = onCleanup(@() app.endBusy()); %#ok<NASGU>
            [file, folder] = uiputfile('*.mat', '导出分析结果', 'exp4_result.mat');
            if isequal(file, 0)
                return;
            end
            result = app.Result; %#ok<NASGU>
            try
                save(fullfile(folder, file), 'result');
                app.StatusLabel.Text = ['已导出 ', file];
            catch exception
                app.StatusLabel.Text = ['导出失败：', exception.message];
            end
        end

        function exportCsv(app)
            if isempty(app.Result) || ~app.ResultIsCurrent
                app.StatusLabel.Text = '参数已修改；请先运行分析';
                return;
            end
            if ~app.beginBusy('正在选择 CSV 保存位置…')
                return;
            end
            busyCleanup = onCleanup(@() app.endBusy()); %#ok<NASGU>
            [file, folder] = uiputfile('*.csv', '导出冲激响应', 'exp4_impulse.csv');
            if isequal(file, 0)
                return;
            end
            try
                axisValues = app.Result.impulse.axis(:);
                numericalResponse = app.Result.impulse.numerical(:);
                symbolicResponse = NaN(size(numericalResponse));
                deltaWeight = repmat(app.Result.impulse.deltaWeight, size(numericalResponse));
                if app.Result.symbolic.success
                    symbolicResponse = app.Result.symbolic.samples(:);
                end
                if strcmp(app.Result.domain, 'discrete')
                    coordinateName = 'sample_n';
                else
                    coordinateName = 'time_s';
                end
                tableData = table(axisValues, numericalResponse, symbolicResponse, deltaWeight, ...
                    'VariableNames', {coordinateName, 'numeric_response', ...
                    'symbolic_response', 'delta_weight'});
                writetable(tableData, fullfile(folder, file));
                app.StatusLabel.Text = ['已导出 ', file];
            catch exception
                app.StatusLabel.Text = ['导出失败：', exception.message];
            end
        end

        function exportCurrentPlot(app)
            if isempty(app.Result) || ~app.ResultIsCurrent
                app.StatusLabel.Text = '参数已修改；请先运行分析';
                return;
            end
            if ~app.beginBusy('正在选择 PNG 保存位置…')
                return;
            end
            busyCleanup = onCleanup(@() app.endBusy()); %#ok<NASGU>
            [file, folder] = uiputfile('*.png', '导出当前图', 'exp4_plot.png');
            if isequal(file, 0)
                return;
            end
            selected = app.Tabs.SelectedTab;
            if strcmp(selected.Tag, 'FrequencyTab')
                axesHandle = app.FrequencyAxes;
            elseif strcmp(selected.Tag, 'ImpulseTab')
                axesHandle = app.ImpulseAxes;
            else
                axesHandle = app.ZeroAxes;
            end
            try
                exportgraphics(axesHandle, fullfile(folder, file), 'Resolution', 180);
                app.StatusLabel.Text = ['已导出 ', file];
            catch exception
                app.StatusLabel.Text = ['图片导出失败：', exception.message];
            end
        end

        function vector = parseCoefficientVector(~, rawText)
            text = strtrim(char(string(rawText)));
            if isempty(text)
                error('exp4:EmptyCoefficientField', '分子和分母系数不能为空。');
            end
            startsBracket = text(1) == '[';
            endsBracket = text(end) == ']';
            if startsBracket ~= endsBracket
                error('exp4:InvalidCoefficientSyntax', '系数方括号必须成对出现。');
            end
            if startsBracket
                text = strtrim(text(2:end-1));
            end
            tokens = regexp(text, '[,;\s]+', 'split');
            if isempty(tokens) || any(cellfun(@isempty, tokens))
                error('exp4:InvalidCoefficientSyntax', '请用逗号、空格或分号分隔系数。');
            end
            pattern = '^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$';
            vector = zeros(1, numel(tokens));
            for k = 1:numel(tokens)
                if isempty(regexp(tokens{k}, pattern, 'once'))
                    error('exp4:InvalidCoefficientSyntax', ...
                        '系数格式无效：%s。只接受有限十进制数，不执行表达式。', tokens{k});
                end
                vector(k) = str2double(tokens{k});
                if isnan(vector(k)) || isinf(vector(k))
                    error('exp4:InvalidCoefficientSyntax', '系数必须是有限数值。');
                end
            end
        end

        function text = formatVector(~, vector)
            parts = arrayfun(@(value) sprintf('%.15g', value), vector, 'UniformOutput', false);
            text = ['[', strjoin(parts, ', '), ']'];
        end

        function setDetails(app, lines)
            if isempty(lines)
                lines = {''};
            end
            app.SymbolicDetails.Value = lines;
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, varargin)
            if isempty(varargin) || isempty(varargin{1})
                config = exp4_defaults('continuous');
            else
                config = varargin{1};
            end
            app.Config = app.completeConfig(config);
            app.applyConfigToControls(app.Config);
            app.runAnalysis();
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            app.requestClose();
        end

        % Value changed function: DomainDropDown
        function DomainDropDownValueChanged(app, event)
            app.onDomainChanged();
        end

        % Value changed function: NumeratorField
        function NumeratorFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: DenominatorField
        function DenominatorFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: ToleranceField
        function ToleranceFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: FrequencyMinField
        function FrequencyMinFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: FrequencyMaxField
        function FrequencyMaxFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: FrequencyPointsField
        function FrequencyPointsFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: SampleCountField
        function SampleCountFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: MaxTimeField
        function MaxTimeFieldValueChanged(app, event)
            app.markDirty();
        end

        % Value changed function: SymbolicCheckBox
        function SymbolicCheckBoxValueChanged(app, event)
            app.markDirty();
        end

        % Button pushed function: RunButton
        function RunButtonButtonPushed(app, event)
            app.runAnalysis();
        end

        % Button pushed function: ResetPresetButton
        function ResetPresetButtonButtonPushed(app, event)
            app.resetPreset();
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
            app.exportCurrentPlot();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Color = [0.95 0.965 0.98];
            app.UIFigure.Position = [80 60 1300 850];
            app.UIFigure.Name = '实验四 · 系统稳定性分析';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.Tag = 'SystemStabilityAppFigure';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {58, '1x'};
            app.GridLayout.RowSpacing = 12;
            app.GridLayout.Padding = [16 14 16 14];

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.GridLayout);
            app.GridLayout_2.ColumnWidth = {350, '1x'};
            app.GridLayout_2.RowHeight = {'1x'};
            app.GridLayout_2.ColumnSpacing = 14;
            app.GridLayout_2.Padding = [0 0 0 0];
            app.GridLayout_2.Layout.Row = 2;
            app.GridLayout_2.Layout.Column = 1;

            % Create ResultPanel
            app.ResultPanel = uipanel(app.GridLayout_2);
            app.ResultPanel.BorderType = 'none';
            app.ResultPanel.BackgroundColor = [0.95 0.965 0.98];
            app.ResultPanel.Tag = 'ResultPanel';
            app.ResultPanel.Layout.Row = 1;
            app.ResultPanel.Layout.Column = 2;

            % Create GridLayout_4
            app.GridLayout_4 = uigridlayout(app.ResultPanel);
            app.GridLayout_4.ColumnWidth = {'1x'};
            app.GridLayout_4.RowHeight = {'1x'};
            app.GridLayout_4.Padding = [0 0 0 0];

            % Create Tabs
            app.Tabs = uitabgroup(app.GridLayout_4);
            app.Tabs.Tag = 'ResultTabs';
            app.Tabs.Layout.Row = 1;
            app.Tabs.Layout.Column = 1;

            % Create ZeroPoleTab
            app.ZeroPoleTab = uitab(app.Tabs);
            app.ZeroPoleTab.Title = '零极点';
            app.ZeroPoleTab.Tag = 'ZeroPoleTab';

            % Create GridLayout_5
            app.GridLayout_5 = uigridlayout(app.ZeroPoleTab);
            app.GridLayout_5.ColumnWidth = {'1x'};
            app.GridLayout_5.RowHeight = {'1x', 168};
            app.GridLayout_5.Padding = [12 12 12 12];

            % Create ZeroAxes
            app.ZeroAxes = uiaxes(app.GridLayout_5);
            title(app.ZeroAxes, '零点与极点')
            xlabel(app.ZeroAxes, '实部（s^{-1}）')
            ylabel(app.ZeroAxes, '虚部（s^{-1}）')
            app.ZeroAxes.PlotBoxAspectRatio = [3.34220532319392 2 1];
            app.ZeroAxes.FontName = 'Microsoft YaHei UI';
            app.ZeroAxes.XColor = [0.34 0.4 0.48];
            app.ZeroAxes.YColor = [0.34 0.4 0.48];
            app.ZeroAxes.GridColor = [0.82 0.86 0.91];
            app.ZeroAxes.Box = 'on';
            app.ZeroAxes.XGrid = 'on';
            app.ZeroAxes.YGrid = 'on';
            app.ZeroAxes.ZGrid = 'on';
            app.ZeroAxes.FontSize = 13;
            app.ZeroAxes.Layout.Row = 1;
            app.ZeroAxes.Layout.Column = 1;
            app.ZeroAxes.Tag = 'ZeroPoleAxes';

            % Create ZeroPoleTable
            app.ZeroPoleTable = uitable(app.GridLayout_5);
            app.ZeroPoleTable.ColumnName = {'类型'; '实部'; '虚部'; '模值'};
            app.ZeroPoleTable.ColumnWidth = {70, 140, 140, 120};
            app.ZeroPoleTable.Tag = 'PoleZeroTable';
            app.ZeroPoleTable.FontName = 'Microsoft YaHei UI';
            app.ZeroPoleTable.Layout.Row = 2;
            app.ZeroPoleTable.Layout.Column = 1;
            app.ZeroPoleTable.FontSize = 13;

            % Create FrequencyTab
            app.FrequencyTab = uitab(app.Tabs);
            app.FrequencyTab.Title = '频率响应';
            app.FrequencyTab.Tag = 'FrequencyTab';

            % Create GridLayout_6
            app.GridLayout_6 = uigridlayout(app.FrequencyTab);
            app.GridLayout_6.ColumnWidth = {'1x'};
            app.GridLayout_6.RowHeight = {'1x', 46};
            app.GridLayout_6.Padding = [14 12 14 10];

            % Create FrequencyAxes
            app.FrequencyAxes = uiaxes(app.GridLayout_6);
            title(app.FrequencyAxes, '代数频率响应 |H(jω)|')
            xlabel(app.FrequencyAxes, 'ω (rad/s)')
            ylabel(app.FrequencyAxes, '幅度 (dB)')
            app.FrequencyAxes.FontName = 'Microsoft YaHei UI';
            app.FrequencyAxes.XColor = [0.34 0.4 0.48];
            app.FrequencyAxes.YColor = [0.34 0.4 0.48];
            app.FrequencyAxes.GridColor = [0.82 0.86 0.91];
            app.FrequencyAxes.Box = 'on';
            app.FrequencyAxes.XGrid = 'on';
            app.FrequencyAxes.YGrid = 'on';
            app.FrequencyAxes.ZGrid = 'on';
            app.FrequencyAxes.FontSize = 13;
            app.FrequencyAxes.Layout.Row = 1;
            app.FrequencyAxes.Layout.Column = 1;
            app.FrequencyAxes.Tag = 'FrequencyAxes';

            % Create FrequencyNote
            app.FrequencyNote = uilabel(app.GridLayout_6);
            app.FrequencyNote.Tag = 'FrequencyNote';
            app.FrequencyNote.WordWrap = 'on';
            app.FrequencyNote.FontName = 'Microsoft YaHei UI';
            app.FrequencyNote.FontSize = 13;
            app.FrequencyNote.FontColor = [0.34 0.4 0.48];
            app.FrequencyNote.Layout.Row = 2;
            app.FrequencyNote.Layout.Column = 1;
            app.FrequencyNote.Text = '未约分分母极点均在左半平面；频响按输入系数直接计算。';

            % Create ImpulseTab
            app.ImpulseTab = uitab(app.Tabs);
            app.ImpulseTab.Title = '冲激响应';
            app.ImpulseTab.Tag = 'ImpulseTab';

            % Create GridLayout_7
            app.GridLayout_7 = uigridlayout(app.ImpulseTab);
            app.GridLayout_7.ColumnWidth = {'1x'};
            app.GridLayout_7.RowHeight = {'1x', 125};
            app.GridLayout_7.RowSpacing = 8;
            app.GridLayout_7.Padding = [14 12 14 12];

            % Create ImpulseAxes
            app.ImpulseAxes = uiaxes(app.GridLayout_7);
            title(app.ImpulseAxes, '因果连续冲激响应（不含 δ(t) 图形）')
            xlabel(app.ImpulseAxes, 't (s)')
            ylabel(app.ImpulseAxes, '幅度')
            app.ImpulseAxes.FontName = 'Microsoft YaHei UI';
            app.ImpulseAxes.XColor = [0.34 0.4 0.48];
            app.ImpulseAxes.YColor = [0.34 0.4 0.48];
            app.ImpulseAxes.GridColor = [0.82 0.86 0.91];
            app.ImpulseAxes.Box = 'on';
            app.ImpulseAxes.XGrid = 'on';
            app.ImpulseAxes.YGrid = 'on';
            app.ImpulseAxes.ZGrid = 'on';
            app.ImpulseAxes.FontSize = 13;
            app.ImpulseAxes.Layout.Row = 1;
            app.ImpulseAxes.Layout.Column = 1;
            app.ImpulseAxes.Tag = 'ImpulseAxes';

            % Create SymbolicDetails
            app.SymbolicDetails = uitextarea(app.GridLayout_7);
            app.SymbolicDetails.Tag = 'SymbolicDetails';
            app.SymbolicDetails.Editable = 'off';
            app.SymbolicDetails.FontName = 'Microsoft YaHei UI';
            app.SymbolicDetails.FontSize = 13;
            app.SymbolicDetails.Layout.Row = 2;
            app.SymbolicDetails.Layout.Column = 1;
            app.SymbolicDetails.Value = {'符号响应已关闭。'};

            % Create ParameterPanel
            app.ParameterPanel = uipanel(app.GridLayout_2);
            app.ParameterPanel.Title = '参数';
            app.ParameterPanel.BackgroundColor = [1 1 1];
            app.ParameterPanel.Tag = 'ParameterPanel';
            app.ParameterPanel.Layout.Row = 1;
            app.ParameterPanel.Layout.Column = 1;
            app.ParameterPanel.FontName = 'Microsoft YaHei UI';
            app.ParameterPanel.Scrollable = 'on';
            app.ParameterPanel.FontSize = 15;

            % Create GridLayout_3
            app.GridLayout_3 = uigridlayout(app.ParameterPanel);
            app.GridLayout_3.ColumnWidth = {118, '1x'};
            app.GridLayout_3.RowHeight = {28, 34, 24, 50, 24, 50, 25, 34, 34, 34, 34, 25, 34, 34, 34, 25, 38, 38, 38, 42};
            app.GridLayout_3.ColumnSpacing = 8;
            app.GridLayout_3.RowSpacing = 4;
            app.GridLayout_3.Padding = [12 10 12 12];
            app.GridLayout_3.Scrollable = 'on';

            % Create ParameterHint
            app.ParameterHint = uilabel(app.GridLayout_3);
            app.ParameterHint.Tag = 'ParameterHint';
            app.ParameterHint.FontName = 'Microsoft YaHei UI';
            app.ParameterHint.FontColor = [0.34 0.4 0.48];
            app.ParameterHint.Layout.Row = 20;
            app.ParameterHint.Layout.Column = [1 2];
            app.ParameterHint.Text = '输入系数后运行；边界极点按不稳定处理。';

            % Create ExportPngButton
            app.ExportPngButton = uibutton(app.GridLayout_3, 'push');
            app.ExportPngButton.ButtonPushedFcn = createCallbackFcn(app, @ExportPngButtonButtonPushed, true);
            app.ExportPngButton.Tag = 'ExportPngButton';
            app.ExportPngButton.FontName = 'Microsoft YaHei UI';
            app.ExportPngButton.FontSize = 13;
            app.ExportPngButton.Layout.Row = 19;
            app.ExportPngButton.Layout.Column = [1 2];
            app.ExportPngButton.Text = '导出当前图 PNG';

            % Create ExportCsvButton
            app.ExportCsvButton = uibutton(app.GridLayout_3, 'push');
            app.ExportCsvButton.ButtonPushedFcn = createCallbackFcn(app, @ExportCsvButtonButtonPushed, true);
            app.ExportCsvButton.Tag = 'ExportCsvButton';
            app.ExportCsvButton.FontName = 'Microsoft YaHei UI';
            app.ExportCsvButton.FontSize = 13;
            app.ExportCsvButton.Layout.Row = 18;
            app.ExportCsvButton.Layout.Column = 2;
            app.ExportCsvButton.Text = '导出 CSV';

            % Create ExportMatButton
            app.ExportMatButton = uibutton(app.GridLayout_3, 'push');
            app.ExportMatButton.ButtonPushedFcn = createCallbackFcn(app, @ExportMatButtonButtonPushed, true);
            app.ExportMatButton.Tag = 'ExportMatButton';
            app.ExportMatButton.FontName = 'Microsoft YaHei UI';
            app.ExportMatButton.FontSize = 13;
            app.ExportMatButton.Layout.Row = 18;
            app.ExportMatButton.Layout.Column = 1;
            app.ExportMatButton.Text = '导出 MAT';

            % Create ResetPresetButton
            app.ResetPresetButton = uibutton(app.GridLayout_3, 'push');
            app.ResetPresetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetPresetButtonButtonPushed, true);
            app.ResetPresetButton.Tag = 'ResetPresetButton';
            app.ResetPresetButton.FontName = 'Microsoft YaHei UI';
            app.ResetPresetButton.FontSize = 14;
            app.ResetPresetButton.Layout.Row = 17;
            app.ResetPresetButton.Layout.Column = 2;
            app.ResetPresetButton.Text = '恢复预设';

            % Create RunButton
            app.RunButton = uibutton(app.GridLayout_3, 'push');
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonButtonPushed, true);
            app.RunButton.Tag = 'RunAnalysisButton';
            app.RunButton.BackgroundColor = [0.12 0.39 0.76];
            app.RunButton.FontName = 'Microsoft YaHei UI';
            app.RunButton.FontSize = 14;
            app.RunButton.FontWeight = 'bold';
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.Layout.Row = 17;
            app.RunButton.Layout.Column = 1;
            app.RunButton.Text = '运行分析';

            % Create ActionsSectionLabel
            app.ActionsSectionLabel = uilabel(app.GridLayout_3);
            app.ActionsSectionLabel.Tag = 'ActionsSectionLabel';
            app.ActionsSectionLabel.FontName = 'Microsoft YaHei UI';
            app.ActionsSectionLabel.FontSize = 15;
            app.ActionsSectionLabel.FontWeight = 'bold';
            app.ActionsSectionLabel.FontColor = [0.11 0.16 0.23];
            app.ActionsSectionLabel.Layout.Row = 16;
            app.ActionsSectionLabel.Layout.Column = [1 2];
            app.ActionsSectionLabel.Text = '运行与导出';

            % Create SymbolicCheckBox
            app.SymbolicCheckBox = uicheckbox(app.GridLayout_3);
            app.SymbolicCheckBox.ValueChangedFcn = createCallbackFcn(app, @SymbolicCheckBoxValueChanged, true);
            app.SymbolicCheckBox.Tag = 'SymbolicCheckBox';
            app.SymbolicCheckBox.Text = '计算符号逆变换';
            app.SymbolicCheckBox.FontName = 'Microsoft YaHei UI';
            app.SymbolicCheckBox.FontSize = 14;
            app.SymbolicCheckBox.FontColor = [0.11 0.16 0.23];
            app.SymbolicCheckBox.Layout.Row = 15;
            app.SymbolicCheckBox.Layout.Column = [1 2];

            % Create MaxTimeField
            app.MaxTimeField = uieditfield(app.GridLayout_3, 'numeric');
            app.MaxTimeField.ValueChangedFcn = createCallbackFcn(app, @MaxTimeFieldValueChanged, true);
            app.MaxTimeField.Tag = 'MaxTimeField';
            app.MaxTimeField.FontName = 'Microsoft YaHei UI';
            app.MaxTimeField.FontSize = 14;
            app.MaxTimeField.FontColor = [0.11 0.16 0.23];
            app.MaxTimeField.Layout.Row = 14;
            app.MaxTimeField.Layout.Column = 2;
            app.MaxTimeField.Value = 10;

            % Create MaxTimeLabel
            app.MaxTimeLabel = uilabel(app.GridLayout_3);
            app.MaxTimeLabel.Tag = 'MaxTimeLabel';
            app.MaxTimeLabel.FontName = 'Microsoft YaHei UI';
            app.MaxTimeLabel.FontSize = 14;
            app.MaxTimeLabel.FontColor = [0.11 0.16 0.23];
            app.MaxTimeLabel.Layout.Row = 14;
            app.MaxTimeLabel.Layout.Column = 1;
            app.MaxTimeLabel.Text = '终止时间 (s)';

            % Create SampleCountField
            app.SampleCountField = uieditfield(app.GridLayout_3, 'numeric');
            app.SampleCountField.ValueChangedFcn = createCallbackFcn(app, @SampleCountFieldValueChanged, true);
            app.SampleCountField.Tag = 'SampleCountField';
            app.SampleCountField.FontName = 'Microsoft YaHei UI';
            app.SampleCountField.FontSize = 14;
            app.SampleCountField.FontColor = [0.11 0.16 0.23];
            app.SampleCountField.Layout.Row = 13;
            app.SampleCountField.Layout.Column = 2;
            app.SampleCountField.Value = 1001;

            % Create SampleCountLabel
            app.SampleCountLabel = uilabel(app.GridLayout_3);
            app.SampleCountLabel.Tag = 'SampleCountLabel';
            app.SampleCountLabel.FontName = 'Microsoft YaHei UI';
            app.SampleCountLabel.FontSize = 14;
            app.SampleCountLabel.FontColor = [0.11 0.16 0.23];
            app.SampleCountLabel.Layout.Row = 13;
            app.SampleCountLabel.Layout.Column = 1;
            app.SampleCountLabel.Text = '采样点数';

            % Create ImpulseSectionLabel
            app.ImpulseSectionLabel = uilabel(app.GridLayout_3);
            app.ImpulseSectionLabel.Tag = 'ImpulseSectionLabel';
            app.ImpulseSectionLabel.FontName = 'Microsoft YaHei UI';
            app.ImpulseSectionLabel.FontSize = 15;
            app.ImpulseSectionLabel.FontWeight = 'bold';
            app.ImpulseSectionLabel.FontColor = [0.11 0.16 0.23];
            app.ImpulseSectionLabel.Layout.Row = 12;
            app.ImpulseSectionLabel.Layout.Column = [1 2];
            app.ImpulseSectionLabel.Text = '冲激响应';

            % Create FrequencyPointsField
            app.FrequencyPointsField = uieditfield(app.GridLayout_3, 'numeric');
            app.FrequencyPointsField.ValueChangedFcn = createCallbackFcn(app, @FrequencyPointsFieldValueChanged, true);
            app.FrequencyPointsField.Tag = 'FrequencyPointsField';
            app.FrequencyPointsField.FontName = 'Microsoft YaHei UI';
            app.FrequencyPointsField.FontSize = 14;
            app.FrequencyPointsField.FontColor = [0.11 0.16 0.23];
            app.FrequencyPointsField.Layout.Row = 11;
            app.FrequencyPointsField.Layout.Column = 2;
            app.FrequencyPointsField.Value = 1024;

            % Create FrequencyPointsLabel
            app.FrequencyPointsLabel = uilabel(app.GridLayout_3);
            app.FrequencyPointsLabel.Tag = 'FrequencyPointsLabel';
            app.FrequencyPointsLabel.FontName = 'Microsoft YaHei UI';
            app.FrequencyPointsLabel.FontSize = 14;
            app.FrequencyPointsLabel.FontColor = [0.11 0.16 0.23];
            app.FrequencyPointsLabel.Layout.Row = 11;
            app.FrequencyPointsLabel.Layout.Column = 1;
            app.FrequencyPointsLabel.Text = '频率点数';

            % Create FrequencyMaxField
            app.FrequencyMaxField = uieditfield(app.GridLayout_3, 'numeric');
            app.FrequencyMaxField.ValueChangedFcn = createCallbackFcn(app, @FrequencyMaxFieldValueChanged, true);
            app.FrequencyMaxField.Tag = 'FrequencyMaxField';
            app.FrequencyMaxField.FontName = 'Microsoft YaHei UI';
            app.FrequencyMaxField.FontSize = 14;
            app.FrequencyMaxField.FontColor = [0.11 0.16 0.23];
            app.FrequencyMaxField.Layout.Row = 10;
            app.FrequencyMaxField.Layout.Column = 2;
            app.FrequencyMaxField.Value = 50;

            % Create FrequencyMaxLabel
            app.FrequencyMaxLabel = uilabel(app.GridLayout_3);
            app.FrequencyMaxLabel.Tag = 'FrequencyMaxLabel';
            app.FrequencyMaxLabel.FontName = 'Microsoft YaHei UI';
            app.FrequencyMaxLabel.FontSize = 14;
            app.FrequencyMaxLabel.FontColor = [0.11 0.16 0.23];
            app.FrequencyMaxLabel.Layout.Row = 10;
            app.FrequencyMaxLabel.Layout.Column = 1;
            app.FrequencyMaxLabel.Text = 'ω 上限';

            % Create FrequencyMinField
            app.FrequencyMinField = uieditfield(app.GridLayout_3, 'numeric');
            app.FrequencyMinField.ValueChangedFcn = createCallbackFcn(app, @FrequencyMinFieldValueChanged, true);
            app.FrequencyMinField.Tag = 'FrequencyMinField';
            app.FrequencyMinField.FontName = 'Microsoft YaHei UI';
            app.FrequencyMinField.FontSize = 14;
            app.FrequencyMinField.FontColor = [0.11 0.16 0.23];
            app.FrequencyMinField.Layout.Row = 9;
            app.FrequencyMinField.Layout.Column = 2;

            % Create FrequencyMinLabel
            app.FrequencyMinLabel = uilabel(app.GridLayout_3);
            app.FrequencyMinLabel.Tag = 'FrequencyMinLabel';
            app.FrequencyMinLabel.FontName = 'Microsoft YaHei UI';
            app.FrequencyMinLabel.FontSize = 14;
            app.FrequencyMinLabel.FontColor = [0.11 0.16 0.23];
            app.FrequencyMinLabel.Layout.Row = 9;
            app.FrequencyMinLabel.Layout.Column = 1;
            app.FrequencyMinLabel.Text = 'ω 下限';

            % Create ToleranceField
            app.ToleranceField = uieditfield(app.GridLayout_3, 'numeric');
            app.ToleranceField.ValueChangedFcn = createCallbackFcn(app, @ToleranceFieldValueChanged, true);
            app.ToleranceField.Tag = 'ToleranceField';
            app.ToleranceField.FontName = 'Microsoft YaHei UI';
            app.ToleranceField.FontSize = 14;
            app.ToleranceField.FontColor = [0.11 0.16 0.23];
            app.ToleranceField.Layout.Row = 8;
            app.ToleranceField.Layout.Column = 2;
            app.ToleranceField.Value = 1e-08;

            % Create ToleranceLabel
            app.ToleranceLabel = uilabel(app.GridLayout_3);
            app.ToleranceLabel.Tag = 'ToleranceLabel';
            app.ToleranceLabel.FontName = 'Microsoft YaHei UI';
            app.ToleranceLabel.FontSize = 14;
            app.ToleranceLabel.FontColor = [0.11 0.16 0.23];
            app.ToleranceLabel.Layout.Row = 8;
            app.ToleranceLabel.Layout.Column = 1;
            app.ToleranceLabel.Text = '判稳容差';

            % Create AnalysisSectionLabel
            app.AnalysisSectionLabel = uilabel(app.GridLayout_3);
            app.AnalysisSectionLabel.Tag = 'AnalysisSectionLabel';
            app.AnalysisSectionLabel.FontName = 'Microsoft YaHei UI';
            app.AnalysisSectionLabel.FontSize = 15;
            app.AnalysisSectionLabel.FontWeight = 'bold';
            app.AnalysisSectionLabel.FontColor = [0.11 0.16 0.23];
            app.AnalysisSectionLabel.Layout.Row = 7;
            app.AnalysisSectionLabel.Layout.Column = [1 2];
            app.AnalysisSectionLabel.Text = '稳定性与频响';

            % Create DenominatorField
            app.DenominatorField = uieditfield(app.GridLayout_3, 'text');
            app.DenominatorField.ValueChangedFcn = createCallbackFcn(app, @DenominatorFieldValueChanged, true);
            app.DenominatorField.Tag = 'DenominatorField';
            app.DenominatorField.FontName = 'Microsoft YaHei UI';
            app.DenominatorField.FontSize = 14;
            app.DenominatorField.Tooltip = '离散域按 z^-1 升幂；连续域按 s 降幂。可用逗号、空格或分号分隔。';
            app.DenominatorField.Layout.Row = 6;
            app.DenominatorField.Layout.Column = [1 2];
            app.DenominatorField.Value = '[1, 10, 35, 50, 24]';

            % Create DenominatorLabel
            app.DenominatorLabel = uilabel(app.GridLayout_3);
            app.DenominatorLabel.Tag = 'DenominatorLabel';
            app.DenominatorLabel.FontName = 'Microsoft YaHei UI';
            app.DenominatorLabel.FontSize = 14;
            app.DenominatorLabel.FontColor = [0.11 0.16 0.23];
            app.DenominatorLabel.Layout.Row = 5;
            app.DenominatorLabel.Layout.Column = [1 2];
            app.DenominatorLabel.Text = '分母系数';

            % Create NumeratorField
            app.NumeratorField = uieditfield(app.GridLayout_3, 'text');
            app.NumeratorField.ValueChangedFcn = createCallbackFcn(app, @NumeratorFieldValueChanged, true);
            app.NumeratorField.Tag = 'NumeratorField';
            app.NumeratorField.FontName = 'Microsoft YaHei UI';
            app.NumeratorField.FontSize = 14;
            app.NumeratorField.Tooltip = '离散域按 z^-1 升幂；连续域按 s 降幂。可用逗号、空格或分号分隔。';
            app.NumeratorField.Layout.Row = 4;
            app.NumeratorField.Layout.Column = [1 2];
            app.NumeratorField.Value = '[1, 7, 24, 24]';

            % Create NumeratorLabel
            app.NumeratorLabel = uilabel(app.GridLayout_3);
            app.NumeratorLabel.Tag = 'NumeratorLabel';
            app.NumeratorLabel.FontName = 'Microsoft YaHei UI';
            app.NumeratorLabel.FontSize = 14;
            app.NumeratorLabel.FontColor = [0.11 0.16 0.23];
            app.NumeratorLabel.Layout.Row = 3;
            app.NumeratorLabel.Layout.Column = [1 2];
            app.NumeratorLabel.Text = '分子系数';

            % Create DomainDropDown
            app.DomainDropDown = uidropdown(app.GridLayout_3);
            app.DomainDropDown.Items = {'离散域（z）', '连续域（s）'};
            app.DomainDropDown.ItemsData = {'discrete', 'continuous'};
            app.DomainDropDown.ValueChangedFcn = createCallbackFcn(app, @DomainDropDownValueChanged, true);
            app.DomainDropDown.Tag = 'DomainDropDown';
            app.DomainDropDown.FontName = 'Microsoft YaHei UI';
            app.DomainDropDown.FontSize = 14;
            app.DomainDropDown.Layout.Row = 2;
            app.DomainDropDown.Layout.Column = 2;
            app.DomainDropDown.Value = 'continuous';

            % Create DomainLabel
            app.DomainLabel = uilabel(app.GridLayout_3);
            app.DomainLabel.Tag = 'DomainLabel';
            app.DomainLabel.FontName = 'Microsoft YaHei UI';
            app.DomainLabel.FontSize = 14;
            app.DomainLabel.FontColor = [0.11 0.16 0.23];
            app.DomainLabel.Layout.Row = 2;
            app.DomainLabel.Layout.Column = 1;
            app.DomainLabel.Text = '系统类型';

            % Create ModelSectionLabel
            app.ModelSectionLabel = uilabel(app.GridLayout_3);
            app.ModelSectionLabel.Tag = 'ModelSectionLabel';
            app.ModelSectionLabel.FontName = 'Microsoft YaHei UI';
            app.ModelSectionLabel.FontSize = 15;
            app.ModelSectionLabel.FontWeight = 'bold';
            app.ModelSectionLabel.FontColor = [0.11 0.16 0.23];
            app.ModelSectionLabel.Layout.Row = 1;
            app.ModelSectionLabel.Layout.Column = [1 2];
            app.ModelSectionLabel.Text = '系统模型';

            % Create Panel
            app.Panel = uipanel(app.GridLayout);
            app.Panel.BorderType = 'none';
            app.Panel.BackgroundColor = [1 1 1];
            app.Panel.Layout.Row = 1;
            app.Panel.Layout.Column = 1;

            % Create GridLayout_1
            app.GridLayout_1 = uigridlayout(app.Panel);
            app.GridLayout_1.ColumnWidth = {'1x', 340};
            app.GridLayout_1.RowHeight = {'1x'};
            app.GridLayout_1.Padding = [16 4 16 4];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.GridLayout_1);
            app.StatusLabel.Tag = 'StatusLabel';
            app.StatusLabel.HorizontalAlignment = 'right';
            app.StatusLabel.FontName = 'Microsoft YaHei UI';
            app.StatusLabel.FontSize = 14;
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.FontColor = [0.1 0.48 0.3];
            app.StatusLabel.Layout.Row = 1;
            app.StatusLabel.Layout.Column = 2;
            app.StatusLabel.Text = '分母判稳 稳定  ·  最右极点实部 -1';

            % Create AppTitle
            app.AppTitle = uilabel(app.GridLayout_1);
            app.AppTitle.Tag = 'AppTitle';
            app.AppTitle.FontName = 'Microsoft YaHei UI';
            app.AppTitle.FontSize = 21;
            app.AppTitle.FontWeight = 'bold';
            app.AppTitle.FontColor = [0.11 0.16 0.23];
            app.AppTitle.Layout.Row = 1;
            app.AppTitle.Layout.Column = 1;
            app.AppTitle.Text = '实验四 · 连续 / 离散系统稳定性';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SystemStabilityApp(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

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