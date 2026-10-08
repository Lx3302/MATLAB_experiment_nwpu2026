classdef StatisticsExperimentMath
    %STATISTICSEXPERIMENTMATH Reusable numerical helpers for the experiment app.

    methods (Static)
        function sums = simulate(nTerms, nTrials)
            %SIMULATE Sum nTerms independent U[0,1] values for each trial.
            nTerms = StatisticsExperimentMath.requirePositiveInteger( ...
                nTerms, 'nTerms', 'StatisticsExperimentMath:InvalidSimulationSize');
            nTrials = StatisticsExperimentMath.requirePositiveInteger( ...
                nTrials, 'nTrials', 'StatisticsExperimentMath:InvalidSimulationSize');

            if nTerms > 1e8 / nTrials
                error('StatisticsExperimentMath:SimulationTooLarge', ...
                    '模拟规模 nTerms*nTrials 不能超过 1e8；请减小项数或重复次数。');
            end

            % Bound temporary random arrays even when either dimension is large.
            maxTemporaryElements = 1e6;
            termBlockSize = min(nTerms, maxTemporaryElements);
            trialBlockSize = max(1, floor(maxTemporaryElements / termBlockSize));
            sums = zeros(nTrials, 1);

            for trialStart = 1:trialBlockSize:nTrials
                trialEnd = min(nTrials, trialStart + trialBlockSize - 1);
                trialIndices = trialStart:trialEnd;
                blockSums = zeros(1, numel(trialIndices));

                for termStart = 1:termBlockSize:nTerms
                    termEnd = min(nTerms, termStart + termBlockSize - 1);
                    randomBlock = rand(termEnd - termStart + 1, numel(trialIndices));
                    blockSums = blockSums + sum(randomBlock, 1);
                end

                sums(trialIndices) = blockSums(:);
            end
        end

        function edges = densityEdges(data, mode, value)
            %DENSITYEDGES Return common, equally spaced histogram edges.
            StatisticsExperimentMath.requireFiniteRealMatrix( ...
                data, 'data', 'StatisticsExperimentMath:InvalidDensityData');
            data = double(data);

            if isstring(mode) && isscalar(mode)
                mode = char(mode);
            end
            if ~(ischar(mode) && (isrow(mode) || isempty(mode)))
                error('StatisticsExperimentMath:InvalidDensityMode', ...
                    'mode 必须是 ''count'' 或 ''width''。');
            end
            mode = lower(strtrim(mode));
            if ~any(strcmp(mode, {'count', 'width'}))
                error('StatisticsExperimentMath:InvalidDensityMode', ...
                    'mode 必须是 ''count'' 或 ''width''。');
            end

            maxBins = 5000;
            dataMinimum = min(data(:));
            dataMaximum = max(data(:));

            switch mode
                case 'count'
                    binCount = StatisticsExperimentMath.requirePositiveInteger( ...
                        value, 'value', 'StatisticsExperimentMath:InvalidDensityValue');
                    if binCount > maxBins
                        error('StatisticsExperimentMath:TooManyDensityBins', ...
                            '分箱数不能超过 %d；请减小分箱数。', maxBins);
                    end

                    if dataMinimum == dataMaximum
                        edges = StatisticsExperimentMath.constantCountEdges( ...
                            dataMinimum, binCount);
                    else
                        edges = linspace(dataMinimum, dataMaximum, binCount + 1);
                    end

                case 'width'
                    binWidth = StatisticsExperimentMath.requirePositiveFiniteScalar( ...
                        value, 'value', 'StatisticsExperimentMath:InvalidDensityValue');
                    edges = StatisticsExperimentMath.edgesForWidth( ...
                        dataMinimum, dataMaximum, binWidth, maxBins);
            end
        end

        function [i1, i2] = windowIndices(t0, t1, fs, nSamples)
            %WINDOWINDICES Map a half-open time interval to inclusive MATLAB indices.
            t0 = StatisticsExperimentMath.requireFiniteRealScalar( ...
                t0, 't0', 'StatisticsExperimentMath:InvalidWindow');
            t1 = StatisticsExperimentMath.requireFiniteRealScalar( ...
                t1, 't1', 'StatisticsExperimentMath:InvalidWindow');
            fs = StatisticsExperimentMath.requirePositiveFiniteScalar( ...
                fs, 'fs', 'StatisticsExperimentMath:InvalidWindow');
            nSamples = StatisticsExperimentMath.requirePositiveInteger( ...
                nSamples, 'nSamples', 'StatisticsExperimentMath:InvalidWindow');

            if t0 < 0 || t1 <= t0
                error('StatisticsExperimentMath:InvalidWindow', ...
                    '时间窗必须满足 0 <= t0 < t1。');
            end

            duration = nSamples / fs;
            if ~isfinite(duration)
                error('StatisticsExperimentMath:InvalidWindow', ...
                    '记录时长超出可表示范围。');
            end
            durationTolerance = 8 * eps(max(abs(duration), abs(t1)));
            if t1 > duration && t1 - duration > durationTolerance
                error('StatisticsExperimentMath:InvalidWindow', ...
                    '时间窗终点不能超过记录时长 %.15g 秒。', duration);
            end

            % Clamp a permitted floating-point overrun at the record boundary.
            boundedEnd = min(t1, duration);
            firstSample = t0 * fs;
            lastSample = boundedEnd * fs;
            startTolerance = 8 * eps(max(1, abs(firstSample)));
            endTolerance = 8 * eps(max(1, abs(lastSample)));
            i1 = ceil(firstSample - startTolerance) + 1;
            i2 = ceil(lastSample - endTolerance);
            i1 = max(1, min(nSamples, i1));
            i2 = max(0, min(nSamples, i2));

            if i2 - i1 + 1 < 2
                error('StatisticsExperimentMath:WindowTooShort', ...
                    '选定时间窗必须至少包含两个采样点。');
            end
        end

        function stats = summarize(data)
            %SUMMARIZE Calculate per-column sample statistics for finite data.
            StatisticsExperimentMath.requireFiniteRealMatrix( ...
                data, 'data', 'StatisticsExperimentMath:InvalidSummaryData');

            columnCount = size(data, 2);
            sampleCount = size(data, 1);
            data = double(data);

            stats = struct();
            stats.Mean = mean(data, 1);
            if sampleCount < 2
                stats.Variance = zeros(1, columnCount);
            else
                stats.Variance = var(data, 0, 1);
            end
            stats.Std = sqrt(stats.Variance);

            scale = max(abs(data), [], 1);
            rmsValues = zeros(1, columnCount);
            nonzeroColumns = scale > 0;
            if any(nonzeroColumns)
                normalized = data(:, nonzeroColumns) ./ scale(nonzeroColumns);
                rmsValues(nonzeroColumns) = scale(nonzeroColumns) .* ...
                    sqrt(mean(normalized .^ 2, 1));
            end
            stats.RMS = rmsValues;
            stats.Count = repmat(sampleCount, 1, columnCount);
        end

        function density = normalDensity(xx, mu, sigma)
            %NORMALDENSITY Evaluate a normal probability density without a toolbox.
            StatisticsExperimentMath.requireFiniteRealMatrix( ...
                xx, 'xx', 'StatisticsExperimentMath:InvalidNormalInput');
            mu = StatisticsExperimentMath.requireFiniteRealScalar( ...
                mu, 'mu', 'StatisticsExperimentMath:InvalidNormalInput');
            sigma = StatisticsExperimentMath.requireFiniteRealScalar( ...
                sigma, 'sigma', 'StatisticsExperimentMath:InvalidNormalInput');
            if sigma < 0
                error('StatisticsExperimentMath:InvalidNormalInput', ...
                    'sigma 必须大于或等于 0。');
            end
            if sigma == 0
                density = [];
                return;
            end

            standardized = (double(xx) - mu) ./ sigma;
            density = exp(-0.5 .* standardized .^ 2) .* ...
                ((1 ./ sigma) ./ sqrt(2 * pi));
        end

        function [t, values] = waveformPreview(data, fs, maxPoints)
            %WAVEFORMPREVIEW Reduce a waveform while retaining block extrema.
            StatisticsExperimentMath.requireFiniteRealMatrix( ...
                data, 'data', 'StatisticsExperimentMath:InvalidWaveform');
            fs = StatisticsExperimentMath.requirePositiveFiniteScalar( ...
                fs, 'fs', 'StatisticsExperimentMath:InvalidWaveform');
            maxPoints = StatisticsExperimentMath.requirePositiveInteger( ...
                maxPoints, 'maxPoints', 'StatisticsExperimentMath:InvalidWaveform');

            data = double(data);
            sampleCount = size(data, 1);
            channelCount = size(data, 2);
            if sampleCount <= maxPoints
                indices = (1:sampleCount).';
            else
                if maxPoints < 2 * channelCount
                    error('StatisticsExperimentMath:PreviewLimitTooSmall', ...
                        'maxPoints 至少需要为每个通道保留一个最小值和一个最大值（当前至少需要 %d 点）。', ...
                        2 * channelCount);
                end

                blockCount = max(1, floor(maxPoints / (2 * channelCount)));
                blockSize = ceil(sampleCount / blockCount);
                selected = zeros(0, 1);
                for blockStart = 1:blockSize:sampleCount
                    blockEnd = min(sampleCount, blockStart + blockSize - 1);
                    rows = blockStart:blockEnd;
                    [~, localMinima] = min(data(rows, :), [], 1);
                    [~, localMaxima] = max(data(rows, :), [], 1);
                    selected = [selected; ...
                        blockStart + localMinima(:) - 1; ...
                        blockStart + localMaxima(:) - 1]; %#ok<AGROW>
                end
                indices = unique(selected, 'sorted');
            end

            values = data(indices, :);
            t = (indices - 1) ./ fs;
        end

        function result = runSimulation(terms, trials, binMode, binValue)
            %RUNSIMULATION Run a sum-of-uniforms experiment and build a result snapshot.
            %   RESULT = RUNSIMULATION(TERMS, TRIALS, BINMODE, BINVAL) accepts
            %   positive integer TERMS and TRIALS, and BINMODE 'count' or 'width'.
            %   BINVALUE is a positive bin count or a positive width in sum units.
            %   RESULT.Samples is TRIALS-by-1; RESULT.Statistics contains row
            %   vectors, with sample variance normalized by N-1. RESULT.Plot.Density
            %   is bins-by-1 (probability density per sum unit), FitX is an
            %   800-by-1 sum-unit grid, and FitDensity and TheoryDensity are
            %   densities on that grid. No graphics handles are retained.
            terms = StatisticsExperimentMath.requirePositiveInteger( ...
                terms, 'terms', 'StatisticsExperimentMath:InvalidSimulationSize');
            trials = StatisticsExperimentMath.requirePositiveInteger( ...
                trials, 'trials', 'StatisticsExperimentMath:InvalidSimulationSize');
            binMode = StatisticsExperimentMath.normalizeBinMode(binMode);

            samples = StatisticsExperimentMath.simulate(terms, trials);
            edges = StatisticsExperimentMath.densityEdges(samples, binMode, binValue);
            stats = StatisticsExperimentMath.summarize(samples);
            theoryMean = terms / 2;
            theoryVariance = terms / 12;
            plotData = StatisticsExperimentMath.buildPlotData(samples, edges, stats);
            plotData.TheoryDensity = StatisticsExperimentMath.normalDensity( ...
                plotData.FitX, theoryMean, sqrt(theoryVariance));

            result = struct( ...
                'Kind', 'simulation', ...
                'Samples', samples, ...
                'Statistics', stats, ...
                'BinEdges', edges, ...
                'BinMode', binMode, ...
                'BinParameter', double(binValue), ...
                'CreatedAt', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
                'Summands', terms, ...
                'Trials', trials, ...
                'TheoreticalMean', theoryMean, ...
                'TheoreticalVariance', theoryVariance, ...
                'Plot', plotData);
        end

        function audio = readAudio(filePath)
            %READAUDIO Read audio metadata and up to two independent channels.
            %   AUDIO = READAUDIO(FILEPATH) returns double AUDIO.Samples with
            %   size [N,min(2,C)], SampleRate in samples/second, Duration in
            %   seconds, SourceFile and SourcePath text scalars, and OriginalChannels
            %   equal to the file's original channel count. At least two finite
            %   samples are required. Channels beyond the first two are omitted.
            if isstring(filePath) && isscalar(filePath)
                filePath = char(filePath);
            end
            if ~(ischar(filePath) && isrow(filePath) && ~isempty(strtrim(filePath)))
                error('StatisticsExperimentMath:InvalidAudioPath', ...
                    'filePath 必须是非空文件路径。');
            end

            [data, sampleRate] = audioread(filePath);
            if isempty(data) || size(data, 1) < 2 || size(data, 2) < 1 || ...
                    any(~isfinite(data(:))) || ~isfinite(sampleRate) || sampleRate <= 0
                error('StatisticsExperimentMath:InvalidAudio', ...
                    '音频需要至少两个有限数值样本和有效采样率。');
            end

            [~, name, extension] = fileparts(filePath);
            sourcePath = StatisticsExperimentMath.resolveSourcePath(filePath);
            originalChannels = size(data, 2);
            audio = struct( ...
                'Samples', double(data(:, 1:min(2, originalChannels))), ...
                'SampleRate', double(sampleRate), ...
                'Duration', double(size(data, 1) / sampleRate), ...
                'SourceFile', [name extension], ...
                'SourcePath', sourcePath, ...
                'OriginalChannels', originalChannels);
        end

        function preview = previewAudio(audio, startTime, endTime, maxPoints)
            %PREVIEWAUDIO Return a reduced preview for a half-open time window.
            %   PREVIEW = PREVIEWAUDIO(AUDIO, STARTTIME, ENDTIME, MAXPOINTS)
            %   takes an audio struct returned by READAUDIO. Time arguments are
            %   seconds and define [STARTTIME,ENDTIME); the returned ActualWindow
            %   is the selected samples' [first time, exclusive end) in seconds.
            %   SampleCount is the selected count per channel. Waveforms is a
            %   1-by-C struct array; each Time is an absolute-seconds column,
            %   Amplitude is the matching double column, and ChannelCount is C.
            audio = StatisticsExperimentMath.validateAudio(audio);
            maxPoints = StatisticsExperimentMath.requirePositiveInteger( ...
                maxPoints, 'maxPoints', 'StatisticsExperimentMath:InvalidWaveform');
            [firstIndex, lastIndex] = StatisticsExperimentMath.windowIndices( ...
                startTime, endTime, audio.SampleRate, size(audio.Samples, 1));
            actualWindow = [(firstIndex - 1) / audio.SampleRate, ...
                lastIndex / audio.SampleRate];
            segment = audio.Samples(firstIndex:lastIndex, :);
            [relativeTime, reducedSamples] = StatisticsExperimentMath.waveformPreview( ...
                segment, audio.SampleRate, maxPoints);
            waveforms = StatisticsExperimentMath.makeWaveforms( ...
                relativeTime + actualWindow(1), reducedSamples);

            preview = struct( ...
                'ActualWindow', actualWindow, ...
                'SampleCount', size(segment, 1), ...
                'ChannelCount', size(segment, 2), ...
                'Waveforms', waveforms);
        end

        function result = analyzeAudio(audio, startTime, endTime, binMode, binValue)
            %ANALYZEAUDIO Analyze each channel within a half-open time window.
            %   RESULT = ANALYZEAUDIO(AUDIO, STARTTIME, ENDTIME, BINMODE,
            %   BINVAL) uses audio metadata from READAUDIO and seconds for
            %   both time values. Samples is N-by-C double; Time is N-by-1
            %   absolute seconds; ActualWindow is [first sample time, exclusive
            %   end) in seconds; SampleIndices is [first,last] inclusive.
            %   Statistics fields are 1-by-C row vectors; Variance uses N-1.
            %   Plot.Density is bins-by-C (inverse amplitude units), FitX is an
            %   800-by-1 amplitude grid, and FitDensity is grid-by-C. A zero
            %   standard deviation produces a NaN fit column. Waveforms is a
            %   1-by-C preview struct array with absolute Time in seconds.
            audio = StatisticsExperimentMath.validateAudio(audio);
            binMode = StatisticsExperimentMath.normalizeBinMode(binMode);
            [firstIndex, lastIndex] = StatisticsExperimentMath.windowIndices( ...
                startTime, endTime, audio.SampleRate, size(audio.Samples, 1));
            samples = audio.Samples(firstIndex:lastIndex, :);
            stats = StatisticsExperimentMath.summarize(samples);
            edges = StatisticsExperimentMath.densityEdges(samples, binMode, binValue);
            actualWindow = [(firstIndex - 1) / audio.SampleRate, ...
                lastIndex / audio.SampleRate];
            [relativeTime, reducedSamples] = StatisticsExperimentMath.waveformPreview( ...
                samples, audio.SampleRate, 10000);
            waveforms = StatisticsExperimentMath.makeWaveforms( ...
                relativeTime + actualWindow(1), reducedSamples);
            plotData = StatisticsExperimentMath.buildPlotData(samples, edges, stats);

            result = struct( ...
                'Kind', 'audio', ...
                'Samples', samples, ...
                'Statistics', stats, ...
                'BinEdges', edges, ...
                'BinMode', binMode, ...
                'BinParameter', double(binValue), ...
                'CreatedAt', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
                'SourceFile', audio.SourceFile, ...
                'SourcePath', audio.SourcePath, ...
                'SampleRate', audio.SampleRate, ...
                'RequestedWindow', [double(startTime), double(endTime)], ...
                'ActualWindow', actualWindow, ...
                'SampleIndices', [firstIndex, lastIndex], ...
                'Time', ((firstIndex - 1:lastIndex - 1).' / audio.SampleRate), ...
                'Plot', plotData, ...
                'Waveforms', waveforms);
        end

        function savedFiles = saveResult(result, filePath)
            %SAVERESULT Save a result struct as MAT or as CSV plus statistics.
            %   SAVEDFILES is a cell array of actual output paths. MAT contains
            %   the complete RESULT struct. CSV contains sample rows and a
            %   sibling *_statistics.csv summary. Simulation CSV columns are
            %   Trial and Sum; audio columns include absolute Time_seconds and
            %   one column per retained channel. No app handles are accepted.
            result = StatisticsExperimentMath.validateResult(result, ...
                {'Kind', 'Samples'});
            filePath = StatisticsExperimentMath.requireFilePath(filePath);
            [folder, name, extension] = fileparts(filePath);
            extension = lower(extension);
            if isempty(folder)
                folder = pwd;
                filePath = fullfile(folder, [name extension]);
            end

            if strcmp(extension, '.mat')
                save(filePath, 'result', '-v7.3');
                savedFiles = {filePath};
            elseif strcmp(extension, '.csv')
                result = StatisticsExperimentMath.validateResult(result, ...
                    {'Kind', 'Samples', 'Statistics'});
                if strcmp(result.Kind, 'simulation')
                    data = table((1:numel(result.Samples)).', result.Samples(:), ...
                        'VariableNames', {'Trial', 'Sum'});
                elseif strcmp(result.Kind, 'audio')
                    result = StatisticsExperimentMath.validateResult(result, ...
                        {'Time', 'Samples'});
                    if size(result.Samples, 2) == 2
                        data = table(result.Time(:), result.Samples(:, 1), ...
                            result.Samples(:, 2), ...
                            'VariableNames', {'Time_seconds', 'Channel1', 'Channel2'});
                    else
                        data = table(result.Time(:), result.Samples(:, 1), ...
                            'VariableNames', {'Time_seconds', 'Channel1'});
                    end
                else
                    error('StatisticsExperimentMath:InvalidResult', ...
                        'CSV 仅支持 simulation 或 audio 结果。');
                end
                writetable(data, filePath, 'Encoding', 'UTF-8');
                statisticsPath = fullfile(folder, [name '_statistics.csv']);
                summary = StatisticsExperimentMath.summaryTable(result);
                writetable(summary, statisticsPath, 'Encoding', 'UTF-8');
                savedFiles = {filePath, statisticsPath};
            else
                error('StatisticsExperimentMath:FileType', ...
                    '数据文件请使用 .mat 或 .csv 扩展名。');
            end
        end

        function exportFigure(result, filePath)
            %EXPORTFIGURE Export a result snapshot to PNG or vector PDF.
            %   EXPORTFIGURE consumes RESULT.Plot and RESULT.Waveforms; it
            %   creates one invisible figure owned by this call and deletes only
            %   that figure after export. It does not use or retain app graphics.
            %   PNG is rendered at 200 dpi; PDF uses vector content.
            result = StatisticsExperimentMath.validateResult(result, ...
                {'Kind', 'Samples', 'Statistics', 'BinEdges', 'Plot'});
            filePath = StatisticsExperimentMath.requireFilePath(filePath);
            [~, ~, extension] = fileparts(filePath);
            extension = lower(extension);
            if ~ismember(extension, {'.png', '.pdf'})
                error('StatisticsExperimentMath:FileType', ...
                    '图像请使用 .png 或 .pdf 扩展名。');
            end

            fig = figure('Visible', 'off', 'Color', 'white', ...
                'Position', [100 100 1400 900]);
            cleanup = onCleanup(@() delete(fig));
            palette = [0.12 0.42 0.70; 0.85 0.38 0.16];

            if strcmp(result.Kind, 'simulation')
                ax = axes('Parent', fig);
                StatisticsExperimentMath.styleExportAxes(ax);
                StatisticsExperimentMath.drawDensity(ax, result, 1, palette(1, :));
                hold(ax, 'on');
                if size(result.Plot.FitDensity, 2) >= 1 && ...
                        any(isfinite(result.Plot.FitDensity(:, 1)))
                    plot(ax, result.Plot.FitX, result.Plot.FitDensity(:, 1), ...
                        'Color', [0.85 0.28 0.22], 'LineWidth', 1.8, ...
                        'DisplayName', 'Sample Gaussian fit');
                end
                plot(ax, result.Plot.FitX, result.Plot.TheoryDensity(:), ...
                    '--', 'Color', [0.22 0.25 0.30], 'LineWidth', 1.5, ...
                    'DisplayName', 'Theoretical Gaussian approximation');
                hold(ax, 'off');
                title(ax, {sprintf('Sum of %d Uniform Variables · %d Trials', ...
                    result.Summands, result.Trials), ...
                    sprintf('Mean %.6g · Variance %.6g · Std %.6g', ...
                    result.Statistics.Mean(1), result.Statistics.Variance(1), ...
                    result.Statistics.Std(1))}, 'Interpreter', 'none');
                xlabel(ax, 'Sum S');
                ylabel(ax, 'Probability density');
                legend(ax, 'Location', 'best');
                xlim(ax, [result.BinEdges(1), result.BinEdges(end)]);
            elseif strcmp(result.Kind, 'audio')
                result = StatisticsExperimentMath.validateResult(result, ...
                    {'SourceFile', 'SampleRate', 'ActualWindow', 'Waveforms'});
                channelCount = size(result.Samples, 2);
                if numel(result.Waveforms) ~= channelCount
                    error('StatisticsExperimentMath:InvalidResult', ...
                        '音频结果中的波形预览数量必须匹配样本声道数。');
                end
                layout = tiledlayout(fig, 2, channelCount, ...
                    'TileSpacing', 'compact', 'Padding', 'compact');
                for channel = 1:channelCount
                    ax = nexttile(layout, channel);
                    StatisticsExperimentMath.styleExportAxes(ax);
                    waveform = result.Waveforms(channel);
                    plot(ax, waveform.Time(:), waveform.Amplitude(:), ...
                        'Color', palette(min(channel, size(palette, 1)), :), ...
                        'LineWidth', 1.0);
                    title(ax, sprintf('Channel %d waveform', channel));
                    xlabel(ax, 'Time (s)');
                    ylabel(ax, 'Amplitude');

                    ax = nexttile(layout, channelCount + channel);
                    StatisticsExperimentMath.styleExportAxes(ax);
                    StatisticsExperimentMath.drawDensity(ax, result, channel, ...
                        palette(min(channel, size(palette, 1)), :));
                    if size(result.Plot.FitDensity, 2) >= channel && ...
                            any(isfinite(result.Plot.FitDensity(:, channel)))
                        hold(ax, 'on');
                        plot(ax, result.Plot.FitX, result.Plot.FitDensity(:, channel), ...
                            'Color', [0.85 0.28 0.22], 'LineWidth', 1.7, ...
                            'DisplayName', 'Sample Gaussian fit');
                        hold(ax, 'off');
                    end
                    title(ax, {sprintf('Channel %d density', channel), ...
                        sprintf('Mean %.6g · Variance %.6g · Std %.6g', ...
                        result.Statistics.Mean(channel), ...
                        result.Statistics.Variance(channel), ...
                        result.Statistics.Std(channel))}, 'Interpreter', 'none');
                    xlabel(ax, 'Amplitude');
                    ylabel(ax, 'Probability density');
                    legend(ax, 'Location', 'best');
                end
                title(layout, sprintf('%s · [%.6g, %.6g) s · %d samples/channel', ...
                    result.SourceFile, result.ActualWindow(1), result.ActualWindow(2), ...
                    size(result.Samples, 1)), 'Interpreter', 'none');
            else
                error('StatisticsExperimentMath:InvalidResult', ...
                    '图像导出仅支持 simulation 或 audio 结果。');
            end

            if strcmp(extension, '.pdf')
                exportgraphics(fig, filePath, 'ContentType', 'vector', ...
                    'BackgroundColor', 'white');
            else
                exportgraphics(fig, filePath, 'Resolution', 200, ...
                    'BackgroundColor', 'white');
            end
        end
    end

    methods (Static, Access = private)
        function mode = normalizeBinMode(mode)
            if isstring(mode) && isscalar(mode)
                mode = char(mode);
            end
            if ~(ischar(mode) && (isrow(mode) || isempty(mode)))
                error('StatisticsExperimentMath:InvalidDensityMode', ...
                    'mode 必须是 ''count'' 或 ''width''。');
            end
            mode = lower(strtrim(mode));
            if ~any(strcmp(mode, {'count', 'width'}))
                error('StatisticsExperimentMath:InvalidDensityMode', ...
                    'mode 必须是 ''count'' 或 ''width''。');
            end
        end

        function audio = validateAudio(audio)
            required = {'Samples', 'SampleRate', 'Duration', ...
                'SourceFile', 'SourcePath', 'OriginalChannels'};
            if ~(isstruct(audio) && isscalar(audio) && ...
                    all(isfield(audio, required)))
                error('StatisticsExperimentMath:InvalidAudio', ...
                    'audio 必须是 readAudio 返回的标量结构体。');
            end
            StatisticsExperimentMath.requireFiniteRealMatrix( ...
                audio.Samples, 'audio.Samples', 'StatisticsExperimentMath:InvalidAudio');
            if size(audio.Samples, 1) < 2 || size(audio.Samples, 2) > 2
                error('StatisticsExperimentMath:InvalidAudio', ...
                    'audio.Samples 必须至少包含两行且最多包含两个声道。');
            end
            audio.Samples = double(audio.Samples);
            audio.SampleRate = StatisticsExperimentMath.requirePositiveFiniteScalar( ...
                audio.SampleRate, 'audio.SampleRate', 'StatisticsExperimentMath:InvalidAudio');
            audio.Duration = StatisticsExperimentMath.requirePositiveFiniteScalar( ...
                audio.Duration, 'audio.Duration', 'StatisticsExperimentMath:InvalidAudio');
            audio.OriginalChannels = StatisticsExperimentMath.requirePositiveInteger( ...
                audio.OriginalChannels, 'audio.OriginalChannels', ...
                'StatisticsExperimentMath:InvalidAudio');
            if ~(ischar(audio.SourceFile) && (isrow(audio.SourceFile) || isempty(audio.SourceFile)))
                if isstring(audio.SourceFile) && isscalar(audio.SourceFile)
                    audio.SourceFile = char(audio.SourceFile);
                else
                    error('StatisticsExperimentMath:InvalidAudio', ...
                        'audio.SourceFile 必须是文本标量。');
                end
            end
            if ~(ischar(audio.SourcePath) && (isrow(audio.SourcePath) || isempty(audio.SourcePath)))
                if isstring(audio.SourcePath) && isscalar(audio.SourcePath)
                    audio.SourcePath = char(audio.SourcePath);
                else
                    error('StatisticsExperimentMath:InvalidAudio', ...
                        'audio.SourcePath 必须是文本标量。');
                end
            end
        end

        function sourcePath = resolveSourcePath(filePath)
            sourcePath = filePath;
            try
                [found, attributes] = fileattrib(filePath);
                if found && isfield(attributes, 'Name')
                    sourcePath = attributes.Name;
                    return;
                end
            catch
                % audioread already resolved the file; preserve its supplied path.
            end
            resolved = which(filePath);
            if ~isempty(resolved)
                sourcePath = resolved;
            end
        end

        function plotData = buildPlotData(data, edges, stats)
            channelCount = size(data, 2);
            density = zeros(numel(edges) - 1, channelCount);
            for channel = 1:channelCount
                density(:, channel) = histcounts(data(:, channel), edges, ...
                    'Normalization', 'pdf').';
            end

            fitX = linspace(edges(1), edges(end), 800).';
            fitDensity = nan(numel(fitX), channelCount);
            for channel = 1:channelCount
                if stats.Std(channel) > 0
                    fitDensity(:, channel) = StatisticsExperimentMath.normalDensity( ...
                        fitX, stats.Mean(channel), stats.Std(channel));
                end
            end
            plotData = struct( ...
                'Density', density, ...
                'FitX', fitX, ...
                'FitDensity', fitDensity);
        end

        function waveforms = makeWaveforms(time, samples)
            channelCount = size(samples, 2);
            template = struct('Time', zeros(0, 1), ...
                'Amplitude', zeros(0, 1), 'ChannelCount', channelCount);
            waveforms = repmat(template, 1, channelCount);
            for channel = 1:channelCount
                waveforms(channel).Time = double(time(:));
                waveforms(channel).Amplitude = double(samples(:, channel));
            end
        end

        function savedPath = requireFilePath(filePath)
            if isstring(filePath) && isscalar(filePath)
                filePath = char(filePath);
            end
            if ~(ischar(filePath) && isrow(filePath) && ~isempty(strtrim(filePath)))
                error('StatisticsExperimentMath:InvalidFilePath', ...
                    'filePath 必须是非空文件路径。');
            end
            savedPath = filePath;
        end

        function result = validateResult(result, requiredFields)
            if ~(isstruct(result) && isscalar(result) && ...
                    all(isfield(result, requiredFields)))
                error('StatisticsExperimentMath:InvalidResult', ...
                    'result 必须是包含所需字段的标量结构体。');
            end
        end

        function summary = summaryTable(result)
            keys = {'Kind'; 'CreatedAt'; 'VarianceNormalization'; ...
                'BinMode'; 'BinParameter'; 'BinCount'; 'BinWidth'};
            values = {result.Kind; result.CreatedAt; 'N-1'; result.BinMode; ...
                sprintf('%.12g', result.BinParameter); ...
                sprintf('%d', numel(result.BinEdges) - 1); ...
                sprintf('%.12g', diff(result.BinEdges(1:2)))};
            if strcmp(result.Kind, 'simulation')
                keys = [keys; {'Summands'; 'Trials'; ...
                    'TheoreticalMean'; 'TheoreticalVariance'}];
                values = [values; {sprintf('%d', result.Summands); ...
                    sprintf('%d', result.Trials); ...
                    sprintf('%.12g', result.TheoreticalMean); ...
                    sprintf('%.12g', result.TheoreticalVariance)}];
            elseif strcmp(result.Kind, 'audio')
                keys = [keys; {'SourceFile'; 'SourcePath'; 'SampleRate'; ...
                    'ActualStart_seconds'; 'ActualEnd_seconds'; 'SamplesPerChannel'}];
                values = [values; {result.SourceFile; result.SourcePath; ...
                    sprintf('%g', result.SampleRate); ...
                    sprintf('%.12g', result.ActualWindow(1)); ...
                    sprintf('%.12g', result.ActualWindow(2)); ...
                    sprintf('%d', size(result.Samples, 1))}];
            else
                error('StatisticsExperimentMath:InvalidResult', ...
                    'Statistics 仅支持 simulation 或 audio 结果。');
            end
            for channel = 1:size(result.Samples, 2)
                if strcmp(result.Kind, 'simulation')
                    prefix = 'Sum';
                else
                    prefix = sprintf('Channel%d', channel);
                end
                names = {'Mean', 'Variance', 'Std', 'RMS'};
                for k = 1:numel(names)
                    keys{end + 1, 1} = [prefix '_' names{k}]; %#ok<AGROW>
                    vector = result.Statistics.(names{k});
                    values{end + 1, 1} = sprintf('%.12g', vector(channel)); %#ok<AGROW>
                end
            end
            summary = table(string(keys), string(values), ...
                'VariableNames', {'Statistic', 'Value'});
        end

        function styleExportAxes(ax)
            ax.FontName = 'Arial';
            ax.FontSize = 11;
            ax.LineWidth = 0.8;
            ax.Box = 'on';
            ax.XGrid = 'on';
            ax.YGrid = 'on';
            ax.GridAlpha = 0.12;
        end

        function drawDensity(ax, result, channel, color)
            edges = result.BinEdges;
            histogram(ax, 'BinEdges', edges, ...
                'BinCounts', result.Plot.Density(:, channel), ...
                'Normalization', 'count', ...
                'FaceColor', color, 'FaceAlpha', 0.65, 'EdgeColor', 'none', ...
                'DisplayName', 'Empirical density');
            xlim(ax, [edges(1), edges(end)]);
        end

        function value = requirePositiveInteger(value, name, errorId)
            if ~(isnumeric(value) && isscalar(value) && isreal(value) && ...
                    isfinite(value) && value >= 1 && value == floor(value) && ...
                    value <= flintmax)
                error(errorId, '%s 必须是有限的正整数。', name);
            end
            value = double(value);
        end

        function value = requireFiniteRealScalar(value, name, errorId)
            if ~(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value))
                error(errorId, '%s 必须是有限实数标量。', name);
            end
            value = double(value);
        end

        function value = requirePositiveFiniteScalar(value, name, errorId)
            value = StatisticsExperimentMath.requireFiniteRealScalar(value, name, errorId);
            if value <= 0
                error(errorId, '%s 必须是有限正数。', name);
            end
        end

        function requireFiniteRealMatrix(value, name, errorId)
            if ~(isnumeric(value) && isreal(value) && ~isempty(value) && ...
                    ismatrix(value) && all(isfinite(value(:))))
                error(errorId, '%s 必须是非空、有限的实数向量或矩阵。', name);
            end
        end

        function edges = constantCountEdges(value, binCount)
            % Keep the interval finite even for constants near realmax.
            scale = min(max(abs(value), 1), realmax / 4);
            halfSpan = sqrt(eps) * scale;
            if value > 0 && value > realmax - halfSpan
                lower = value - 2 * halfSpan;
                upper = value;
            elseif value < 0 && value < -realmax + halfSpan
                lower = value;
                upper = value + 2 * halfSpan;
            else
                lower = value - halfSpan;
                upper = value + halfSpan;
            end
            edges = linspace(lower, upper, binCount + 1);
            if any(~isfinite(edges)) || any(diff(edges) <= 0)
                error('StatisticsExperimentMath:UnrepresentableDensityEdges', ...
                    '无法为该常量数据构造有限且严格递增的分箱边界。');
            end
        end

        function edges = edgesForWidth(dataMinimum, dataMaximum, binWidth, maxBins)
            if dataMinimum == dataMaximum
                right = dataMinimum + binWidth;
                left = dataMinimum - binWidth;
                tolerance = 8 * eps(max([1, abs(dataMinimum), binWidth]));
                if isfinite(right) && right > dataMinimum && abs((right - dataMinimum) - binWidth) <= tolerance
                    edges = [dataMinimum, right];
                elseif isfinite(left) && left < dataMinimum && abs((dataMinimum - left) - binWidth) <= tolerance
                    edges = [left, dataMinimum];
                else
                    error('StatisticsExperimentMath:UnrepresentableDensityEdges', ...
                        '请求的分箱宽度在该常量数值附近无法用有限浮点边界精确表示。');
                end
                return;
            end

            dataRange = dataMaximum - dataMinimum;
            if isfinite(dataRange)
                ratio = dataRange / binWidth;
            else
                scale = max([abs(dataMinimum), abs(dataMaximum), binWidth]);
                scaledRange = dataMaximum / scale - dataMinimum / scale;
                scaledWidth = binWidth / scale;
                ratio = scaledRange / scaledWidth;
            end
            if ~isfinite(ratio) || ratio > maxBins
                error('StatisticsExperimentMath:TooManyDensityBins', ...
                    '请求的分箱宽度会产生超过 %d 个分箱；请增大宽度。', maxBins);
            end

            binCount = max(1, ceil(ratio));
            while binCount <= maxBins
                padding = binWidth * max(0, binCount - ratio);
                if ~isfinite(padding)
                    padding = 0;
                end
                start = dataMinimum - padding / 2;
                if ~isfinite(start)
                    start = dataMinimum;
                end

                edges = zeros(1, binCount + 1);
                edges(1) = start;
                for k = 2:numel(edges)
                    edges(k) = edges(k - 1) + binWidth;
                end
                if all(isfinite(edges)) && all(diff(edges) > 0) && ...
                        edges(1) <= dataMinimum && edges(end) >= dataMaximum
                    return;
                end
                binCount = binCount + 1;
            end
            error('StatisticsExperimentMath:UnrepresentableDensityEdges', ...
                '请求的分箱宽度无法表示为覆盖全部数据的有限边界。');
        end
    end
end
