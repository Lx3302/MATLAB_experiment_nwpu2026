function tests = test_backend_services
%TEST_BACKEND_SERVICES Tests for the app-independent experiment services.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
sourceDirectory = projectRoot;
testCase.TestData.OriginalPath = path;
addpath(sourceDirectory);
testCase.TestData.SourceDirectory = sourceDirectory;
end

function teardownOnce(testCase)
path(testCase.TestData.OriginalPath);
end

function setup(testCase)
outputDirectory = tempname;
mkdir(outputDirectory);
testCase.TestData.OutputDirectory = outputDirectory;
end

function teardown(testCase)
outputDirectory = testCase.TestData.OutputDirectory;
if isfolder(outputDirectory)
    rmdir(outputDirectory, 's');
end
end

function testRunSimulationBuildsNumericAndPlotSnapshot(testCase)
rng(31, 'twister');
result = StatisticsExperimentMath.runSimulation(2, 4000, 'count', 12);

verifyEqual(testCase, result.Kind, 'simulation');
verifySize(testCase, result.Samples, [4000 1]);
verifyEqual(testCase, [result.Summands result.Trials], [2 4000]);
verifyEqual(testCase, result.TheoreticalMean, 1);
verifyEqual(testCase, result.TheoreticalVariance, 1 / 6, 'AbsTol', 1e-14);
verifyEqual(testCase, result.BinMode, 'count');
verifySize(testCase, result.BinEdges, [1 13]);
verifySize(testCase, result.Plot.Density, [12 1]);
verifySize(testCase, result.Plot.FitX, [800 1]);
verifySize(testCase, result.Plot.FitDensity, [800 1]);
verifySize(testCase, result.Plot.TheoryDensity, [800 1]);
verifyEqual(testCase, sum(result.Plot.Density .* diff(result.BinEdges).'), ...
    1, 'AbsTol', 1e-12);
verifyLessThan(testCase, abs(result.Statistics.Mean - 1), 0.025);
verifyEmpty(testCase, intersect(fieldnames(result), {'App', 'UIFigure', 'UIAxes'}));

singleTrial = StatisticsExperimentMath.runSimulation(1, 1, 'count', 3);
verifyTrue(testCase, all(isnan(singleTrial.Plot.FitDensity), 'all'));
verifyTrue(testCase, all(isfinite(singleTrial.Plot.TheoryDensity)));
end

function testReadAudioAndPreviewRetainChannelAndTimeMetadata(testCase)
fixture = writeFixture(testCase);
audio = StatisticsExperimentMath.readAudio(fixture);

verifySize(testCase, audio.Samples, [16 2]);
verifyEqual(testCase, audio.OriginalChannels, 3);
verifyEqual(testCase, audio.SampleRate, 8);
verifyEqual(testCase, audio.Duration, 2);
verifyEqual(testCase, audio.SourceFile, 'three_channel.wav');
verifyTrue(testCase, isfile(audio.SourcePath));

preview = StatisticsExperimentMath.previewAudio(audio, 0.25, 1.0, 4);
verifyEqual(testCase, preview.ActualWindow, [0.25 1.0], 'AbsTol', 1e-12);
verifyEqual(testCase, preview.SampleCount, 6);
verifyNumElements(testCase, preview.Waveforms, 2);
verifyLessThanOrEqual(testCase, numel(preview.Waveforms(1).Time), 4);
verifyEqual(testCase, preview.Waveforms(1).Time, preview.Waveforms(2).Time);
verifyEqual(testCase, [preview.Waveforms.ChannelCount], [2 2]);
verifyEqual(testCase, preview.Waveforms(1).Time(1), 0.25, 'AbsTol', 1e-12);
verifyLessThan(testCase, preview.Waveforms(1).Time(end), 1.0);
end

function testAnalyzeAudioUsesHalfOpenWindowAndProvidesPerChannelPlots(testCase)
audio = StatisticsExperimentMath.readAudio(writeFixture(testCase));
result = StatisticsExperimentMath.analyzeAudio(audio, 0.25, 1.0, 'width', 0.1);
expectedSamples = audio.Samples(3:8, :);

verifyEqual(testCase, result.Kind, 'audio');
verifyEqual(testCase, result.Samples, expectedSamples);
verifyEqual(testCase, result.SampleIndices, [3 8]);
verifyEqual(testCase, result.RequestedWindow, [0.25 1.0]);
verifyEqual(testCase, result.ActualWindow, [0.25 1.0], 'AbsTol', 1e-12);
verifyEqual(testCase, result.Time, (2:7).' / 8, 'AbsTol', 1e-12);
verifyEqual(testCase, result.Statistics.Variance, var(expectedSamples, 0, 1), ...
    'AbsTol', 1e-14);
verifySize(testCase, result.Plot.Density, ...
    [numel(result.BinEdges) - 1 2]);
verifySize(testCase, result.Plot.FitX, [800 1]);
verifySize(testCase, result.Plot.FitDensity, [800 2]);
verifyTrue(testCase, all(isnan(result.Plot.FitDensity(:, 2))));
verifyNumElements(testCase, result.Waveforms, 2);
verifyEqual(testCase, result.Waveforms(1).Time, result.Time);
verifyEqual(testCase, result.Waveforms(1).Amplitude, result.Samples(:, 1));
verifyEqual(testCase, result.SourcePath, audio.SourcePath);
end

function testSaveResultWritesCompleteMatAndCsvFiles(testCase)
audio = StatisticsExperimentMath.readAudio(writeFixture(testCase));
result = StatisticsExperimentMath.analyzeAudio(audio, 0, 1.5, 'count', 8);
outputDirectory = testCase.TestData.OutputDirectory;
matPath = fullfile(outputDirectory, 'audio_result.mat');
csvPath = fullfile(outputDirectory, 'audio_result.csv');

matFiles = StatisticsExperimentMath.saveResult(result, matPath);
verifyEqual(testCase, matFiles, {matPath});
verifyTrue(testCase, isfile(matPath));
loaded = load(matPath, 'result');
verifyEqual(testCase, loaded.result, result);

csvFiles = StatisticsExperimentMath.saveResult(result, csvPath);
statisticsPath = fullfile(outputDirectory, 'audio_result_statistics.csv');
verifyEqual(testCase, csvFiles, {csvPath, statisticsPath});
verifyTrue(testCase, isfile(csvPath));
verifyTrue(testCase, isfile(statisticsPath));
sampleTable = readtable(csvPath);
verifyEqual(testCase, height(sampleTable), size(result.Samples, 1));
verifyEqual(testCase, width(sampleTable), 3);
verifyEqual(testCase, sampleTable.Time_seconds, result.Time, 'AbsTol', 1e-12);
summaryTable = readtable(statisticsPath);
verifyTrue(testCase, any(strcmp(string(summaryTable.Statistic), "VarianceNormalization")));
summaryCells = readcell(statisticsPath, 'TextType', 'string');
verifyTrue(testCase, any(strcmp(string(summaryCells(:, 2)), "N-1"), 'all'));
end

function testExportFigureOnlyDeletesItsOwnHiddenFigure(testCase)
rng(7, 'twister');
result = StatisticsExperimentMath.runSimulation(3, 2500, 'count', 20);
outputDirectory = testCase.TestData.OutputDirectory;
pngPath = fullfile(outputDirectory, 'simulation.png');
pdfPath = fullfile(outputDirectory, 'simulation.pdf');
otherFigure = figure('Visible', 'off');
cleanup = onCleanup(@() delete(otherFigure));

StatisticsExperimentMath.exportFigure(result, pngPath);
verifyTrue(testCase, isgraphics(otherFigure));
verifyTrue(testCase, isfile(pngPath));
verifyGreaterThan(testCase, dir(pngPath).bytes, 0);
StatisticsExperimentMath.exportFigure(result, pdfPath);
verifyTrue(testCase, isgraphics(otherFigure));
verifyTrue(testCase, isfile(pdfPath));
verifyGreaterThan(testCase, dir(pdfPath).bytes, 0);
end

function testSingleWideBinExportUsesExactNativeHistogramValuesAndEdges(testCase)
sampleRate = 8;
fixture = fullfile(testCase.TestData.OutputDirectory, 'constant.wav');
audiowrite(fixture, 0.25 .* ones(16, 1), sampleRate);
audio = StatisticsExperimentMath.readAudio(fixture);
result = StatisticsExperimentMath.analyzeAudio(audio, 0, 1.5, 'width', 0.5);

verifyEqual(testCase, result.BinEdges, [0.25 0.75], 'AbsTol', 1e-12);
verifyEqual(testCase, result.Plot.Density, 2, 'AbsTol', 1e-12);

fig = figure('Visible', 'off');
cleanup = onCleanup(@() delete(fig));
ax = axes('Parent', fig);
h = histogram(ax, 'BinEdges', result.BinEdges, ...
    'BinCounts', result.Plot.Density(:, 1), 'Normalization', 'count');
verifyEqual(testCase, h.Values, result.Plot.Density(:, 1), 'AbsTol', 1e-12);
verifyEqual(testCase, h.BinEdges, result.BinEdges, 'AbsTol', 1e-12);
verifyEqual(testCase, h.BinCounts, result.Plot.Density(:, 1), 'AbsTol', 1e-12);

pngPath = fullfile(testCase.TestData.OutputDirectory, 'single_wide_bin.png');
StatisticsExperimentMath.exportFigure(result, pngPath);
verifyTrue(testCase, isfile(pngPath));
verifyGreaterThan(testCase, dir(pngPath).bytes, 0);
end

function fixture = writeFixture(testCase)
sampleRate = 8;
time = (0:15).' / sampleRate;
samples = [0.5 .* sin(2 .* pi .* time), ...
    0.25 .* ones(size(time)), 0.15 .* cos(2 .* pi .* time)];
fixture = fullfile(testCase.TestData.OutputDirectory, 'three_channel.wav');
audiowrite(fixture, samples, sampleRate);
end
