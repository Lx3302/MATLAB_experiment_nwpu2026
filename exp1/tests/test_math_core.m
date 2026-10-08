function tests = test_math_core
%TEST_MATH_CORE Behavior tests for the app's reusable math helpers.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.OriginalPath = path;
addpath(fileparts(fileparts(mfilename('fullpath'))));
end

function teardownOnce(testCase)
path(testCase.TestData.OriginalPath);
end

function testSimulationShapeBoundsAndMoments(testCase)
rng(31, 'twister');
sums = StatisticsExperimentMath.simulate(4, 20000);
verifySize(testCase, sums, [20000, 1]);
verifyGreaterThanOrEqual(testCase, min(sums), 0);
verifyLessThanOrEqual(testCase, max(sums), 4);
verifyLessThan(testCase, abs(mean(sums) - 2), 0.025);
verifyLessThan(testCase, abs(var(sums, 0) - 1/3), 0.025);
end

function testSimulationRejectsInvalidAndExcessiveRequests(testCase)
verifyError(testCase, @() StatisticsExperimentMath.simulate(0, 10), ...
    'StatisticsExperimentMath:InvalidSimulationSize');
verifyError(testCase, @() StatisticsExperimentMath.simulate(2.5, 10), ...
    'StatisticsExperimentMath:InvalidSimulationSize');
verifyError(testCase, @() StatisticsExperimentMath.simulate(10001, 10000), ...
    'StatisticsExperimentMath:SimulationTooLarge');

rng(31, 'twister');
largeTermBlock = StatisticsExperimentMath.simulate(1000001, 1);
verifyGreaterThanOrEqual(testCase, largeTermBlock, 0);
verifyLessThanOrEqual(testCase, largeTermBlock, 1000001);
end

function testDensityEdgesCountModeUsesSharedRange(testCase)
data = [0 2; 10 4];
edges = StatisticsExperimentMath.densityEdges(data, 'count', 5);
verifySize(testCase, edges, [1, 6]);
verifyEqual(testCase, edges(1), 0);
verifyEqual(testCase, edges(end), 10);
verifyEqual(testCase, diff(edges), repmat(2, 1, 5), 'AbsTol', 1e-12);
end

function testDensityEdgesWidthModeKeepsRequestedWidth(testCase)
data = [0.13; 0.92];
requestedWidth = 0.2;
edges = StatisticsExperimentMath.densityEdges(data, 'width', requestedWidth);
verifyLessThanOrEqual(testCase, edges(1), min(data));
verifyGreaterThanOrEqual(testCase, edges(end), max(data));
verifyEqual(testCase, diff(edges), repmat(requestedWidth, 1, numel(edges) - 1), ...
    'AbsTol', 5e-15);
end

function testDensityEdgesHandleConstantAndZeroSignals(testCase)
zeroEdges = StatisticsExperimentMath.densityEdges(zeros(10, 1), 'count', 8);
constantEdges = StatisticsExperimentMath.densityEdges(ones(10, 2) * 7, 'count', 4);
verifyTrue(testCase, all(isfinite(zeroEdges)) && all(diff(zeroEdges) > 0));
verifyTrue(testCase, all(isfinite(constantEdges)) && all(diff(constantEdges) > 0));
verifyEqual(testCase, numel(zeroEdges), 9);
verifyEqual(testCase, numel(constantEdges), 5);
verifyError(testCase, @() StatisticsExperimentMath.densityEdges(1:10, 'count', 5001), ...
    'StatisticsExperimentMath:TooManyDensityBins');
verifyError(testCase, @() StatisticsExperimentMath.densityEdges([0; 1], 'width', 1e-4), ...
    'StatisticsExperimentMath:TooManyDensityBins');
end

function testWindowUsesHalfOpenEndpoints(testCase)
[i1, i2] = StatisticsExperimentMath.windowIndices(0.25, 0.75, 4, 4);
verifyEqual(testCase, [i1, i2], [2, 3]);
[i1, i2] = StatisticsExperimentMath.windowIndices(0, 1, 4, 4);
verifyEqual(testCase, [i1, i2], [1, 4]);
[i1, i2] = StatisticsExperimentMath.windowIndices(0, 1 + eps(1), 4, 4);
verifyEqual(testCase, [i1, i2], [1, 4]);
end

function testWindowRejectsInvalidAndTooShortIntervals(testCase)
verifyError(testCase, @() StatisticsExperimentMath.windowIndices(-0.1, 0.5, 4, 4), ...
    'StatisticsExperimentMath:InvalidWindow');
verifyError(testCase, @() StatisticsExperimentMath.windowIndices(0, 1.1, 4, 4), ...
    'StatisticsExperimentMath:InvalidWindow');
verifyError(testCase, @() StatisticsExperimentMath.windowIndices(0, 0.25, 4, 4), ...
    'StatisticsExperimentMath:WindowTooShort');
end

function testSummaryUsesSampleVarianceAndTrueRms(testCase)
data = [1 2; 2 4; 3 8];
stats = StatisticsExperimentMath.summarize(data);
verifyEqual(testCase, stats.Mean, [2 14/3], 'AbsTol', 1e-12);
verifyEqual(testCase, stats.Variance, [1 28/3], 'AbsTol', 1e-12);
verifyEqual(testCase, stats.Std, sqrt([1 28/3]), 'AbsTol', 1e-12);
verifyEqual(testCase, stats.RMS, [sqrt(14/3), sqrt(84/3)], 'AbsTol', 1e-12);
verifyEqual(testCase, stats.Count, [3 3]);

single = StatisticsExperimentMath.summarize(5);
verifyEqual(testCase, single.Variance, 0);
verifyEqual(testCase, single.RMS, 5);
end

function testNormalDensityIsAnalyticAndHandlesZeroSigma(testCase)
x = [-1, 0, 1];
density = StatisticsExperimentMath.normalDensity(x, 0, 1);
verifyEqual(testCase, density, exp(-0.5 .* x.^2) ./ sqrt(2*pi), 'AbsTol', 1e-14);
verifyEmpty(testCase, StatisticsExperimentMath.normalDensity(x, 0, 0));
verifyError(testCase, @() StatisticsExperimentMath.normalDensity(x, 0, -1), ...
    'StatisticsExperimentMath:InvalidNormalInput');
end

function testWaveformPreviewRetainsChronologicalChannelExtrema(testCase)
data = zeros(100, 2);
data(3, 1) = -5;
data(8, 1) = 5;
data(4, 2) = -8;
data(7, 2) = 8;
[t, preview] = StatisticsExperimentMath.waveformPreview(data, 10, 4);
indices = round(t * 10) + 1;
verifyEqual(testCase, indices, [3; 4; 7; 8]);
verifyEqual(testCase, preview, data(indices, :));
verifyLessThanOrEqual(testCase, numel(t), 4);
verifyEqual(testCase, min(preview(:, 1)), -5);
verifyEqual(testCase, max(preview(:, 1)), 5);
verifyEqual(testCase, min(preview(:, 2)), -8);
verifyEqual(testCase, max(preview(:, 2)), 8);
end

function testWaveformPreviewReturnsOriginalWhenUnderLimit(testCase)
data = reshape(1:12, 6, 2);
[t, preview] = StatisticsExperimentMath.waveformPreview(data, 2, 10);
verifyEqual(testCase, t, (0:5).' / 2);
verifyEqual(testCase, preview, data);
end

function testWaveformPreviewRejectsImpossibleLimit(testCase)
verifyError(testCase, @() StatisticsExperimentMath.waveformPreview(zeros(10, 3), 10, 5), ...
    'StatisticsExperimentMath:PreviewLimitTooSmall');
end
