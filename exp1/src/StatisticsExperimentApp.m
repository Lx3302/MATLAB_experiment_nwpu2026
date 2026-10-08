classdef StatisticsExperimentApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        ShellGrid             matlab.ui.container.GridLayout
        Sidebar               matlab.ui.container.Panel
        GridLayout            matlab.ui.container.GridLayout
        Label                 matlab.ui.control.Label
        NavigationSimulation  matlab.ui.control.Button
        NavigationAudio       matlab.ui.control.Button
        Label_2               matlab.ui.control.Label
        ContentGrid           matlab.ui.container.GridLayout
        HeaderGrid            matlab.ui.container.GridLayout
        PageTitle             matlab.ui.control.Label
        StateLabel            matlab.ui.control.Label
        SaveDataButton        matlab.ui.control.Button
        SaveFigureButton      matlab.ui.control.Button
        WorkspaceGrid         matlab.ui.container.GridLayout
        SimPage               matlab.ui.container.Panel
        SimLayout             matlab.ui.container.GridLayout
        Panel                 matlab.ui.container.Panel
        GridLayout_2          matlab.ui.container.GridLayout
        Label_3               matlab.ui.control.Label
        TermsEditField        matlab.ui.control.NumericEditField
        Label_4               matlab.ui.control.Label
        TrialsEditField       matlab.ui.control.NumericEditField
        Label_5               matlab.ui.control.Label
        SimBinModeDropDown    matlab.ui.control.DropDown
        SimBinValueLabel      matlab.ui.control.Label
        SimBinValueField      matlab.ui.control.NumericEditField
        RunSimButton          matlab.ui.control.Button
        Label_6               matlab.ui.control.Label
        Panel_2               matlab.ui.container.Panel
        GridLayout_3          matlab.ui.container.GridLayout
        Panel_5               matlab.ui.container.Panel
        GridLayout_6          matlab.ui.container.GridLayout
        SimAxes               matlab.ui.control.UIAxes
        Panel_6               matlab.ui.container.Panel
        GridLayout_7          matlab.ui.container.GridLayout
        Label_13              matlab.ui.control.Label
        SimMeanField          matlab.ui.control.EditField
        Label_14              matlab.ui.control.Label
        SimVarianceField      matlab.ui.control.EditField
        Label_15              matlab.ui.control.Label
        SimStdField           matlab.ui.control.EditField
        Label_16              matlab.ui.control.Label
        SimCountField         matlab.ui.control.EditField
        Label_17              matlab.ui.control.Label
        TheoryMeanField       matlab.ui.control.EditField
        Label_18              matlab.ui.control.Label
        TheoryVarianceField   matlab.ui.control.EditField
        Label_19              matlab.ui.control.Label
        TheoryStdField        matlab.ui.control.EditField
        Label_20              matlab.ui.control.Label
        SimWidthField         matlab.ui.control.EditField
        AudioPage             matlab.ui.container.Panel
        AudioLayout           matlab.ui.container.GridLayout
        Panel_3               matlab.ui.container.Panel
        GridLayout_4          matlab.ui.container.GridLayout
        LoadAudioButton       matlab.ui.control.Button
        AudioFileField        matlab.ui.control.EditField
        Label_7               matlab.ui.control.Label
        SampleRateField       matlab.ui.control.EditField
        Label_8               matlab.ui.control.Label
        ChannelCountField     matlab.ui.control.EditField
        Label_9               matlab.ui.control.Label
        DurationField         matlab.ui.control.EditField
        Label_10              matlab.ui.control.Label
        StartTimeField        matlab.ui.control.NumericEditField
        Label_11              matlab.ui.control.Label
        EndTimeField          matlab.ui.control.NumericEditField
        Label_12              matlab.ui.control.Label
        AudioBinModeDropDown  matlab.ui.control.DropDown
        AudioBinValueLabel    matlab.ui.control.Label
        AudioBinValueField    matlab.ui.control.NumericEditField
        AnalyzeAudioButton    matlab.ui.control.Button
        WindowInfoLabel       matlab.ui.control.Label
        Panel_4               matlab.ui.container.Panel
        GridLayout_5          matlab.ui.container.GridLayout
        Panel_7               matlab.ui.container.Panel
        GridLayout_8          matlab.ui.container.GridLayout
        WaveAxes              matlab.ui.control.UIAxes
        Panel_8               matlab.ui.container.Panel
        GridLayout_9          matlab.ui.container.GridLayout
        RightWaveAxes         matlab.ui.control.UIAxes
        Panel_9               matlab.ui.container.Panel
        GridLayout_10         matlab.ui.container.GridLayout
        AudioHistAxes         matlab.ui.control.UIAxes
        Panel_10              matlab.ui.container.Panel
        GridLayout_11         matlab.ui.container.GridLayout
        RightHistAxes         matlab.ui.control.UIAxes
        Panel_11              matlab.ui.container.Panel
        GridLayout_12         matlab.ui.container.GridLayout
        Label_21              matlab.ui.control.Label
        LeftMeanField         matlab.ui.control.EditField
        Label_22              matlab.ui.control.Label
        LeftVarianceField     matlab.ui.control.EditField
        Label_23              matlab.ui.control.Label
        LeftStdField          matlab.ui.control.EditField
        Label_24              matlab.ui.control.Label
        LeftRMSField          matlab.ui.control.EditField
        Panel_12              matlab.ui.container.Panel
        GridLayout_13         matlab.ui.container.GridLayout
        Label_25              matlab.ui.control.Label
        RightMeanField        matlab.ui.control.EditField
        Label_26              matlab.ui.control.Label
        RightVarianceField    matlab.ui.control.EditField
        Label_27              matlab.ui.control.Label
        RightStdField         matlab.ui.control.EditField
        Label_28              matlab.ui.control.Label
        RightRMSField         matlab.ui.control.EditField
        StatusLabel           matlab.ui.control.Label
    end

    properties (Access = private)
        % 纯数据快照，不含窗口、坐标轴或回调句柄。
        Audio struct = struct()
        SimulationResult struct = struct()
        AudioResult struct = struct()
        CurrentPage char = 'simulation'
        Busy logical = false
        Closing logical = false
    end

    methods (Access = private)



























































































































































































        % ---------- 视图状态：仅管理控件，不执行实验算法 ----------
        function showPage(app, page)
            app.CurrentPage = page;
            isSimulation = strcmp(page, 'simulation');
            app.SimPage.Visible = app.onOff(isSimulation);
            app.AudioPage.Visible = app.onOff(~isSimulation);
            colors = app.theme();
            app.NavigationSimulation.BackgroundColor = colors.Sidebar;
            app.NavigationAudio.BackgroundColor = colors.Sidebar;
            if isSimulation
                app.PageTitle.Text = '随机数仿真';
                app.NavigationSimulation.BackgroundColor = colors.Selection;
            else
                app.PageTitle.Text = '音频分析';
                app.NavigationAudio.BackgroundColor = colors.Selection;
            end
            if isfield(app.currentResult(), 'Samples')
                app.setStatus('当前结果可保存或导出', 'success');
            elseif ~isSimulation && isfield(app.Audio, 'Samples')
                app.setStatus('音频已导入，请开始分析', 'pending');
            else
                app.setStatus('就绪', 'idle');
            end
            app.refreshActions();
        end

        function started = beginOperation(app, message)
            started = ~app.Busy && ~app.Closing && isvalid(app.UIFigure);
            if ~started, return; end
            app.Busy = true;
            app.refreshActions();
            app.setStatus(message, 'busy');
            % 刷新画面但不重入其他回调，避免清理与新操作交错。
            drawnow limitrate nocallbacks
        end

        function finishOperation(app)
            if app.Closing || ~isvalid(app.UIFigure), return; end
            app.Busy = false;
            app.refreshActions();
            drawnow limitrate nocallbacks
        end

        function refreshActions(app)
            available = ~app.Busy;
            controls = {app.NavigationSimulation, app.NavigationAudio, ...
                app.TermsEditField, app.TrialsEditField, app.SimBinModeDropDown, ...
                app.SimBinValueField, app.RunSimButton, app.LoadAudioButton};
            for k = 1:numel(controls), controls{k}.Enable = app.onOff(available); end
            hasAudio = isfield(app.Audio, 'Samples');
            controls = {app.StartTimeField, app.EndTimeField, app.AudioBinModeDropDown, ...
                app.AudioBinValueField, app.AnalyzeAudioButton};
            for k = 1:numel(controls), controls{k}.Enable = app.onOff(available && hasAudio); end
            canSave = available && isfield(app.currentResult(), 'Samples');
            app.SaveDataButton.Enable = app.onOff(canSave);
            app.SaveFigureButton.Enable = app.onOff(canSave);
        end

        function result = currentResult(app)
            if strcmp(app.CurrentPage, 'simulation')
                result = app.SimulationResult;
            else
                result = app.AudioResult;
            end
        end

        function setStatus(app, message, state)
            colors = app.theme();
            app.StatusLabel.Text = message;
            app.StatusLabel.Tooltip = message;
            switch state
                case 'success', text = '已完成'; color = colors.Success;
                case 'error', text = '需处理'; color = colors.Danger;
                case 'busy', text = '处理中'; color = colors.Accent;
                case 'pending', text = '待运行'; color = colors.Warning;
                otherwise, text = '就绪'; color = colors.Muted;
            end
            app.StateLabel.Text = text;
            app.StateLabel.FontColor = color;
        end

        function showError(app, exception)
            app.setStatus(exception.message, 'error');
            app.StatusLabel.Tooltip = sprintf('%s\n%s', exception.message, exception.identifier);
        end

        function updateAudioPreview(app)
            app.invalidateAudioResult();
            preview = StatisticsExperimentMath.previewAudio(app.Audio, ...
                app.StartTimeField.Value, app.EndTimeField.Value, 6000);
            app.renderWaveforms(preview.Waveforms);
            app.WindowInfoLabel.Text = sprintf('%.6g–%.6g s · %g 个样本', ...
                preview.ActualWindow, preview.SampleCount);
            app.WindowInfoLabel.Tooltip = '左闭右开时间段 [起始, 结束)，按采样点对齐';
        end

        function invalidateAudioResult(app)
            app.AudioResult = struct();
            app.clearFields([app.leftFields(), app.rightFields()]);
            app.emptyPlot(app.AudioHistAxes, '等待分析');
            app.emptyPlot(app.RightHistAxes, '等待分析');
        end

        function renderSimulation(app, result)
            colors = app.theme(); stats = result.Statistics;
            ax = app.SimAxes; cla(ax); legend(ax, 'off');
            histogram(ax, 'BinEdges', result.BinEdges, 'BinCounts', result.Plot.Density, ...
                'FaceColor', colors.Series1, 'FaceAlpha', .65, 'EdgeColor', 'none', ...
                'DisplayName', '仿真概率密度');
            hold(ax, 'on');
            plot(ax, result.Plot.FitX, result.Plot.FitDensity, ...
                'Color', colors.Series2, 'LineWidth', 1.8, 'DisplayName', '样本参数高斯拟合');
            plot(ax, result.Plot.FitX, result.Plot.TheoryDensity, '--', ...
                'Color', colors.Ink, 'LineWidth', 1.6, 'DisplayName', '理论参数高斯近似');
            hold(ax, 'off');
            title(ax, sprintf('均值 %.5g    方差 %.5g', stats.Mean, stats.Variance));
            xlabel(ax, '随机变量之和 S'); ylabel(ax, '概率密度');
            legend(ax, 'Location', 'northeast'); xlim(ax, result.BinEdges([1 end]));
            app.writeFields(app.simFields(), [stats.Mean, stats.Variance, stats.Std, ...
                result.Trials, result.TheoreticalMean, result.TheoreticalVariance, ...
                sqrt(result.TheoreticalVariance), result.BinEdges(2)-result.BinEdges(1)]);
        end

        function renderAudio(app, result)
            app.renderWaveforms(result.Waveforms);
            colors = app.theme(); axesList = {app.AudioHistAxes, app.RightHistAxes};
            stats = result.Statistics; names = {'左声道', '右声道'};
            series = [colors.Series1; colors.Series2]; fields = {app.leftFields(), app.rightFields()};
            for channel = 1:size(result.Samples, 2)
                ax = axesList{channel}; cla(ax); legend(ax, 'off');
                histogram(ax, 'BinEdges', result.BinEdges, 'BinCounts', result.Plot.Density(:,channel), ...
                    'FaceColor', series(channel,:), 'FaceAlpha', .65, 'EdgeColor', 'none', ...
                    'DisplayName', '样本概率密度');
                if stats.Std(channel) > 0
                    hold(ax, 'on');
                    plot(ax, result.Plot.FitX, result.Plot.FitDensity(:,channel), ...
                        'Color', colors.Ink, 'LineWidth', 1.5, 'DisplayName', '高斯参考');
                    hold(ax, 'off');
                end
                title(ax, sprintf('均值 %.5g    方差 %.5g', stats.Mean(channel), stats.Variance(channel)));
                xlabel(ax, '幅值'); ylabel(ax, '概率密度');
                xlim(ax, result.BinEdges([1 end]));
                app.writeFields(fields{channel}, [stats.Mean(channel), stats.Variance(channel), ...
                    stats.Std(channel), stats.RMS(channel)]);
                title(axesList{channel}, sprintf('%s · 均值 %.4g · 方差 %.4g', ...
                    names{channel}, stats.Mean(channel), stats.Variance(channel)));
            end
            if size(result.Samples,2) == 1, app.emptyPlot(app.RightHistAxes, '无右声道'); end
        end

        function renderWaveforms(app, waveforms)
            axesList = {app.WaveAxes, app.RightWaveAxes}; colors = app.theme();
            series = [colors.Series1; colors.Series2]; names = {'左声道', '右声道'};
            for channel = 1:numel(waveforms)
                ax = axesList{channel}; cla(ax);
                plot(ax, waveforms(channel).Time, waveforms(channel).Amplitude, ...
                    'Color', series(channel,:), 'LineWidth', .8);
                title(ax, names{channel}); xlabel(ax, '时间 / s'); ylabel(ax, '幅值');
                axis(ax, 'tight');
            end
            if numel(waveforms) == 1, app.emptyPlot(app.RightWaveAxes, '无右声道'); end
        end

        function fields = simFields(app)
            fields = {app.SimMeanField, app.SimVarianceField, app.SimStdField, app.SimCountField, ...
                app.TheoryMeanField, app.TheoryVarianceField, app.TheoryStdField, app.SimWidthField};
        end

        function fields = leftFields(app)
            fields = {app.LeftMeanField, app.LeftVarianceField, app.LeftStdField, app.LeftRMSField};
        end

        function fields = rightFields(app)
            fields = {app.RightMeanField, app.RightVarianceField, app.RightStdField, app.RightRMSField};
        end

        function tagComponents(app)
            names = properties(app);
            for k = 1:numel(names)
                component = app.(names{k});
                % App Designer 保存后会为所有组件生成公开属性；保留布局角色标签。
                if isscalar(component) && isobject(component) && isprop(component, 'Tag') && ...
                        ~ismember(component.Tag, {'ParameterSection','ResultSection'})
                    component.Tag = names{k};
                end
            end
        end

        % ---------- 界面构建：App Designer 可视组件及统一样式 ----------


















































        function buildSimulationPage(app)
            app.SimLayout = app.pageLayout(app.SimPage);
            parameters = app.panel(app.SimLayout, '实验参数', 1, 1);
            parameters.Tag = 'ParameterSection';
            form = uigridlayout(parameters,[9 2], 'ColumnWidth',{106,'1x'}, ...
                'RowHeight',{36,36,14,36,36,16,42,46,'1x'});
            app.styleForm(form);
            app.label(form, '求和个数 m', 1, 1);
            app.TermsEditField = app.numberField(form, 1, 2, 100, [1 Inf], true);
            app.TermsEditField.Tooltip = '每次试验独立抽取 m 个 U(0,1) 随机数并相加';
            app.TermsEditField.ValueChangedFcn = createCallbackFcn(app, @SimulationParametersChanged, true);
            app.label(form, '样本数 N', 2, 1);
            app.TrialsEditField = app.numberField(form, 2, 2, 10000, [1 Inf], true);
            app.TrialsEditField.Tooltip = '重复试验次数；m × N 最大为 1e8';
            app.TrialsEditField.ValueChangedFcn = createCallbackFcn(app, @SimulationParametersChanged, true);
            app.label(form, '分箱方式', 4, 1);
            app.SimBinModeDropDown = app.binDropdown(form, 4, 2);
            app.SimBinModeDropDown.ValueChangedFcn = createCallbackFcn(app, @SimulationBinModeChanged, true);
            app.SimBinValueLabel = app.label(form, '区间数', 5, 1);
            app.SimBinValueField = app.numberField(form,5,2,60,[1 5000],true);
            app.SimBinValueField.ValueChangedFcn = createCallbackFcn(app, @SimulationParametersChanged, true);
            app.RunSimButton = app.primaryButton(form,'开始仿真',7,[1 2]);
            app.RunSimButton.ButtonPushedFcn = createCallbackFcn(app, @RunSimulation, true);
            note = app.label(form, '独立均匀变量 U(0,1)', 8, [1 2]);
            note.FontSize = 12;
            note.Tooltip = '同时显示经验密度、样本参数高斯拟合、理论参数高斯近似；小 m 时高斯近似可能不理想';
            results = app.panel(app.SimLayout, '', 1, 2); results.Tag = 'ResultSection';
            results.BorderType = 'none';
            grid = uigridlayout(results,[2 1], 'RowHeight',{'1x',206},'Padding',0, 'RowSpacing',14);
            grid.BackgroundColor = app.theme().Canvas;
            plotPanel = app.panel(grid,'概率密度与高斯拟合',1,1);
            plotGrid = uigridlayout(plotPanel,[1 1],'Padding',[10 8 10 10],'BackgroundColor',[1 1 1]);
            app.SimAxes = uiaxes(plotGrid); app.styleAxes(app.SimAxes);
            app.emptyPlot(app.SimAxes, '设置参数，开始仿真');
            statsPanel = app.panel(grid,'统计对比',2,1);
            fields = app.metricFields(statsPanel, ...
                {'样本均值','样本方差','样本标准差','样本数 N', ...
                 '理论均值','理论方差','理论标准差','实际宽度 Δ'},4);
            app.SimMeanField=fields{1}; app.SimVarianceField=fields{2};
            app.SimStdField=fields{3}; app.SimCountField=fields{4};
            app.TheoryMeanField=fields{5}; app.TheoryVarianceField=fields{6};
            app.TheoryStdField=fields{7}; app.SimWidthField=fields{8};
        end

        function buildAudioPage(app)
            app.AudioLayout = app.pageLayout(app.AudioPage);
            parameters = app.panel(app.AudioLayout,'音频与参数',1,1); parameters.Tag='ParameterSection';
            form = uigridlayout(parameters,[15 2], 'ColumnWidth',{106,'1x'}, ...
                'RowHeight',{38,32,32,32,32,14,36,36,14,36,36,14,40,40,'1x'});
            app.styleForm(form);
            app.LoadAudioButton = uibutton(form,'Text','导入音频','FontName','Microsoft YaHei','FontSize',13);
            app.place(app.LoadAudioButton,1,[1 2]);
            app.LoadAudioButton.ButtonPushedFcn = createCallbackFcn(app, @ImportAudio, true);
            app.AudioFileField = app.readout(form,2,[1 2]); app.AudioFileField.Value='尚未导入';
            app.label(form,'采样率 / Hz',3,1); app.SampleRateField=app.readout(form,3,2);
            app.label(form,'文件声道数',4,1); app.ChannelCountField=app.readout(form,4,2);
            app.label(form,'时长 / s',5,1); app.DurationField=app.readout(form,5,2);
            app.label(form,'起始时间 / s',7,1); app.StartTimeField=app.numberField(form,7,2,0,[0 Inf],false);
            app.StartTimeField.ValueChangedFcn = createCallbackFcn(app, @AudioParametersChanged, true);
            app.label(form,'结束时间 / s',8,1); app.EndTimeField=app.numberField(form,8,2,1,[0 Inf],false);
            app.EndTimeField.ValueChangedFcn = createCallbackFcn(app, @AudioParametersChanged, true);
            app.label(form,'分箱方式',10,1); app.AudioBinModeDropDown=app.binDropdown(form,10,2);
            app.AudioBinModeDropDown.ValueChangedFcn = createCallbackFcn(app, @AudioBinModeChanged, true);
            app.AudioBinValueLabel=app.label(form,'区间数',11,1);
            app.AudioBinValueField=app.numberField(form,11,2,100,[1 5000],true);
            app.AudioBinValueField.ValueChangedFcn = createCallbackFcn(app, @AudioParametersChanged, true);
            app.AnalyzeAudioButton=app.primaryButton(form,'开始分析',13,[1 2]);
            app.AnalyzeAudioButton.ButtonPushedFcn = createCallbackFcn(app, @AnalyzeAudio, true);
            app.WindowInfoLabel=app.label(form,'选择音频文件',14,[1 2]);
            app.WindowInfoLabel.FontSize=12; app.WindowInfoLabel.WordWrap='on';
            results=app.panel(app.AudioLayout,'',1,2); results.Tag='ResultSection'; results.BorderType='none';
            grid=uigridlayout(results,[3 2],'RowHeight',{'1x','1x',176}, ...
                'ColumnWidth',{'1x','1x'},'Padding',0,'RowSpacing',12,'ColumnSpacing',12);
            grid.BackgroundColor=app.theme().Canvas;
            axesList=cell(1,4); names={'左声道 · 波形','右声道 · 波形','左声道 · 概率密度','右声道 · 概率密度'};
            for k=1:4
                panel=app.panel(grid,names{k},ceil(k/2),mod(k-1,2)+1);
                axisGrid=uigridlayout(panel,[1 1],'Padding',[4 2 4 4],'BackgroundColor',[1 1 1]);
                axesList{k}=uiaxes(axisGrid); app.styleAxes(axesList{k});
                app.emptyPlot(axesList{k},'等待导入');
            end
            app.WaveAxes=axesList{1}; app.RightWaveAxes=axesList{2};
            app.AudioHistAxes=axesList{3}; app.RightHistAxes=axesList{4};
            fields=app.metricFields(app.panel(grid,'左声道统计',3,1),{'均值','方差','标准差','RMS'},2);
            app.LeftMeanField=fields{1}; app.LeftVarianceField=fields{2}; app.LeftStdField=fields{3}; app.LeftRMSField=fields{4};
            fields=app.metricFields(app.panel(grid,'右声道统计',3,2),{'均值','方差','标准差','RMS'},2);
            app.RightMeanField=fields{1}; app.RightVarianceField=fields{2}; app.RightStdField=fields{3}; app.RightRMSField=fields{4};
        end
    end

    methods (Static, Access = private)
        function colors = theme()
            % 视觉语义集中定义，修改主题无需改动业务接口。
            colors=struct('Canvas',[.949 .957 .973], 'Sidebar',[.133 .173 .239], ...
                'Selection',[.18 .32 .50], 'Ink',[.125 .145 .204], 'Muted',[.31 .35 .43], ...
                'Accent',[0 .412 .851], 'Success',[.067 .459 .22], 'Warning',[.541 .349 0], ...
                'Danger',[.765 .149 .196], 'Series1',[.031 .42 .80], 'Series2',[.60 .396 0]);
        end

        function place(component, row, column)
            component.Layout.Row=row; component.Layout.Column=column;
        end

        function component=label(parent, text, row, column)
            component=uilabel(parent,'Text',text,'FontName','Microsoft YaHei','FontSize',13);
            component.FontColor=StatisticsExperimentApp.theme().Ink;
            StatisticsExperimentApp.place(component,row,column);
        end

        function component=panel(parent, text, row, column)
            component=uipanel(parent,'Title',text,'BackgroundColor',[1 1 1], ...
                'FontName','Microsoft YaHei','FontSize',13,'FontWeight','bold','BorderType','line');
            StatisticsExperimentApp.place(component,row,column);
        end

        function grid=pageLayout(parent)
            grid=uigridlayout(parent,[1 2],'ColumnWidth',{256,'1x'},'Padding',0, ...
                'ColumnSpacing',16,'RowSpacing',16,'Scrollable','on');
            grid.BackgroundColor=StatisticsExperimentApp.theme().Canvas;
        end

        function styleForm(grid)
            grid.Padding=[16 16 16 16]; grid.RowSpacing=8; grid.ColumnSpacing=8;
            grid.BackgroundColor=[1 1 1];
        end

        function field=numberField(parent,row,column,value,limits,integer)
            field=uieditfield(parent,'numeric','Value',value,'Limits',limits, ...
                'RoundFractionalValues',StatisticsExperimentApp.onOff(integer), ...
                'FontName','Microsoft YaHei','FontSize',13,'ValueDisplayFormat','%.8g');
            StatisticsExperimentApp.place(field,row,column);
        end

        function field=readout(parent,row,column)
            field=uieditfield(parent,'text','Value','—','Editable','off', ...
                'FontName','Microsoft YaHei','FontSize',13,'BackgroundColor',[.97 .98 .99]);
            StatisticsExperimentApp.place(field,row,column);
        end

        function dropdown=binDropdown(parent,row,column)
            dropdown=uidropdown(parent,'Items',{'区间数','区间宽度'},'FontName','Microsoft YaHei','FontSize',13);
            StatisticsExperimentApp.place(dropdown,row,column);
        end

        function button=primaryButton(parent,text,row,column)
            button=uibutton(parent,'Text',text,'FontName','Microsoft YaHei','FontSize',14, ...
                'FontWeight','bold','FontColor',[1 1 1]);
            button.BackgroundColor=StatisticsExperimentApp.theme().Accent;
            StatisticsExperimentApp.place(button,row,column);
        end

        function button=navButton(parent,text,row)
            button=uibutton(parent,'Text',text,'FontName','Microsoft YaHei','FontSize',14,'FontColor',[1 1 1]);
            button.BackgroundColor=StatisticsExperimentApp.theme().Sidebar;
            StatisticsExperimentApp.place(button,row,1);
        end

        function fields=metricFields(parent,names,columns)
            rows=ceil(numel(names)/columns);
            grid=uigridlayout(parent,[2*rows columns], ...
                'RowHeight',repmat({20,30},1,rows),'Padding',[14 10 14 12], ...
                'RowSpacing',6,'ColumnSpacing',12,'BackgroundColor',[1 1 1]);
            fields=cell(1,numel(names));
            for k=1:numel(names)
                row=2*floor((k-1)/columns)+1; column=mod(k-1,columns)+1;
                label=StatisticsExperimentApp.label(grid,names{k},row,column); label.FontSize=12;
                fields{k}=StatisticsExperimentApp.readout(grid,row+1,column);
            end
        end

        function styleAxes(ax)
            ax.FontName='Microsoft YaHei'; ax.FontSize=10;
            ax.XGrid='on'; ax.YGrid='on'; ax.GridAlpha=.10;
            ax.Box='off'; ax.Toolbar.Visible='off'; ax.TitleFontSizeMultiplier=1.1;
        end

        function emptyPlot(ax,text)
            cla(ax); legend(ax,'off'); title(ax,text); xlabel(ax,''); ylabel(ax,'');
        end

        function clearFields(fields)
            for k=1:numel(fields), fields{k}.Value='—'; fields{k}.Tooltip=''; end
        end

        function writeFields(fields,values)
            for k=1:numel(fields)
                fields{k}.Value=sprintf('%.8g',values(k)); fields{k}.Tooltip=sprintf('%.16g',values(k));
            end
        end

        function value=onOff(condition)
            if condition, value='on'; else, value='off'; end
        end

        function mode=binMode(dropdown)
            if strcmp(dropdown.Value,'区间数'), mode='count'; else, mode='width'; end
        end

        function configureBins(dropdown,label,field,count,width)
            if strcmp(dropdown.Value,'区间数')
                field.Limits=[1 Inf]; field.Value=count; field.Limits=[1 5000];
                field.RoundFractionalValues='on'; label.Text='区间数';
            else
                field.RoundFractionalValues='off'; field.Limits=[0 Inf];
                field.Value=width; label.Text='区间宽度 Δ';
            end
        end

        function positionPageSections(layout,compact)
            parameters=findobj(layout,'-depth',1,'Tag','ParameterSection');
            results=findobj(layout,'-depth',1,'Tag','ResultSection');
            StatisticsExperimentApp.place(parameters,1,1);
            if compact, StatisticsExperimentApp.place(results,2,1);
            else, StatisticsExperimentApp.place(results,1,2); end
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.tagComponents();
            app.showPage('simulation');
            app.WindowResized([]);
            app.setStatus('就绪', 'idle');
        end

        % Close request function: UIFigure
        function CloseApp(app, event)
            % 保存/导出中的事件刷新不允许提前析构正在工作的 App。
            if app.Busy
                app.setStatus('操作进行中，请完成后关闭窗口', 'busy');
                return;
            end
            delete(app);
        end

        % Size changed function: UIFigure
        function WindowResized(app, event)
            if isempty(app.SimLayout) || isempty(app.AudioLayout), return; end
            compact = app.UIFigure.Position(3) < 1180;
            if compact
                app.ShellGrid.ColumnWidth = {160, '1x'};
                app.SimLayout.ColumnWidth = {'1x'};
                app.SimLayout.RowHeight = {400, 620};
                app.AudioLayout.ColumnWidth = {'1x'};
                app.AudioLayout.RowHeight = {710, 800};
            else
                app.ShellGrid.ColumnWidth = {184, '1x'};
                app.SimLayout.ColumnWidth = {256, '1x'};
                app.SimLayout.RowHeight = {'1x'};
                app.AudioLayout.ColumnWidth = {256, '1x'};
                app.AudioLayout.RowHeight = {'1x'};
            end
            app.positionPageSections(app.SimLayout, compact);
            app.positionPageSections(app.AudioLayout, compact);
        end

        % Button pushed function: NavigationSimulation
        function ShowSimulation(app, event)
            app.showPage('simulation');
        end

        % Button pushed function: NavigationAudio
        function ShowAudio(app, event)
            app.showPage('audio');
        end

        % Button pushed function: SaveDataButton
        function SaveData(app, event)
            result = app.currentResult();
            if ~isfield(result, 'Samples') || ~app.beginOperation('选择保存位置'), return; end
            try
                [file, folder] = uiputfile( ...
                    {'*.mat','完整结果 (*.mat)'; '*.csv','样本与统计量 (*.csv)'}, ...
                    '保存数据', [result.Kind '.mat']);
                if isequal(file, 0)
                    app.setStatus('已取消保存', 'idle');
                else
                    % 接口仅传纯数据；保存函数不持有或操作主窗口。
                    files = StatisticsExperimentMath.saveResult(result, fullfile(folder, file));
                    app.setStatus(sprintf('已保存 %d 个数据文件', numel(files)), 'success');
                    app.StatusLabel.Tooltip = strjoin(files, newline);
                end
            catch exception
                app.showError(exception);
            end
            app.finishOperation();
        end

        % Button pushed function: SaveFigureButton
        function SaveFigure(app, event)
            result = app.currentResult();
            if ~isfield(result, 'Samples') || ~app.beginOperation('选择导出位置'), return; end
            try
                [file, folder] = uiputfile( ...
                    {'*.png','高清图像 (*.png)'; '*.pdf','矢量图像 (*.pdf)'}, ...
                    '导出图像', [result.Kind '.png']);
                if isequal(file, 0)
                    app.setStatus('已取消导出', 'idle');
                else
                    % 后台创建并清理专用导出图，不接收 UIFigure/UIAxes。
                    StatisticsExperimentMath.exportFigure(result, fullfile(folder, file));
                    app.setStatus('图像已导出', 'success');
                    app.StatusLabel.Tooltip = fullfile(folder, file);
                end
            catch exception
                app.showError(exception);
            end
            app.finishOperation();
        end

        % Value changed function: SimBinValueField, TermsEditField,
        % ...and 1 other component
        function SimulationParametersChanged(app, event)
            if app.Busy, return; end
            app.SimulationResult = struct();
            app.clearFields(app.simFields());
            app.emptyPlot(app.SimAxes, '参数已修改，等待仿真');
            app.setStatus('参数已修改，请开始仿真', 'pending');
            app.refreshActions();
        end

        % Value changed function: SimBinModeDropDown
        function SimulationBinModeChanged(app, event)
            app.configureBins(app.SimBinModeDropDown, app.SimBinValueLabel, ...
                app.SimBinValueField, 60, 1);
            app.SimulationParametersChanged(event);
        end

        % Button pushed function: RunSimButton
        function RunSimulation(app, event)
            if ~app.beginOperation('正在生成样本…'), return; end
            app.SimulationResult = struct();
            app.clearFields(app.simFields());
            try
                % 接口：正整数 m、N，分箱模式与参数 → 完整结果快照。
                result = StatisticsExperimentMath.runSimulation( ...
                    app.TermsEditField.Value, app.TrialsEditField.Value, ...
                    app.binMode(app.SimBinModeDropDown), app.SimBinValueField.Value);
                app.renderSimulation(result);
                app.SimulationResult = result;
                app.setStatus(sprintf('仿真完成 · %g 次试验 · %d 个区间', ...
                    result.Trials, numel(result.BinEdges)-1), 'success');
            catch exception
                app.emptyPlot(app.SimAxes, '调整参数后重新仿真');
                app.showError(exception);
            end
            app.finishOperation();
        end

        % Button pushed function: LoadAudioButton
        function ImportAudio(app, event)
            if ~app.beginOperation('选择音频文件'), return; end
            try
                [file, folder] = uigetfile( ...
                    {'*.m4a;*.wav;*.mp3;*.flac;*.ogg', '音频文件'}, '导入音频');
                if isequal(file, 0)
                    app.setStatus('已取消导入', 'idle');
                else
                    % 接口：文件路径 → 原采样率、独立声道和来源信息。
                    audio = StatisticsExperimentMath.readAudio(fullfile(folder, file));
                    app.Audio = audio;
                    app.AudioFileField.Value = audio.SourceFile;
                    app.AudioFileField.Tooltip = audio.SourcePath;
                    app.writeFields({app.SampleRateField, app.ChannelCountField, ...
                        app.DurationField}, [audio.SampleRate, audio.OriginalChannels, audio.Duration]);
                    app.StartTimeField.Value = 0;
                    app.EndTimeField.Value = audio.Duration;
                    app.updateAudioPreview();
                    app.setStatus('音频已导入，请设置时间段并开始分析', 'pending');
                end
            catch exception
                app.showError(exception);
            end
            app.finishOperation();
        end

        % Value changed function: AudioBinValueField, EndTimeField,
        % ...and 1 other component
        function AudioParametersChanged(app, event)
            if app.Busy || ~isfield(app.Audio, 'Samples'), return; end
            try
                app.updateAudioPreview();
                app.setStatus('时间段或分箱已修改，请开始分析', 'pending');
            catch exception
                app.emptyPlot(app.WaveAxes, '请检查起止时间');
                app.emptyPlot(app.RightWaveAxes, '请检查起止时间');
                app.WindowInfoLabel.Text = '时间段无效';
                app.showError(exception);
            end
            app.refreshActions();
        end

        % Value changed function: AudioBinModeDropDown
        function AudioBinModeChanged(app, event)
            app.configureBins(app.AudioBinModeDropDown, app.AudioBinValueLabel, ...
                app.AudioBinValueField, 100, 0.02);
            app.AudioParametersChanged(event);
        end

        % Button pushed function: AnalyzeAudioButton
        function AnalyzeAudio(app, event)
            if ~isfield(app.Audio, 'Samples') || ~app.beginOperation('正在分析所选时间段…')
                return;
            end
            app.invalidateAudioResult();
            try
                % 接口：音频快照、起止秒数、分箱设置 → 各声道分析结果。
                result = StatisticsExperimentMath.analyzeAudio(app.Audio, ...
                    app.StartTimeField.Value, app.EndTimeField.Value, ...
                    app.binMode(app.AudioBinModeDropDown), app.AudioBinValueField.Value);
                app.renderAudio(result);
                app.AudioResult = result;
                app.setStatus(sprintf('分析完成 · 每声道 %g 个样本 · %d 个区间', ...
                    size(result.Samples,1), numel(result.BinEdges)-1), 'success');
            catch exception
                app.showError(exception);
            end
            app.finishOperation();
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
            app.UIFigure.Position = [80 60 1360 860];
            app.UIFigure.Name = '统计实验室';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @CloseApp, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @WindowResized, true);
            app.UIFigure.Tag = 'UIFigure';

            % Create ShellGrid
            app.ShellGrid = uigridlayout(app.UIFigure);
            app.ShellGrid.ColumnWidth = {184, '1x'};
            app.ShellGrid.RowHeight = {'1x'};
            app.ShellGrid.ColumnSpacing = 0;
            app.ShellGrid.Padding = [0 0 0 0];
            app.ShellGrid.Tag = 'ShellGrid';
            app.ShellGrid.BackgroundColor = [0.949 0.957 0.973];

            % Create ContentGrid
            app.ContentGrid = uigridlayout(app.ShellGrid);
            app.ContentGrid.ColumnWidth = {'1x'};
            app.ContentGrid.RowHeight = {60, '1x', 28};
            app.ContentGrid.RowSpacing = 12;
            app.ContentGrid.Padding = [20 12 20 12];
            app.ContentGrid.Tag = 'ContentGrid';
            app.ContentGrid.Layout.Row = 1;
            app.ContentGrid.Layout.Column = 2;
            app.ContentGrid.BackgroundColor = [0.949 0.957 0.973];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.ContentGrid);
            app.StatusLabel.Tag = 'StatusLabel';
            app.StatusLabel.FontName = 'Microsoft YaHei';
            app.StatusLabel.FontColor = [0.31 0.35 0.43];
            app.StatusLabel.Tooltip = '就绪';
            app.StatusLabel.Layout.Row = 3;
            app.StatusLabel.Layout.Column = 1;
            app.StatusLabel.Text = '就绪';

            % Create WorkspaceGrid
            app.WorkspaceGrid = uigridlayout(app.ContentGrid);
            app.WorkspaceGrid.ColumnWidth = {'1x'};
            app.WorkspaceGrid.RowHeight = {'1x'};
            app.WorkspaceGrid.Padding = [0 0 0 0];
            app.WorkspaceGrid.Tag = 'WorkspaceGrid';
            app.WorkspaceGrid.Layout.Row = 2;
            app.WorkspaceGrid.Layout.Column = 1;
            app.WorkspaceGrid.BackgroundColor = [0.949 0.957 0.973];

            % Create AudioPage
            app.AudioPage = uipanel(app.WorkspaceGrid);
            app.AudioPage.BorderType = 'none';
            app.AudioPage.Visible = 'off';
            app.AudioPage.BackgroundColor = [0.949 0.957 0.973];
            app.AudioPage.Tag = 'AudioPage';
            app.AudioPage.Layout.Row = 1;
            app.AudioPage.Layout.Column = 1;

            % Create AudioLayout
            app.AudioLayout = uigridlayout(app.AudioPage);
            app.AudioLayout.ColumnWidth = {256, '1x'};
            app.AudioLayout.RowHeight = {'1x'};
            app.AudioLayout.ColumnSpacing = 16;
            app.AudioLayout.RowSpacing = 16;
            app.AudioLayout.Padding = [0 0 0 0];
            app.AudioLayout.Tag = 'AudioLayout';
            app.AudioLayout.Scrollable = 'on';
            app.AudioLayout.BackgroundColor = [0.949 0.957 0.973];

            % Create Panel_4
            app.Panel_4 = uipanel(app.AudioLayout);
            app.Panel_4.BorderType = 'none';
            app.Panel_4.BackgroundColor = [1 1 1];
            app.Panel_4.Tag = 'ResultSection';
            app.Panel_4.Layout.Row = 1;
            app.Panel_4.Layout.Column = 2;
            app.Panel_4.FontName = 'Microsoft YaHei';
            app.Panel_4.FontWeight = 'bold';
            app.Panel_4.FontSize = 13;

            % Create GridLayout_5
            app.GridLayout_5 = uigridlayout(app.Panel_4);
            app.GridLayout_5.RowHeight = {'1x', '1x', 176};
            app.GridLayout_5.ColumnSpacing = 12;
            app.GridLayout_5.RowSpacing = 12;
            app.GridLayout_5.Padding = [0 0 0 0];
            app.GridLayout_5.BackgroundColor = [0.949 0.957 0.973];

            % Create Panel_12
            app.Panel_12 = uipanel(app.GridLayout_5);
            app.Panel_12.Title = '右声道统计';
            app.Panel_12.BackgroundColor = [1 1 1];
            app.Panel_12.Layout.Row = 3;
            app.Panel_12.Layout.Column = 2;
            app.Panel_12.FontName = 'Microsoft YaHei';
            app.Panel_12.FontWeight = 'bold';
            app.Panel_12.FontSize = 13;

            % Create GridLayout_13
            app.GridLayout_13 = uigridlayout(app.Panel_12);
            app.GridLayout_13.RowHeight = {20, 30, 20, 30};
            app.GridLayout_13.ColumnSpacing = 12;
            app.GridLayout_13.RowSpacing = 6;
            app.GridLayout_13.Padding = [14 10 14 12];
            app.GridLayout_13.BackgroundColor = [1 1 1];

            % Create RightRMSField
            app.RightRMSField = uieditfield(app.GridLayout_13, 'text');
            app.RightRMSField.Tag = 'RightRMSField';
            app.RightRMSField.Editable = 'off';
            app.RightRMSField.FontName = 'Microsoft YaHei';
            app.RightRMSField.FontSize = 13;
            app.RightRMSField.BackgroundColor = [0.97 0.98 0.99];
            app.RightRMSField.Layout.Row = 4;
            app.RightRMSField.Layout.Column = 2;
            app.RightRMSField.Value = '—';

            % Create Label_28
            app.Label_28 = uilabel(app.GridLayout_13);
            app.Label_28.FontName = 'Microsoft YaHei';
            app.Label_28.FontColor = [0.125 0.145 0.204];
            app.Label_28.Layout.Row = 3;
            app.Label_28.Layout.Column = 2;
            app.Label_28.Text = 'RMS';

            % Create RightStdField
            app.RightStdField = uieditfield(app.GridLayout_13, 'text');
            app.RightStdField.Tag = 'RightStdField';
            app.RightStdField.Editable = 'off';
            app.RightStdField.FontName = 'Microsoft YaHei';
            app.RightStdField.FontSize = 13;
            app.RightStdField.BackgroundColor = [0.97 0.98 0.99];
            app.RightStdField.Layout.Row = 4;
            app.RightStdField.Layout.Column = 1;
            app.RightStdField.Value = '—';

            % Create Label_27
            app.Label_27 = uilabel(app.GridLayout_13);
            app.Label_27.FontName = 'Microsoft YaHei';
            app.Label_27.FontColor = [0.125 0.145 0.204];
            app.Label_27.Layout.Row = 3;
            app.Label_27.Layout.Column = 1;
            app.Label_27.Text = '标准差';

            % Create RightVarianceField
            app.RightVarianceField = uieditfield(app.GridLayout_13, 'text');
            app.RightVarianceField.Tag = 'RightVarianceField';
            app.RightVarianceField.Editable = 'off';
            app.RightVarianceField.FontName = 'Microsoft YaHei';
            app.RightVarianceField.FontSize = 13;
            app.RightVarianceField.BackgroundColor = [0.97 0.98 0.99];
            app.RightVarianceField.Layout.Row = 2;
            app.RightVarianceField.Layout.Column = 2;
            app.RightVarianceField.Value = '—';

            % Create Label_26
            app.Label_26 = uilabel(app.GridLayout_13);
            app.Label_26.FontName = 'Microsoft YaHei';
            app.Label_26.FontColor = [0.125 0.145 0.204];
            app.Label_26.Layout.Row = 1;
            app.Label_26.Layout.Column = 2;
            app.Label_26.Text = '方差';

            % Create RightMeanField
            app.RightMeanField = uieditfield(app.GridLayout_13, 'text');
            app.RightMeanField.Tag = 'RightMeanField';
            app.RightMeanField.Editable = 'off';
            app.RightMeanField.FontName = 'Microsoft YaHei';
            app.RightMeanField.FontSize = 13;
            app.RightMeanField.BackgroundColor = [0.97 0.98 0.99];
            app.RightMeanField.Layout.Row = 2;
            app.RightMeanField.Layout.Column = 1;
            app.RightMeanField.Value = '—';

            % Create Label_25
            app.Label_25 = uilabel(app.GridLayout_13);
            app.Label_25.FontName = 'Microsoft YaHei';
            app.Label_25.FontColor = [0.125 0.145 0.204];
            app.Label_25.Layout.Row = 1;
            app.Label_25.Layout.Column = 1;
            app.Label_25.Text = '均值';

            % Create Panel_11
            app.Panel_11 = uipanel(app.GridLayout_5);
            app.Panel_11.Title = '左声道统计';
            app.Panel_11.BackgroundColor = [1 1 1];
            app.Panel_11.Layout.Row = 3;
            app.Panel_11.Layout.Column = 1;
            app.Panel_11.FontName = 'Microsoft YaHei';
            app.Panel_11.FontWeight = 'bold';
            app.Panel_11.FontSize = 13;

            % Create GridLayout_12
            app.GridLayout_12 = uigridlayout(app.Panel_11);
            app.GridLayout_12.RowHeight = {20, 30, 20, 30};
            app.GridLayout_12.ColumnSpacing = 12;
            app.GridLayout_12.RowSpacing = 6;
            app.GridLayout_12.Padding = [14 10 14 12];
            app.GridLayout_12.BackgroundColor = [1 1 1];

            % Create LeftRMSField
            app.LeftRMSField = uieditfield(app.GridLayout_12, 'text');
            app.LeftRMSField.Tag = 'LeftRMSField';
            app.LeftRMSField.Editable = 'off';
            app.LeftRMSField.FontName = 'Microsoft YaHei';
            app.LeftRMSField.FontSize = 13;
            app.LeftRMSField.BackgroundColor = [0.97 0.98 0.99];
            app.LeftRMSField.Layout.Row = 4;
            app.LeftRMSField.Layout.Column = 2;
            app.LeftRMSField.Value = '—';

            % Create Label_24
            app.Label_24 = uilabel(app.GridLayout_12);
            app.Label_24.FontName = 'Microsoft YaHei';
            app.Label_24.FontColor = [0.125 0.145 0.204];
            app.Label_24.Layout.Row = 3;
            app.Label_24.Layout.Column = 2;
            app.Label_24.Text = 'RMS';

            % Create LeftStdField
            app.LeftStdField = uieditfield(app.GridLayout_12, 'text');
            app.LeftStdField.Tag = 'LeftStdField';
            app.LeftStdField.Editable = 'off';
            app.LeftStdField.FontName = 'Microsoft YaHei';
            app.LeftStdField.FontSize = 13;
            app.LeftStdField.BackgroundColor = [0.97 0.98 0.99];
            app.LeftStdField.Layout.Row = 4;
            app.LeftStdField.Layout.Column = 1;
            app.LeftStdField.Value = '—';

            % Create Label_23
            app.Label_23 = uilabel(app.GridLayout_12);
            app.Label_23.FontName = 'Microsoft YaHei';
            app.Label_23.FontColor = [0.125 0.145 0.204];
            app.Label_23.Layout.Row = 3;
            app.Label_23.Layout.Column = 1;
            app.Label_23.Text = '标准差';

            % Create LeftVarianceField
            app.LeftVarianceField = uieditfield(app.GridLayout_12, 'text');
            app.LeftVarianceField.Tag = 'LeftVarianceField';
            app.LeftVarianceField.Editable = 'off';
            app.LeftVarianceField.FontName = 'Microsoft YaHei';
            app.LeftVarianceField.FontSize = 13;
            app.LeftVarianceField.BackgroundColor = [0.97 0.98 0.99];
            app.LeftVarianceField.Layout.Row = 2;
            app.LeftVarianceField.Layout.Column = 2;
            app.LeftVarianceField.Value = '—';

            % Create Label_22
            app.Label_22 = uilabel(app.GridLayout_12);
            app.Label_22.FontName = 'Microsoft YaHei';
            app.Label_22.FontColor = [0.125 0.145 0.204];
            app.Label_22.Layout.Row = 1;
            app.Label_22.Layout.Column = 2;
            app.Label_22.Text = '方差';

            % Create LeftMeanField
            app.LeftMeanField = uieditfield(app.GridLayout_12, 'text');
            app.LeftMeanField.Tag = 'LeftMeanField';
            app.LeftMeanField.Editable = 'off';
            app.LeftMeanField.FontName = 'Microsoft YaHei';
            app.LeftMeanField.FontSize = 13;
            app.LeftMeanField.BackgroundColor = [0.97 0.98 0.99];
            app.LeftMeanField.Layout.Row = 2;
            app.LeftMeanField.Layout.Column = 1;
            app.LeftMeanField.Value = '—';

            % Create Label_21
            app.Label_21 = uilabel(app.GridLayout_12);
            app.Label_21.FontName = 'Microsoft YaHei';
            app.Label_21.FontColor = [0.125 0.145 0.204];
            app.Label_21.Layout.Row = 1;
            app.Label_21.Layout.Column = 1;
            app.Label_21.Text = '均值';

            % Create Panel_10
            app.Panel_10 = uipanel(app.GridLayout_5);
            app.Panel_10.Title = '右声道 · 概率密度';
            app.Panel_10.BackgroundColor = [1 1 1];
            app.Panel_10.Layout.Row = 2;
            app.Panel_10.Layout.Column = 2;
            app.Panel_10.FontName = 'Microsoft YaHei';
            app.Panel_10.FontWeight = 'bold';
            app.Panel_10.FontSize = 13;

            % Create GridLayout_11
            app.GridLayout_11 = uigridlayout(app.Panel_10);
            app.GridLayout_11.ColumnWidth = {'1x'};
            app.GridLayout_11.RowHeight = {'1x'};
            app.GridLayout_11.Padding = [4 2 4 4];
            app.GridLayout_11.BackgroundColor = [1 1 1];

            % Create RightHistAxes
            app.RightHistAxes = uiaxes(app.GridLayout_11);
            title(app.RightHistAxes, '等待导入')
            app.RightHistAxes.FontName = 'Microsoft YaHei';
            app.RightHistAxes.GridAlpha = 0.1;
            app.RightHistAxes.XGrid = 'on';
            app.RightHistAxes.YGrid = 'on';
            app.RightHistAxes.FontSize = 10;
            app.RightHistAxes.Layout.Row = 1;
            app.RightHistAxes.Layout.Column = 1;
            app.RightHistAxes.Tag = 'RightHistAxes';

            % Create Panel_9
            app.Panel_9 = uipanel(app.GridLayout_5);
            app.Panel_9.Title = '左声道 · 概率密度';
            app.Panel_9.BackgroundColor = [1 1 1];
            app.Panel_9.Layout.Row = 2;
            app.Panel_9.Layout.Column = 1;
            app.Panel_9.FontName = 'Microsoft YaHei';
            app.Panel_9.FontWeight = 'bold';
            app.Panel_9.FontSize = 13;

            % Create GridLayout_10
            app.GridLayout_10 = uigridlayout(app.Panel_9);
            app.GridLayout_10.ColumnWidth = {'1x'};
            app.GridLayout_10.RowHeight = {'1x'};
            app.GridLayout_10.Padding = [4 2 4 4];
            app.GridLayout_10.BackgroundColor = [1 1 1];

            % Create AudioHistAxes
            app.AudioHistAxes = uiaxes(app.GridLayout_10);
            title(app.AudioHistAxes, '等待导入')
            app.AudioHistAxes.FontName = 'Microsoft YaHei';
            app.AudioHistAxes.GridAlpha = 0.1;
            app.AudioHistAxes.XGrid = 'on';
            app.AudioHistAxes.YGrid = 'on';
            app.AudioHistAxes.FontSize = 10;
            app.AudioHistAxes.Layout.Row = 1;
            app.AudioHistAxes.Layout.Column = 1;
            app.AudioHistAxes.Tag = 'AudioHistAxes';

            % Create Panel_8
            app.Panel_8 = uipanel(app.GridLayout_5);
            app.Panel_8.Title = '右声道 · 波形';
            app.Panel_8.BackgroundColor = [1 1 1];
            app.Panel_8.Layout.Row = 1;
            app.Panel_8.Layout.Column = 2;
            app.Panel_8.FontName = 'Microsoft YaHei';
            app.Panel_8.FontWeight = 'bold';
            app.Panel_8.FontSize = 13;

            % Create GridLayout_9
            app.GridLayout_9 = uigridlayout(app.Panel_8);
            app.GridLayout_9.ColumnWidth = {'1x'};
            app.GridLayout_9.RowHeight = {'1x'};
            app.GridLayout_9.Padding = [4 2 4 4];
            app.GridLayout_9.BackgroundColor = [1 1 1];

            % Create RightWaveAxes
            app.RightWaveAxes = uiaxes(app.GridLayout_9);
            title(app.RightWaveAxes, '等待导入')
            app.RightWaveAxes.FontName = 'Microsoft YaHei';
            app.RightWaveAxes.GridAlpha = 0.1;
            app.RightWaveAxes.XGrid = 'on';
            app.RightWaveAxes.YGrid = 'on';
            app.RightWaveAxes.FontSize = 10;
            app.RightWaveAxes.Layout.Row = 1;
            app.RightWaveAxes.Layout.Column = 1;
            app.RightWaveAxes.Tag = 'RightWaveAxes';

            % Create Panel_7
            app.Panel_7 = uipanel(app.GridLayout_5);
            app.Panel_7.Title = '左声道 · 波形';
            app.Panel_7.BackgroundColor = [1 1 1];
            app.Panel_7.Layout.Row = 1;
            app.Panel_7.Layout.Column = 1;
            app.Panel_7.FontName = 'Microsoft YaHei';
            app.Panel_7.FontWeight = 'bold';
            app.Panel_7.FontSize = 13;

            % Create GridLayout_8
            app.GridLayout_8 = uigridlayout(app.Panel_7);
            app.GridLayout_8.ColumnWidth = {'1x'};
            app.GridLayout_8.RowHeight = {'1x'};
            app.GridLayout_8.Padding = [4 2 4 4];
            app.GridLayout_8.BackgroundColor = [1 1 1];

            % Create WaveAxes
            app.WaveAxes = uiaxes(app.GridLayout_8);
            title(app.WaveAxes, '等待导入')
            app.WaveAxes.FontName = 'Microsoft YaHei';
            app.WaveAxes.GridAlpha = 0.1;
            app.WaveAxes.XGrid = 'on';
            app.WaveAxes.YGrid = 'on';
            app.WaveAxes.FontSize = 10;
            app.WaveAxes.Layout.Row = 1;
            app.WaveAxes.Layout.Column = 1;
            app.WaveAxes.Tag = 'WaveAxes';

            % Create Panel_3
            app.Panel_3 = uipanel(app.AudioLayout);
            app.Panel_3.Title = '音频与参数';
            app.Panel_3.BackgroundColor = [1 1 1];
            app.Panel_3.Tag = 'ParameterSection';
            app.Panel_3.Layout.Row = 1;
            app.Panel_3.Layout.Column = 1;
            app.Panel_3.FontName = 'Microsoft YaHei';
            app.Panel_3.FontWeight = 'bold';
            app.Panel_3.FontSize = 13;

            % Create GridLayout_4
            app.GridLayout_4 = uigridlayout(app.Panel_3);
            app.GridLayout_4.ColumnWidth = {106, '1x'};
            app.GridLayout_4.RowHeight = {38, 32, 32, 32, 32, 14, 36, 36, 14, 36, 36, 14, 40, 40, '1x'};
            app.GridLayout_4.ColumnSpacing = 8;
            app.GridLayout_4.RowSpacing = 8;
            app.GridLayout_4.Padding = [16 16 16 16];
            app.GridLayout_4.BackgroundColor = [1 1 1];

            % Create WindowInfoLabel
            app.WindowInfoLabel = uilabel(app.GridLayout_4);
            app.WindowInfoLabel.Tag = 'WindowInfoLabel';
            app.WindowInfoLabel.WordWrap = 'on';
            app.WindowInfoLabel.FontName = 'Microsoft YaHei';
            app.WindowInfoLabel.FontColor = [0.125 0.145 0.204];
            app.WindowInfoLabel.Layout.Row = 14;
            app.WindowInfoLabel.Layout.Column = [1 2];
            app.WindowInfoLabel.Text = '选择音频文件';

            % Create AnalyzeAudioButton
            app.AnalyzeAudioButton = uibutton(app.GridLayout_4, 'push');
            app.AnalyzeAudioButton.ButtonPushedFcn = createCallbackFcn(app, @AnalyzeAudio, true);
            app.AnalyzeAudioButton.Tag = 'AnalyzeAudioButton';
            app.AnalyzeAudioButton.BackgroundColor = [0 0.412 0.851];
            app.AnalyzeAudioButton.FontName = 'Microsoft YaHei';
            app.AnalyzeAudioButton.FontSize = 14;
            app.AnalyzeAudioButton.FontWeight = 'bold';
            app.AnalyzeAudioButton.FontColor = [1 1 1];
            app.AnalyzeAudioButton.Enable = 'off';
            app.AnalyzeAudioButton.Layout.Row = 13;
            app.AnalyzeAudioButton.Layout.Column = [1 2];
            app.AnalyzeAudioButton.Text = '开始分析';

            % Create AudioBinValueField
            app.AudioBinValueField = uieditfield(app.GridLayout_4, 'numeric');
            app.AudioBinValueField.Limits = [1 5000];
            app.AudioBinValueField.RoundFractionalValues = 'on';
            app.AudioBinValueField.ValueDisplayFormat = '%.8g';
            app.AudioBinValueField.ValueChangedFcn = createCallbackFcn(app, @AudioParametersChanged, true);
            app.AudioBinValueField.Tag = 'AudioBinValueField';
            app.AudioBinValueField.FontName = 'Microsoft YaHei';
            app.AudioBinValueField.FontSize = 13;
            app.AudioBinValueField.Enable = 'off';
            app.AudioBinValueField.Layout.Row = 11;
            app.AudioBinValueField.Layout.Column = 2;
            app.AudioBinValueField.Value = 100;

            % Create AudioBinValueLabel
            app.AudioBinValueLabel = uilabel(app.GridLayout_4);
            app.AudioBinValueLabel.Tag = 'AudioBinValueLabel';
            app.AudioBinValueLabel.FontName = 'Microsoft YaHei';
            app.AudioBinValueLabel.FontSize = 13;
            app.AudioBinValueLabel.FontColor = [0.125 0.145 0.204];
            app.AudioBinValueLabel.Layout.Row = 11;
            app.AudioBinValueLabel.Layout.Column = 1;
            app.AudioBinValueLabel.Text = '区间数';

            % Create AudioBinModeDropDown
            app.AudioBinModeDropDown = uidropdown(app.GridLayout_4);
            app.AudioBinModeDropDown.Items = {'区间数', '区间宽度'};
            app.AudioBinModeDropDown.ValueChangedFcn = createCallbackFcn(app, @AudioBinModeChanged, true);
            app.AudioBinModeDropDown.Tag = 'AudioBinModeDropDown';
            app.AudioBinModeDropDown.Enable = 'off';
            app.AudioBinModeDropDown.FontName = 'Microsoft YaHei';
            app.AudioBinModeDropDown.FontSize = 13;
            app.AudioBinModeDropDown.Layout.Row = 10;
            app.AudioBinModeDropDown.Layout.Column = 2;
            app.AudioBinModeDropDown.Value = '区间数';

            % Create Label_12
            app.Label_12 = uilabel(app.GridLayout_4);
            app.Label_12.FontName = 'Microsoft YaHei';
            app.Label_12.FontSize = 13;
            app.Label_12.FontColor = [0.125 0.145 0.204];
            app.Label_12.Layout.Row = 10;
            app.Label_12.Layout.Column = 1;
            app.Label_12.Text = '分箱方式';

            % Create EndTimeField
            app.EndTimeField = uieditfield(app.GridLayout_4, 'numeric');
            app.EndTimeField.Limits = [0 Inf];
            app.EndTimeField.ValueDisplayFormat = '%.8g';
            app.EndTimeField.ValueChangedFcn = createCallbackFcn(app, @AudioParametersChanged, true);
            app.EndTimeField.Tag = 'EndTimeField';
            app.EndTimeField.FontName = 'Microsoft YaHei';
            app.EndTimeField.FontSize = 13;
            app.EndTimeField.Enable = 'off';
            app.EndTimeField.Layout.Row = 8;
            app.EndTimeField.Layout.Column = 2;
            app.EndTimeField.Value = 1;

            % Create Label_11
            app.Label_11 = uilabel(app.GridLayout_4);
            app.Label_11.FontName = 'Microsoft YaHei';
            app.Label_11.FontSize = 13;
            app.Label_11.FontColor = [0.125 0.145 0.204];
            app.Label_11.Layout.Row = 8;
            app.Label_11.Layout.Column = 1;
            app.Label_11.Text = '结束时间 / s';

            % Create StartTimeField
            app.StartTimeField = uieditfield(app.GridLayout_4, 'numeric');
            app.StartTimeField.Limits = [0 Inf];
            app.StartTimeField.ValueDisplayFormat = '%.8g';
            app.StartTimeField.ValueChangedFcn = createCallbackFcn(app, @AudioParametersChanged, true);
            app.StartTimeField.Tag = 'StartTimeField';
            app.StartTimeField.FontName = 'Microsoft YaHei';
            app.StartTimeField.FontSize = 13;
            app.StartTimeField.Enable = 'off';
            app.StartTimeField.Layout.Row = 7;
            app.StartTimeField.Layout.Column = 2;

            % Create Label_10
            app.Label_10 = uilabel(app.GridLayout_4);
            app.Label_10.FontName = 'Microsoft YaHei';
            app.Label_10.FontSize = 13;
            app.Label_10.FontColor = [0.125 0.145 0.204];
            app.Label_10.Layout.Row = 7;
            app.Label_10.Layout.Column = 1;
            app.Label_10.Text = '起始时间 / s';

            % Create DurationField
            app.DurationField = uieditfield(app.GridLayout_4, 'text');
            app.DurationField.Tag = 'DurationField';
            app.DurationField.Editable = 'off';
            app.DurationField.FontName = 'Microsoft YaHei';
            app.DurationField.FontSize = 13;
            app.DurationField.BackgroundColor = [0.97 0.98 0.99];
            app.DurationField.Layout.Row = 5;
            app.DurationField.Layout.Column = 2;
            app.DurationField.Value = '—';

            % Create Label_9
            app.Label_9 = uilabel(app.GridLayout_4);
            app.Label_9.FontName = 'Microsoft YaHei';
            app.Label_9.FontSize = 13;
            app.Label_9.FontColor = [0.125 0.145 0.204];
            app.Label_9.Layout.Row = 5;
            app.Label_9.Layout.Column = 1;
            app.Label_9.Text = '时长 / s';

            % Create ChannelCountField
            app.ChannelCountField = uieditfield(app.GridLayout_4, 'text');
            app.ChannelCountField.Tag = 'ChannelCountField';
            app.ChannelCountField.Editable = 'off';
            app.ChannelCountField.FontName = 'Microsoft YaHei';
            app.ChannelCountField.FontSize = 13;
            app.ChannelCountField.BackgroundColor = [0.97 0.98 0.99];
            app.ChannelCountField.Layout.Row = 4;
            app.ChannelCountField.Layout.Column = 2;
            app.ChannelCountField.Value = '—';

            % Create Label_8
            app.Label_8 = uilabel(app.GridLayout_4);
            app.Label_8.FontName = 'Microsoft YaHei';
            app.Label_8.FontSize = 13;
            app.Label_8.FontColor = [0.125 0.145 0.204];
            app.Label_8.Layout.Row = 4;
            app.Label_8.Layout.Column = 1;
            app.Label_8.Text = '文件声道数';

            % Create SampleRateField
            app.SampleRateField = uieditfield(app.GridLayout_4, 'text');
            app.SampleRateField.Tag = 'SampleRateField';
            app.SampleRateField.Editable = 'off';
            app.SampleRateField.FontName = 'Microsoft YaHei';
            app.SampleRateField.FontSize = 13;
            app.SampleRateField.BackgroundColor = [0.97 0.98 0.99];
            app.SampleRateField.Layout.Row = 3;
            app.SampleRateField.Layout.Column = 2;
            app.SampleRateField.Value = '—';

            % Create Label_7
            app.Label_7 = uilabel(app.GridLayout_4);
            app.Label_7.FontName = 'Microsoft YaHei';
            app.Label_7.FontSize = 13;
            app.Label_7.FontColor = [0.125 0.145 0.204];
            app.Label_7.Layout.Row = 3;
            app.Label_7.Layout.Column = 1;
            app.Label_7.Text = '采样率 / Hz';

            % Create AudioFileField
            app.AudioFileField = uieditfield(app.GridLayout_4, 'text');
            app.AudioFileField.Tag = 'AudioFileField';
            app.AudioFileField.Editable = 'off';
            app.AudioFileField.FontName = 'Microsoft YaHei';
            app.AudioFileField.FontSize = 13;
            app.AudioFileField.BackgroundColor = [0.97 0.98 0.99];
            app.AudioFileField.Layout.Row = 2;
            app.AudioFileField.Layout.Column = [1 2];
            app.AudioFileField.Value = '尚未导入';

            % Create LoadAudioButton
            app.LoadAudioButton = uibutton(app.GridLayout_4, 'push');
            app.LoadAudioButton.ButtonPushedFcn = createCallbackFcn(app, @ImportAudio, true);
            app.LoadAudioButton.Tag = 'LoadAudioButton';
            app.LoadAudioButton.FontName = 'Microsoft YaHei';
            app.LoadAudioButton.FontSize = 13;
            app.LoadAudioButton.Layout.Row = 1;
            app.LoadAudioButton.Layout.Column = [1 2];
            app.LoadAudioButton.Text = '导入音频';

            % Create SimPage
            app.SimPage = uipanel(app.WorkspaceGrid);
            app.SimPage.BorderType = 'none';
            app.SimPage.BackgroundColor = [0.949 0.957 0.973];
            app.SimPage.Tag = 'SimPage';
            app.SimPage.Layout.Row = 1;
            app.SimPage.Layout.Column = 1;

            % Create SimLayout
            app.SimLayout = uigridlayout(app.SimPage);
            app.SimLayout.ColumnWidth = {256, '1x'};
            app.SimLayout.RowHeight = {'1x'};
            app.SimLayout.ColumnSpacing = 16;
            app.SimLayout.RowSpacing = 16;
            app.SimLayout.Padding = [0 0 0 0];
            app.SimLayout.Tag = 'SimLayout';
            app.SimLayout.Scrollable = 'on';
            app.SimLayout.BackgroundColor = [0.949 0.957 0.973];

            % Create Panel_2
            app.Panel_2 = uipanel(app.SimLayout);
            app.Panel_2.BorderType = 'none';
            app.Panel_2.BackgroundColor = [1 1 1];
            app.Panel_2.Tag = 'ResultSection';
            app.Panel_2.Layout.Row = 1;
            app.Panel_2.Layout.Column = 2;
            app.Panel_2.FontName = 'Microsoft YaHei';
            app.Panel_2.FontWeight = 'bold';
            app.Panel_2.FontSize = 13;

            % Create GridLayout_3
            app.GridLayout_3 = uigridlayout(app.Panel_2);
            app.GridLayout_3.ColumnWidth = {'1x'};
            app.GridLayout_3.RowHeight = {'1x', 206};
            app.GridLayout_3.RowSpacing = 14;
            app.GridLayout_3.Padding = [0 0 0 0];
            app.GridLayout_3.BackgroundColor = [0.949 0.957 0.973];

            % Create Panel_6
            app.Panel_6 = uipanel(app.GridLayout_3);
            app.Panel_6.Title = '统计对比';
            app.Panel_6.BackgroundColor = [1 1 1];
            app.Panel_6.Layout.Row = 2;
            app.Panel_6.Layout.Column = 1;
            app.Panel_6.FontName = 'Microsoft YaHei';
            app.Panel_6.FontWeight = 'bold';
            app.Panel_6.FontSize = 13;

            % Create GridLayout_7
            app.GridLayout_7 = uigridlayout(app.Panel_6);
            app.GridLayout_7.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.GridLayout_7.RowHeight = {20, 30, 20, 30};
            app.GridLayout_7.ColumnSpacing = 12;
            app.GridLayout_7.RowSpacing = 6;
            app.GridLayout_7.Padding = [14 10 14 12];
            app.GridLayout_7.BackgroundColor = [1 1 1];

            % Create SimWidthField
            app.SimWidthField = uieditfield(app.GridLayout_7, 'text');
            app.SimWidthField.Tag = 'SimWidthField';
            app.SimWidthField.Editable = 'off';
            app.SimWidthField.FontName = 'Microsoft YaHei';
            app.SimWidthField.FontSize = 13;
            app.SimWidthField.BackgroundColor = [0.97 0.98 0.99];
            app.SimWidthField.Layout.Row = 4;
            app.SimWidthField.Layout.Column = 4;
            app.SimWidthField.Value = '—';

            % Create Label_20
            app.Label_20 = uilabel(app.GridLayout_7);
            app.Label_20.FontName = 'Microsoft YaHei';
            app.Label_20.FontColor = [0.125 0.145 0.204];
            app.Label_20.Layout.Row = 3;
            app.Label_20.Layout.Column = 4;
            app.Label_20.Text = '实际宽度 Δ';

            % Create TheoryStdField
            app.TheoryStdField = uieditfield(app.GridLayout_7, 'text');
            app.TheoryStdField.Tag = 'TheoryStdField';
            app.TheoryStdField.Editable = 'off';
            app.TheoryStdField.FontName = 'Microsoft YaHei';
            app.TheoryStdField.FontSize = 13;
            app.TheoryStdField.BackgroundColor = [0.97 0.98 0.99];
            app.TheoryStdField.Layout.Row = 4;
            app.TheoryStdField.Layout.Column = 3;
            app.TheoryStdField.Value = '—';

            % Create Label_19
            app.Label_19 = uilabel(app.GridLayout_7);
            app.Label_19.FontName = 'Microsoft YaHei';
            app.Label_19.FontColor = [0.125 0.145 0.204];
            app.Label_19.Layout.Row = 3;
            app.Label_19.Layout.Column = 3;
            app.Label_19.Text = '理论标准差';

            % Create TheoryVarianceField
            app.TheoryVarianceField = uieditfield(app.GridLayout_7, 'text');
            app.TheoryVarianceField.Tag = 'TheoryVarianceField';
            app.TheoryVarianceField.Editable = 'off';
            app.TheoryVarianceField.FontName = 'Microsoft YaHei';
            app.TheoryVarianceField.FontSize = 13;
            app.TheoryVarianceField.BackgroundColor = [0.97 0.98 0.99];
            app.TheoryVarianceField.Layout.Row = 4;
            app.TheoryVarianceField.Layout.Column = 2;
            app.TheoryVarianceField.Value = '—';

            % Create Label_18
            app.Label_18 = uilabel(app.GridLayout_7);
            app.Label_18.FontName = 'Microsoft YaHei';
            app.Label_18.FontColor = [0.125 0.145 0.204];
            app.Label_18.Layout.Row = 3;
            app.Label_18.Layout.Column = 2;
            app.Label_18.Text = '理论方差';

            % Create TheoryMeanField
            app.TheoryMeanField = uieditfield(app.GridLayout_7, 'text');
            app.TheoryMeanField.Tag = 'TheoryMeanField';
            app.TheoryMeanField.Editable = 'off';
            app.TheoryMeanField.FontName = 'Microsoft YaHei';
            app.TheoryMeanField.FontSize = 13;
            app.TheoryMeanField.BackgroundColor = [0.97 0.98 0.99];
            app.TheoryMeanField.Layout.Row = 4;
            app.TheoryMeanField.Layout.Column = 1;
            app.TheoryMeanField.Value = '—';

            % Create Label_17
            app.Label_17 = uilabel(app.GridLayout_7);
            app.Label_17.FontName = 'Microsoft YaHei';
            app.Label_17.FontColor = [0.125 0.145 0.204];
            app.Label_17.Layout.Row = 3;
            app.Label_17.Layout.Column = 1;
            app.Label_17.Text = '理论均值';

            % Create SimCountField
            app.SimCountField = uieditfield(app.GridLayout_7, 'text');
            app.SimCountField.Tag = 'SimCountField';
            app.SimCountField.Editable = 'off';
            app.SimCountField.FontName = 'Microsoft YaHei';
            app.SimCountField.FontSize = 13;
            app.SimCountField.BackgroundColor = [0.97 0.98 0.99];
            app.SimCountField.Layout.Row = 2;
            app.SimCountField.Layout.Column = 4;
            app.SimCountField.Value = '—';

            % Create Label_16
            app.Label_16 = uilabel(app.GridLayout_7);
            app.Label_16.FontName = 'Microsoft YaHei';
            app.Label_16.FontColor = [0.125 0.145 0.204];
            app.Label_16.Layout.Row = 1;
            app.Label_16.Layout.Column = 4;
            app.Label_16.Text = '样本数 N';

            % Create SimStdField
            app.SimStdField = uieditfield(app.GridLayout_7, 'text');
            app.SimStdField.Tag = 'SimStdField';
            app.SimStdField.Editable = 'off';
            app.SimStdField.FontName = 'Microsoft YaHei';
            app.SimStdField.FontSize = 13;
            app.SimStdField.BackgroundColor = [0.97 0.98 0.99];
            app.SimStdField.Layout.Row = 2;
            app.SimStdField.Layout.Column = 3;
            app.SimStdField.Value = '—';

            % Create Label_15
            app.Label_15 = uilabel(app.GridLayout_7);
            app.Label_15.FontName = 'Microsoft YaHei';
            app.Label_15.FontColor = [0.125 0.145 0.204];
            app.Label_15.Layout.Row = 1;
            app.Label_15.Layout.Column = 3;
            app.Label_15.Text = '样本标准差';

            % Create SimVarianceField
            app.SimVarianceField = uieditfield(app.GridLayout_7, 'text');
            app.SimVarianceField.Tag = 'SimVarianceField';
            app.SimVarianceField.Editable = 'off';
            app.SimVarianceField.FontName = 'Microsoft YaHei';
            app.SimVarianceField.FontSize = 13;
            app.SimVarianceField.BackgroundColor = [0.97 0.98 0.99];
            app.SimVarianceField.Layout.Row = 2;
            app.SimVarianceField.Layout.Column = 2;
            app.SimVarianceField.Value = '—';

            % Create Label_14
            app.Label_14 = uilabel(app.GridLayout_7);
            app.Label_14.FontName = 'Microsoft YaHei';
            app.Label_14.FontColor = [0.125 0.145 0.204];
            app.Label_14.Layout.Row = 1;
            app.Label_14.Layout.Column = 2;
            app.Label_14.Text = '样本方差';

            % Create SimMeanField
            app.SimMeanField = uieditfield(app.GridLayout_7, 'text');
            app.SimMeanField.Tag = 'SimMeanField';
            app.SimMeanField.Editable = 'off';
            app.SimMeanField.FontName = 'Microsoft YaHei';
            app.SimMeanField.FontSize = 13;
            app.SimMeanField.BackgroundColor = [0.97 0.98 0.99];
            app.SimMeanField.Layout.Row = 2;
            app.SimMeanField.Layout.Column = 1;
            app.SimMeanField.Value = '—';

            % Create Label_13
            app.Label_13 = uilabel(app.GridLayout_7);
            app.Label_13.FontName = 'Microsoft YaHei';
            app.Label_13.FontColor = [0.125 0.145 0.204];
            app.Label_13.Layout.Row = 1;
            app.Label_13.Layout.Column = 1;
            app.Label_13.Text = '样本均值';

            % Create Panel_5
            app.Panel_5 = uipanel(app.GridLayout_3);
            app.Panel_5.Title = '概率密度与高斯拟合';
            app.Panel_5.BackgroundColor = [1 1 1];
            app.Panel_5.Layout.Row = 1;
            app.Panel_5.Layout.Column = 1;
            app.Panel_5.FontName = 'Microsoft YaHei';
            app.Panel_5.FontWeight = 'bold';
            app.Panel_5.FontSize = 13;

            % Create GridLayout_6
            app.GridLayout_6 = uigridlayout(app.Panel_5);
            app.GridLayout_6.ColumnWidth = {'1x'};
            app.GridLayout_6.RowHeight = {'1x'};
            app.GridLayout_6.Padding = [10 8 10 10];
            app.GridLayout_6.BackgroundColor = [1 1 1];

            % Create SimAxes
            app.SimAxes = uiaxes(app.GridLayout_6);
            title(app.SimAxes, '设置参数，开始仿真')
            app.SimAxes.FontName = 'Microsoft YaHei';
            app.SimAxes.GridAlpha = 0.1;
            app.SimAxes.XGrid = 'on';
            app.SimAxes.YGrid = 'on';
            app.SimAxes.FontSize = 10;
            app.SimAxes.Layout.Row = 1;
            app.SimAxes.Layout.Column = 1;
            app.SimAxes.Tag = 'SimAxes';

            % Create Panel
            app.Panel = uipanel(app.SimLayout);
            app.Panel.Title = '实验参数';
            app.Panel.BackgroundColor = [1 1 1];
            app.Panel.Tag = 'ParameterSection';
            app.Panel.Layout.Row = 1;
            app.Panel.Layout.Column = 1;
            app.Panel.FontName = 'Microsoft YaHei';
            app.Panel.FontWeight = 'bold';
            app.Panel.FontSize = 13;

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.Panel);
            app.GridLayout_2.ColumnWidth = {106, '1x'};
            app.GridLayout_2.RowHeight = {36, 36, 14, 36, 36, 16, 42, 46, '1x'};
            app.GridLayout_2.ColumnSpacing = 8;
            app.GridLayout_2.RowSpacing = 8;
            app.GridLayout_2.Padding = [16 16 16 16];
            app.GridLayout_2.BackgroundColor = [1 1 1];

            % Create Label_6
            app.Label_6 = uilabel(app.GridLayout_2);
            app.Label_6.FontName = 'Microsoft YaHei';
            app.Label_6.FontColor = [0.125 0.145 0.204];
            app.Label_6.Tooltip = '同时显示经验密度、样本参数高斯拟合、理论参数高斯近似；小 m 时高斯近似可能不理想';
            app.Label_6.Layout.Row = 8;
            app.Label_6.Layout.Column = [1 2];
            app.Label_6.Text = '独立均匀变量 U(0,1)';

            % Create RunSimButton
            app.RunSimButton = uibutton(app.GridLayout_2, 'push');
            app.RunSimButton.ButtonPushedFcn = createCallbackFcn(app, @RunSimulation, true);
            app.RunSimButton.Tag = 'RunSimButton';
            app.RunSimButton.BackgroundColor = [0 0.412 0.851];
            app.RunSimButton.FontName = 'Microsoft YaHei';
            app.RunSimButton.FontSize = 14;
            app.RunSimButton.FontWeight = 'bold';
            app.RunSimButton.FontColor = [1 1 1];
            app.RunSimButton.Layout.Row = 7;
            app.RunSimButton.Layout.Column = [1 2];
            app.RunSimButton.Text = '开始仿真';

            % Create SimBinValueField
            app.SimBinValueField = uieditfield(app.GridLayout_2, 'numeric');
            app.SimBinValueField.Limits = [1 5000];
            app.SimBinValueField.RoundFractionalValues = 'on';
            app.SimBinValueField.ValueDisplayFormat = '%.8g';
            app.SimBinValueField.ValueChangedFcn = createCallbackFcn(app, @SimulationParametersChanged, true);
            app.SimBinValueField.Tag = 'SimBinValueField';
            app.SimBinValueField.FontName = 'Microsoft YaHei';
            app.SimBinValueField.FontSize = 13;
            app.SimBinValueField.Layout.Row = 5;
            app.SimBinValueField.Layout.Column = 2;
            app.SimBinValueField.Value = 60;

            % Create SimBinValueLabel
            app.SimBinValueLabel = uilabel(app.GridLayout_2);
            app.SimBinValueLabel.Tag = 'SimBinValueLabel';
            app.SimBinValueLabel.FontName = 'Microsoft YaHei';
            app.SimBinValueLabel.FontSize = 13;
            app.SimBinValueLabel.FontColor = [0.125 0.145 0.204];
            app.SimBinValueLabel.Layout.Row = 5;
            app.SimBinValueLabel.Layout.Column = 1;
            app.SimBinValueLabel.Text = '区间数';

            % Create SimBinModeDropDown
            app.SimBinModeDropDown = uidropdown(app.GridLayout_2);
            app.SimBinModeDropDown.Items = {'区间数', '区间宽度'};
            app.SimBinModeDropDown.ValueChangedFcn = createCallbackFcn(app, @SimulationBinModeChanged, true);
            app.SimBinModeDropDown.Tag = 'SimBinModeDropDown';
            app.SimBinModeDropDown.FontName = 'Microsoft YaHei';
            app.SimBinModeDropDown.FontSize = 13;
            app.SimBinModeDropDown.Layout.Row = 4;
            app.SimBinModeDropDown.Layout.Column = 2;
            app.SimBinModeDropDown.Value = '区间数';

            % Create Label_5
            app.Label_5 = uilabel(app.GridLayout_2);
            app.Label_5.FontName = 'Microsoft YaHei';
            app.Label_5.FontSize = 13;
            app.Label_5.FontColor = [0.125 0.145 0.204];
            app.Label_5.Layout.Row = 4;
            app.Label_5.Layout.Column = 1;
            app.Label_5.Text = '分箱方式';

            % Create TrialsEditField
            app.TrialsEditField = uieditfield(app.GridLayout_2, 'numeric');
            app.TrialsEditField.Limits = [1 Inf];
            app.TrialsEditField.RoundFractionalValues = 'on';
            app.TrialsEditField.ValueDisplayFormat = '%.8g';
            app.TrialsEditField.ValueChangedFcn = createCallbackFcn(app, @SimulationParametersChanged, true);
            app.TrialsEditField.Tag = 'TrialsEditField';
            app.TrialsEditField.FontName = 'Microsoft YaHei';
            app.TrialsEditField.FontSize = 13;
            app.TrialsEditField.Tooltip = '重复试验次数；m × N 最大为 1e8';
            app.TrialsEditField.Layout.Row = 2;
            app.TrialsEditField.Layout.Column = 2;
            app.TrialsEditField.Value = 10000;

            % Create Label_4
            app.Label_4 = uilabel(app.GridLayout_2);
            app.Label_4.FontName = 'Microsoft YaHei';
            app.Label_4.FontSize = 13;
            app.Label_4.FontColor = [0.125 0.145 0.204];
            app.Label_4.Layout.Row = 2;
            app.Label_4.Layout.Column = 1;
            app.Label_4.Text = '样本数 N';

            % Create TermsEditField
            app.TermsEditField = uieditfield(app.GridLayout_2, 'numeric');
            app.TermsEditField.Limits = [1 Inf];
            app.TermsEditField.RoundFractionalValues = 'on';
            app.TermsEditField.ValueDisplayFormat = '%.8g';
            app.TermsEditField.ValueChangedFcn = createCallbackFcn(app, @SimulationParametersChanged, true);
            app.TermsEditField.Tag = 'TermsEditField';
            app.TermsEditField.FontName = 'Microsoft YaHei';
            app.TermsEditField.FontSize = 13;
            app.TermsEditField.Tooltip = '每次试验独立抽取 m 个 U(0,1) 随机数并相加';
            app.TermsEditField.Layout.Row = 1;
            app.TermsEditField.Layout.Column = 2;
            app.TermsEditField.Value = 100;

            % Create Label_3
            app.Label_3 = uilabel(app.GridLayout_2);
            app.Label_3.FontName = 'Microsoft YaHei';
            app.Label_3.FontSize = 13;
            app.Label_3.FontColor = [0.125 0.145 0.204];
            app.Label_3.Layout.Row = 1;
            app.Label_3.Layout.Column = 1;
            app.Label_3.Text = '求和个数 m';

            % Create HeaderGrid
            app.HeaderGrid = uigridlayout(app.ContentGrid);
            app.HeaderGrid.ColumnWidth = {'1x', 70, 112, 112};
            app.HeaderGrid.RowHeight = {'1x'};
            app.HeaderGrid.Padding = [0 8 0 8];
            app.HeaderGrid.Tag = 'HeaderGrid';
            app.HeaderGrid.Layout.Row = 1;
            app.HeaderGrid.Layout.Column = 1;
            app.HeaderGrid.BackgroundColor = [0.949 0.957 0.973];

            % Create SaveFigureButton
            app.SaveFigureButton = uibutton(app.HeaderGrid, 'push');
            app.SaveFigureButton.ButtonPushedFcn = createCallbackFcn(app, @SaveFigure, true);
            app.SaveFigureButton.Tag = 'SaveFigureButton';
            app.SaveFigureButton.FontName = 'Microsoft YaHei';
            app.SaveFigureButton.FontSize = 13;
            app.SaveFigureButton.Enable = 'off';
            app.SaveFigureButton.Layout.Row = 1;
            app.SaveFigureButton.Layout.Column = 4;
            app.SaveFigureButton.Text = '导出图像';

            % Create SaveDataButton
            app.SaveDataButton = uibutton(app.HeaderGrid, 'push');
            app.SaveDataButton.ButtonPushedFcn = createCallbackFcn(app, @SaveData, true);
            app.SaveDataButton.Tag = 'SaveDataButton';
            app.SaveDataButton.FontName = 'Microsoft YaHei';
            app.SaveDataButton.FontSize = 13;
            app.SaveDataButton.Enable = 'off';
            app.SaveDataButton.Layout.Row = 1;
            app.SaveDataButton.Layout.Column = 3;
            app.SaveDataButton.Text = '保存数据';

            % Create StateLabel
            app.StateLabel = uilabel(app.HeaderGrid);
            app.StateLabel.Tag = 'StateLabel';
            app.StateLabel.HorizontalAlignment = 'center';
            app.StateLabel.FontName = 'Microsoft YaHei';
            app.StateLabel.FontSize = 13;
            app.StateLabel.FontColor = [0.31 0.35 0.43];
            app.StateLabel.Layout.Row = 1;
            app.StateLabel.Layout.Column = 2;
            app.StateLabel.Text = '就绪';

            % Create PageTitle
            app.PageTitle = uilabel(app.HeaderGrid);
            app.PageTitle.Tag = 'PageTitle';
            app.PageTitle.FontName = 'Microsoft YaHei';
            app.PageTitle.FontSize = 24;
            app.PageTitle.FontWeight = 'bold';
            app.PageTitle.FontColor = [0.125 0.145 0.204];
            app.PageTitle.Layout.Row = 1;
            app.PageTitle.Layout.Column = 1;
            app.PageTitle.Text = '随机数仿真';

            % Create Sidebar
            app.Sidebar = uipanel(app.ShellGrid);
            app.Sidebar.BorderType = 'none';
            app.Sidebar.BackgroundColor = [0.133 0.173 0.239];
            app.Sidebar.Tag = 'Sidebar';
            app.Sidebar.Layout.Row = 1;
            app.Sidebar.Layout.Column = 1;

            % Create GridLayout
            app.GridLayout = uigridlayout(app.Sidebar);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {54, 44, 44, '1x', 24};
            app.GridLayout.Padding = [14 16 14 20];
            app.GridLayout.BackgroundColor = [0.133 0.173 0.239];

            % Create Label_2
            app.Label_2 = uilabel(app.GridLayout);
            app.Label_2.FontName = 'Microsoft YaHei';
            app.Label_2.FontSize = 11;
            app.Label_2.FontColor = [0.73 0.79 0.88];
            app.Label_2.Layout.Row = 5;
            app.Label_2.Layout.Column = 1;
            app.Label_2.Text = '概率与统计 · 实验一';

            % Create NavigationAudio
            app.NavigationAudio = uibutton(app.GridLayout, 'push');
            app.NavigationAudio.ButtonPushedFcn = createCallbackFcn(app, @ShowAudio, true);
            app.NavigationAudio.Tag = 'NavigationAudio';
            app.NavigationAudio.BackgroundColor = [0.133 0.173 0.239];
            app.NavigationAudio.FontName = 'Microsoft YaHei';
            app.NavigationAudio.FontSize = 14;
            app.NavigationAudio.FontColor = [1 1 1];
            app.NavigationAudio.Layout.Row = 3;
            app.NavigationAudio.Layout.Column = 1;
            app.NavigationAudio.Text = '音频分析';

            % Create NavigationSimulation
            app.NavigationSimulation = uibutton(app.GridLayout, 'push');
            app.NavigationSimulation.ButtonPushedFcn = createCallbackFcn(app, @ShowSimulation, true);
            app.NavigationSimulation.Tag = 'NavigationSimulation';
            app.NavigationSimulation.BackgroundColor = [0.18 0.32 0.5];
            app.NavigationSimulation.FontName = 'Microsoft YaHei';
            app.NavigationSimulation.FontSize = 14;
            app.NavigationSimulation.FontColor = [1 1 1];
            app.NavigationSimulation.Layout.Row = 2;
            app.NavigationSimulation.Layout.Column = 1;
            app.NavigationSimulation.Text = '随机数仿真';

            % Create Label
            app.Label = uilabel(app.GridLayout);
            app.Label.FontName = 'Microsoft YaHei';
            app.Label.FontSize = 20;
            app.Label.FontWeight = 'bold';
            app.Label.FontColor = [1 1 1];
            app.Label.Layout.Row = 1;
            app.Label.Layout.Column = 1;
            app.Label.Text = '统计实验室';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = StatisticsExperimentApp

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