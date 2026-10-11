classdef MatlabExperimentHub < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        GridLayout         matlab.ui.container.GridLayout
        Panel              matlab.ui.container.Panel
        GridLayout_1       matlab.ui.container.GridLayout
        Label              matlab.ui.control.Label
        Label_1            matlab.ui.control.Label
        SelectExperiment1  matlab.ui.control.Button
        SelectExperiment2  matlab.ui.control.Button
        SelectExperiment3  matlab.ui.control.Button
        SelectExperiment4  matlab.ui.control.Button
        Label_2            matlab.ui.control.Label
        Button             matlab.ui.control.Button
        MainGrid           matlab.ui.container.GridLayout
        Heading            matlab.ui.control.Label
        Scope              matlab.ui.control.Label
        DetailPanel        matlab.ui.container.Panel
        GridLayout_2       matlab.ui.container.GridLayout
        Label_3            matlab.ui.control.Label
        Label_4            matlab.ui.control.Label
        Label_5            matlab.ui.control.Label
        Label_6            matlab.ui.control.Label
        Label_7            matlab.ui.control.Label
        Label_8            matlab.ui.control.Label
        Label_9            matlab.ui.control.Label
        Label_10           matlab.ui.control.Label
        GridLayout_3       matlab.ui.container.GridLayout
        OpenButton         matlab.ui.control.Button
        Button_1           matlab.ui.control.Button
        Label_11           matlab.ui.control.Label
        StateLabel         matlab.ui.control.Label
    end

    properties (SetAccess = private)
        SelectedExperiment = 1
    end

    properties (Access = private)
        Children = cell(1,4)
        Navigation = cell(1,4)
        Capabilities
        Busy = false
        Names = {'实验一 · 统计仿真', '实验二 · 数值求根', ...
            '实验三 · 阵列指向性', '实验四 · 系统稳定性'}
        Accent = [0.12 0.33 0.67]
        Text = [0.12 0.17 0.25]
    end

    methods


        function selectExperiment(app, number)
            validateattributes(number, {'numeric'}, ...
                {'scalar','integer','>=',1,'<=',4});
            app.SelectedExperiment = number;
            for k = 1:4
                selected = k == number;
                app.Navigation{k}.BackgroundColor = ...
                    app.choose(selected, [0.88 0.93 1], [0.96 0.97 0.99]);
                app.Navigation{k}.FontColor = ...
                    app.choose(selected, app.Accent, app.Text);
                app.Navigation{k}.FontWeight = app.choose(selected, 'bold', 'normal');
            end
            scopes = {'统计仿真与音频分析', '实验内容 1 · 牛顿法与二分法', ...
                '实验内容 1 · 均匀线列阵', '全部内容 · 离散与连续系统'};
            details = {
                {'随机仿真','均匀随机变量求和、概率密度、高斯拟合'; ...
                 '音频分析','声道波形、时间窗、均值与方差'; ...
                 '参数','求和项数、重复次数、分箱方式、音频区间'; ...
                 '保存','MAT / CSV 数据、PNG / PDF 图形'}, ...
                {'求根算法','牛顿法、二分法、roots 验证'; ...
                 '计算过程','迭代轨迹、残差、停止原因'; ...
                 '参数','多项式、初值、区间、精度、最大迭代次数'; ...
                 '保存','数据与结果图'}, ...
                {'方向图','直角坐标、极坐标'; ...
                 '幅度','原始幅度、归一化幅度、相对 dB'; ...
                 '参数','阵元数、间距、波长、扫描角与角度采样'; ...
                 '保存','数据与结果图'}, ...
                {'系统分析','零极点、因果系统稳定性'; ...
                 '响应','幅频响应、单位脉冲 / 单位冲激响应'; ...
                 '参数','系统系数、频率范围、时域范围、判定容差'; ...
                 '符号计算','逆 Z / 逆 Laplace 变换、数值结果核验'}};
            app.Heading.Text = app.Names{number};
            app.Scope.Text = scopes{number};
            rows = details{number};
            for row = 1:4
                for column = 1:2
                    app.Capabilities{row,column}.Text = rows{row,column};
                end
            end
            app.OpenButton.Text = '打开实验';
            if app.childIsOpen(number)
                app.OpenButton.Text = '返回已打开的实验';
                app.setStatus('实验窗口已打开', [0.12 0.42 0.29]);
            else
                app.setStatus('就绪', app.Text);
            end
        end

        function child = openExperiment(app, number)
            if nargin < 2, number = app.SelectedExperiment; end
            app.selectExperiment(number);
            if app.Busy
                error('ExperimentHub:Busy', '正在打开实验，请稍候。');
            end
            if app.childIsOpen(number)
                child = app.Children{number};
                child.UIFigure.Visible = 'on';
                figure(child.UIFigure);
                return
            end
            app.Busy = true;
            app.OpenButton.Enable = 'off';
            cleanup = onCleanup(@() app.finishOpening());
            app.setStatus('正在打开实验…', app.Accent);
            drawnow;
            try
                child = launch_experiment(number);
                app.Children{number} = child;
                app.OpenButton.Text = '返回已打开的实验';
                app.setStatus('实验窗口已打开', [0.12 0.42 0.29]);
            catch exception
                app.setStatus(['打开失败：' exception.message], [0.72 0.17 0.17]);
                rethrow(exception);
            end
        end


    end

    methods (Access = private)


        function openSelected(app)
            try
                app.openExperiment();
            catch
                % openExperiment 已在当前界面显示详细错误，保留窗口以便重试。
            end
        end

        function tf = childIsOpen(app, k)
            child = app.Children{k};
            tf = ~isempty(child) && isvalid(child) && ...
                ~isempty(child.UIFigure) && isgraphics(child.UIFigure);
        end

        function finishOpening(app)
            if isvalid(app) && isgraphics(app.UIFigure)
                app.Busy = false;
                app.OpenButton.Enable = 'on';
            end
        end

        function requestClose(app)
            if app.Busy
                app.setStatus('正在打开实验，请完成后再关闭。', app.Accent);
                return
            end
            delete(app);
        end

        function setStatus(app, message, color)
            app.StateLabel.Text = message;
            app.StateLabel.Tooltip = message;
            app.StateLabel.FontColor = color;
        end

        function resize(app)
            % 固定导航宽度，窄窗口由右侧网格滚动保留全部操作。
            if app.UIFigure.Position(3) < 940 || app.UIFigure.Position(4) < 650
                app.MainGrid.RowHeight = {46,32,310,48,52,28};
                app.MainGrid.Scrollable = 'on';
            else
                app.MainGrid.RowHeight = {46,32,'1x',48,52,28};
                app.MainGrid.Scrollable = 'off';
            end
        end

        function openInterface(app)
            root = fileparts(mfilename('fullpath'));
            paths = {fullfile(root,'exp1','docs','接口说明.txt'), ...
                fullfile(root,'exp2','README.md'), fullfile(root,'exp3','README.md'), ...
                fullfile(root,'exp4','README.md')};
            try
                edit(paths{app.SelectedExperiment});
            catch exception
                app.setStatus(exception.message,[0.72 0.17 0.17]);
            end
        end

        function openFolder(app)
            try
                root = fileparts(mfilename('fullpath'));
                if ispc, winopen(root); else, web(root,'-browser'); end
            catch exception
                app.setStatus(exception.message,[0.72 0.17 0.17]);
            end
        end
    end

    methods (Static, Access = private)
        function value = choose(condition, whenTrue, whenFalse)
            if condition, value = whenTrue; else, value = whenFalse; end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.Navigation = {app.SelectExperiment1, app.SelectExperiment2, app.SelectExperiment3, app.SelectExperiment4};
            app.Capabilities = {app.Label_3, app.Label_4; app.Label_5, app.Label_6; app.Label_7, app.Label_8; app.Label_9, app.Label_10};
            app.selectExperiment(1);
            app.resize();
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            app.requestClose();
        end

        % Size changed function: UIFigure
        function UIFigureSizeChanged(app, event)
            app.resize();
        end

        % Button pushed function: SelectExperiment1
        function SelectExperiment1ButtonPushed(app, event)
            app.selectExperiment(1);
        end

        % Button pushed function: SelectExperiment2
        function SelectExperiment2ButtonPushed(app, event)
            app.selectExperiment(2);
        end

        % Button pushed function: SelectExperiment3
        function SelectExperiment3ButtonPushed(app, event)
            app.selectExperiment(3);
        end

        % Button pushed function: SelectExperiment4
        function SelectExperiment4ButtonPushed(app, event)
            app.selectExperiment(4);
        end

        % Button pushed function: Button
        function ButtonButtonPushed(app, event)
            app.openFolder();
        end

        % Button pushed function: OpenButton
        function OpenButtonButtonPushed(app, event)
            app.openSelected();
        end

        % Button pushed function: Button_1
        function Button_1ButtonPushed(app, event)
            app.openInterface();
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Color = [0.94 0.96 0.98];
            app.UIFigure.Position = [100 100 1080 720];
            app.UIFigure.Name = 'MATLAB 实验 · NWPU 2026';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @UIFigureSizeChanged, true);
            app.UIFigure.Tag = 'ExperimentHub';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {220, '1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];

            % Create MainGrid
            app.MainGrid = uigridlayout(app.GridLayout);
            app.MainGrid.ColumnWidth = {'1x'};
            app.MainGrid.RowHeight = {46, 32, '1x', 48, 52, 28};
            app.MainGrid.RowSpacing = 14;
            app.MainGrid.Padding = [28 26 28 22];
            app.MainGrid.Layout.Row = 1;
            app.MainGrid.Layout.Column = 2;
            app.MainGrid.BackgroundColor = [0.94 0.96 0.98];

            % Create StateLabel
            app.StateLabel = uilabel(app.MainGrid);
            app.StateLabel.Tag = 'HubStatus';
            app.StateLabel.FontName = 'Microsoft YaHei';
            app.StateLabel.FontSize = 13;
            app.StateLabel.FontColor = [0.12 0.17 0.25];
            app.StateLabel.Tooltip = '就绪';
            app.StateLabel.Layout.Row = 6;
            app.StateLabel.Layout.Column = 1;
            app.StateLabel.Text = '就绪';

            % Create Label_11
            app.Label_11 = uilabel(app.MainGrid);
            app.Label_11.WordWrap = 'on';
            app.Label_11.FontName = 'Microsoft YaHei';
            app.Label_11.FontSize = 13;
            app.Label_11.FontColor = [0.35 0.4 0.48];
            app.Label_11.Layout.Row = 5;
            app.Label_11.Layout.Column = 1;
            app.Label_11.Text = '实验参数在各自窗口中设置；可同时打开多个实验。';

            % Create GridLayout_3
            app.GridLayout_3 = uigridlayout(app.MainGrid);
            app.GridLayout_3.ColumnWidth = {'1x', 150};
            app.GridLayout_3.RowHeight = {'1x'};
            app.GridLayout_3.Padding = [0 0 0 0];
            app.GridLayout_3.Layout.Row = 4;
            app.GridLayout_3.Layout.Column = 1;
            app.GridLayout_3.BackgroundColor = [0.94 0.96 0.98];

            % Create Button_1
            app.Button_1 = uibutton(app.GridLayout_3, 'push');
            app.Button_1.ButtonPushedFcn = createCallbackFcn(app, @Button_1ButtonPushed, true);
            app.Button_1.FontName = 'Microsoft YaHei';
            app.Button_1.FontSize = 14;
            app.Button_1.Layout.Row = 1;
            app.Button_1.Layout.Column = 2;
            app.Button_1.Text = '接口与运行说明';

            % Create OpenButton
            app.OpenButton = uibutton(app.GridLayout_3, 'push');
            app.OpenButton.ButtonPushedFcn = createCallbackFcn(app, @OpenButtonButtonPushed, true);
            app.OpenButton.Tag = 'OpenExperiment';
            app.OpenButton.BackgroundColor = [0.12 0.33 0.67];
            app.OpenButton.FontName = 'Microsoft YaHei';
            app.OpenButton.FontSize = 15;
            app.OpenButton.FontWeight = 'bold';
            app.OpenButton.FontColor = [1 1 1];
            app.OpenButton.Layout.Row = 1;
            app.OpenButton.Layout.Column = 1;
            app.OpenButton.Text = '打开实验';

            % Create DetailPanel
            app.DetailPanel = uipanel(app.MainGrid);
            app.DetailPanel.Title = '实验内容';
            app.DetailPanel.BackgroundColor = [1 1 1];
            app.DetailPanel.Layout.Row = 3;
            app.DetailPanel.Layout.Column = 1;
            app.DetailPanel.FontName = 'Microsoft YaHei';
            app.DetailPanel.FontWeight = 'bold';
            app.DetailPanel.FontSize = 15;

            % Create GridLayout_2
            app.GridLayout_2 = uigridlayout(app.DetailPanel);
            app.GridLayout_2.ColumnWidth = {90, '1x'};
            app.GridLayout_2.RowHeight = {'1x', '1x', '1x', '1x'};
            app.GridLayout_2.Padding = [22 20 22 20];
            app.GridLayout_2.BackgroundColor = [1 1 1];

            % Create Label_10
            app.Label_10 = uilabel(app.GridLayout_2);
            app.Label_10.WordWrap = 'on';
            app.Label_10.FontName = 'Microsoft YaHei';
            app.Label_10.FontSize = 14;
            app.Label_10.FontColor = [0.32 0.38 0.47];
            app.Label_10.Layout.Row = 4;
            app.Label_10.Layout.Column = 2;
            app.Label_10.Text = 'MAT / CSV 数据、PNG / PDF 图形';

            % Create Label_9
            app.Label_9 = uilabel(app.GridLayout_2);
            app.Label_9.FontName = 'Microsoft YaHei';
            app.Label_9.FontSize = 14;
            app.Label_9.FontWeight = 'bold';
            app.Label_9.FontColor = [0.12 0.17 0.25];
            app.Label_9.Layout.Row = 4;
            app.Label_9.Layout.Column = 1;
            app.Label_9.Text = '保存';

            % Create Label_8
            app.Label_8 = uilabel(app.GridLayout_2);
            app.Label_8.WordWrap = 'on';
            app.Label_8.FontName = 'Microsoft YaHei';
            app.Label_8.FontSize = 14;
            app.Label_8.FontColor = [0.32 0.38 0.47];
            app.Label_8.Layout.Row = 3;
            app.Label_8.Layout.Column = 2;
            app.Label_8.Text = '求和项数、重复次数、分箱方式、音频区间';

            % Create Label_7
            app.Label_7 = uilabel(app.GridLayout_2);
            app.Label_7.FontName = 'Microsoft YaHei';
            app.Label_7.FontSize = 14;
            app.Label_7.FontWeight = 'bold';
            app.Label_7.FontColor = [0.12 0.17 0.25];
            app.Label_7.Layout.Row = 3;
            app.Label_7.Layout.Column = 1;
            app.Label_7.Text = '参数';

            % Create Label_6
            app.Label_6 = uilabel(app.GridLayout_2);
            app.Label_6.WordWrap = 'on';
            app.Label_6.FontName = 'Microsoft YaHei';
            app.Label_6.FontSize = 14;
            app.Label_6.FontColor = [0.32 0.38 0.47];
            app.Label_6.Layout.Row = 2;
            app.Label_6.Layout.Column = 2;
            app.Label_6.Text = '声道波形、时间窗、均值与方差';

            % Create Label_5
            app.Label_5 = uilabel(app.GridLayout_2);
            app.Label_5.FontName = 'Microsoft YaHei';
            app.Label_5.FontSize = 14;
            app.Label_5.FontWeight = 'bold';
            app.Label_5.FontColor = [0.12 0.17 0.25];
            app.Label_5.Layout.Row = 2;
            app.Label_5.Layout.Column = 1;
            app.Label_5.Text = '音频分析';

            % Create Label_4
            app.Label_4 = uilabel(app.GridLayout_2);
            app.Label_4.WordWrap = 'on';
            app.Label_4.FontName = 'Microsoft YaHei';
            app.Label_4.FontSize = 14;
            app.Label_4.FontColor = [0.32 0.38 0.47];
            app.Label_4.Layout.Row = 1;
            app.Label_4.Layout.Column = 2;
            app.Label_4.Text = '均匀随机变量求和、概率密度、高斯拟合';

            % Create Label_3
            app.Label_3 = uilabel(app.GridLayout_2);
            app.Label_3.FontName = 'Microsoft YaHei';
            app.Label_3.FontSize = 14;
            app.Label_3.FontWeight = 'bold';
            app.Label_3.FontColor = [0.12 0.17 0.25];
            app.Label_3.Layout.Row = 1;
            app.Label_3.Layout.Column = 1;
            app.Label_3.Text = '随机仿真';

            % Create Scope
            app.Scope = uilabel(app.MainGrid);
            app.Scope.FontName = 'Microsoft YaHei';
            app.Scope.FontSize = 14;
            app.Scope.FontColor = [0.35 0.4 0.48];
            app.Scope.Layout.Row = 2;
            app.Scope.Layout.Column = 1;
            app.Scope.Text = '统计仿真与音频分析';

            % Create Heading
            app.Heading = uilabel(app.MainGrid);
            app.Heading.FontName = 'Microsoft YaHei';
            app.Heading.FontSize = 24;
            app.Heading.FontWeight = 'bold';
            app.Heading.FontColor = [0.12 0.17 0.25];
            app.Heading.Layout.Row = 1;
            app.Heading.Layout.Column = 1;
            app.Heading.Text = '实验一 · 统计仿真';

            % Create Panel
            app.Panel = uipanel(app.GridLayout);
            app.Panel.BorderType = 'none';
            app.Panel.BackgroundColor = [0.97 0.98 1];
            app.Panel.Layout.Row = 1;
            app.Panel.Layout.Column = 1;
            app.Panel.FontName = 'Microsoft YaHei';

            % Create GridLayout_1
            app.GridLayout_1 = uigridlayout(app.Panel);
            app.GridLayout_1.ColumnWidth = {'1x'};
            app.GridLayout_1.RowHeight = {44, 28, 48, 48, 48, 48, '1x', 28, 32};
            app.GridLayout_1.Padding = [16 20 16 16];
            app.GridLayout_1.BackgroundColor = [0.97 0.98 1];

            % Create Button
            app.Button = uibutton(app.GridLayout_1, 'push');
            app.Button.ButtonPushedFcn = createCallbackFcn(app, @ButtonButtonPushed, true);
            app.Button.FontName = 'Microsoft YaHei';
            app.Button.Layout.Row = 9;
            app.Button.Layout.Column = 1;
            app.Button.Text = '打开项目文件夹';

            % Create Label_2
            app.Label_2 = uilabel(app.GridLayout_1);
            app.Label_2.FontName = 'Microsoft YaHei';
            app.Label_2.FontColor = [0.38 0.43 0.52];
            app.Label_2.Layout.Row = 8;
            app.Label_2.Layout.Column = 1;
            app.Label_2.Text = '四个独立实验窗口';

            % Create SelectExperiment4
            app.SelectExperiment4 = uibutton(app.GridLayout_1, 'push');
            app.SelectExperiment4.ButtonPushedFcn = createCallbackFcn(app, @SelectExperiment4ButtonPushed, true);
            app.SelectExperiment4.Tag = 'SelectExperiment4';
            app.SelectExperiment4.BackgroundColor = [0.96 0.97 0.99];
            app.SelectExperiment4.FontName = 'Microsoft YaHei';
            app.SelectExperiment4.FontSize = 14;
            app.SelectExperiment4.FontColor = [0.12 0.17 0.25];
            app.SelectExperiment4.Layout.Row = 6;
            app.SelectExperiment4.Layout.Column = 1;
            app.SelectExperiment4.Text = '实验四 · 系统稳定性';

            % Create SelectExperiment3
            app.SelectExperiment3 = uibutton(app.GridLayout_1, 'push');
            app.SelectExperiment3.ButtonPushedFcn = createCallbackFcn(app, @SelectExperiment3ButtonPushed, true);
            app.SelectExperiment3.Tag = 'SelectExperiment3';
            app.SelectExperiment3.BackgroundColor = [0.96 0.97 0.99];
            app.SelectExperiment3.FontName = 'Microsoft YaHei';
            app.SelectExperiment3.FontSize = 14;
            app.SelectExperiment3.FontColor = [0.12 0.17 0.25];
            app.SelectExperiment3.Layout.Row = 5;
            app.SelectExperiment3.Layout.Column = 1;
            app.SelectExperiment3.Text = '实验三 · 阵列指向性';

            % Create SelectExperiment2
            app.SelectExperiment2 = uibutton(app.GridLayout_1, 'push');
            app.SelectExperiment2.ButtonPushedFcn = createCallbackFcn(app, @SelectExperiment2ButtonPushed, true);
            app.SelectExperiment2.Tag = 'SelectExperiment2';
            app.SelectExperiment2.BackgroundColor = [0.96 0.97 0.99];
            app.SelectExperiment2.FontName = 'Microsoft YaHei';
            app.SelectExperiment2.FontSize = 14;
            app.SelectExperiment2.FontColor = [0.12 0.17 0.25];
            app.SelectExperiment2.Layout.Row = 4;
            app.SelectExperiment2.Layout.Column = 1;
            app.SelectExperiment2.Text = '实验二 · 数值求根';

            % Create SelectExperiment1
            app.SelectExperiment1 = uibutton(app.GridLayout_1, 'push');
            app.SelectExperiment1.ButtonPushedFcn = createCallbackFcn(app, @SelectExperiment1ButtonPushed, true);
            app.SelectExperiment1.Tag = 'SelectExperiment1';
            app.SelectExperiment1.BackgroundColor = [0.88 0.93 1];
            app.SelectExperiment1.FontName = 'Microsoft YaHei';
            app.SelectExperiment1.FontSize = 14;
            app.SelectExperiment1.FontWeight = 'bold';
            app.SelectExperiment1.FontColor = [0.12 0.33 0.67];
            app.SelectExperiment1.Layout.Row = 3;
            app.SelectExperiment1.Layout.Column = 1;
            app.SelectExperiment1.Text = '实验一 · 统计仿真';

            % Create Label_1
            app.Label_1 = uilabel(app.GridLayout_1);
            app.Label_1.FontName = 'Microsoft YaHei';
            app.Label_1.FontSize = 13;
            app.Label_1.FontColor = [0.38 0.43 0.52];
            app.Label_1.Layout.Row = 2;
            app.Label_1.Layout.Column = 1;
            app.Label_1.Text = 'NWPU 2026';

            % Create Label
            app.Label = uilabel(app.GridLayout_1);
            app.Label.FontName = 'Microsoft YaHei';
            app.Label.FontSize = 21;
            app.Label.FontWeight = 'bold';
            app.Label.FontColor = [0.12 0.17 0.25];
            app.Label.Layout.Row = 1;
            app.Label.Layout.Column = 1;
            app.Label.Text = 'MATLAB 实验';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MatlabExperimentHub

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