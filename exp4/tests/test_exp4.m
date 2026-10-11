function tests = test_exp4
%TEST_EXP4 Unit tests for the experiment 4 analysis core.
tests = functiontests(localfunctions);
end

function testDiscreteGuideDenominatorPolesAndStability(testCase)
config = exp4_defaults('discrete');
config.symbolic = false;
result = exp4_analyze(config);
expectedPoles = roots(config.denominator);
verifyEqual(testCase, sortComplex(result.poles), sortComplex(expectedPoles), 'AbsTol', 1e-10);
verifyEqual(testCase, result.stability.isStable, ...
    all(abs(expectedPoles) < 1 - config.stabilityTolerance));
verifyEqual(testCase, result.stability.classification, 'unstable');
verifyEqual(testCase, result.zDenominatorPolynomial, config.denominator, 'AbsTol', 1e-12);
end

function testDefaultContinuousPolesAreRetained(testCase)
config = exp4_defaults('continuous');
config.symbolic = false;
result = exp4_analyze(config);
verifyEqual(testCase, sortComplex(result.poles), sortComplex([-1; -2; -3; -4]), 'AbsTol', 1e-10);
verifyTrue(testCase, result.stability.isStable);
verifyEqual(testCase, numel(result.poles), 4);
verifyEqual(testCase, result.impulse.numerical(1), 1, 'AbsTol', 1e-10);
% The printed numerator is not divisible by s+2; the raw denominator poles
% remain visible and are never cancelled by the analyzer.
verifyEqual(testCase, polyval(config.numerator, -2), -4, 'AbsTol', 1e-12);
end

function testDiscreteImpulseAndDelayConversion(testCase)
config = exp4_defaults('discrete');
config.numerator = [0, 1];
config.denominator = [1, -0.5];
config.sampleCount = 5;
config.frequencyPoints = 32;
config.symbolic = false;
result = exp4_analyze(config);
verifyEqual(testCase, result.impulse.numerical, [0; 1; 0.5; 0.25; 0.125], 'AbsTol', 1e-12);
verifyEmpty(testCase, result.zeros);
verifyEqual(testCase, result.poles, 0.5, 'AbsTol', 1e-12);
verifyEqual(testCase, result.zNumeratorPolynomial, [0, 1]);
end

function testDefaultDiscreteKnownInitialSamples(testCase)
config = exp4_defaults('discrete');
config.sampleCount = 5;
config.symbolic = false;
result = exp4_analyze(config);
verifyEqual(testCase, result.impulse.numerical(1:3), ...
    [0.021; 0.031311; -0.055123299], 'AbsTol', 1e-10);
end

function testContinuousCompanionResponse(testCase)
config = exp4_defaults('continuous');
config.numerator = 1;
config.denominator = [1, 1];
config.frequencyMax = 10;
config.sampleCount = 3;
config.maxTime = 1;
config.symbolic = false;
result = exp4_analyze(config);
verifyEqual(testCase, result.impulse.numerical, exp(-result.impulse.axis), 'AbsTol', 1e-11);
verifyEqual(testCase, result.impulse.deltaWeight, 0);
end

function testCommonPoleZeroIsNotCancelled(testCase)
config = exp4_defaults('continuous');
config.numerator = [1, 1];
config.denominator = [1, 3, 2];
config.frequencyMax = 10;
config.sampleCount = 10;
config.symbolic = false;
result = exp4_analyze(config);
verifyEqual(testCase, numel(result.zeros), 1);
verifyEqual(testCase, numel(result.poles), 2);
verifyTrue(testCase, any(abs(result.poles + 1) < 1e-10));
verifyTrue(testCase, result.stability.isStable);
end

function testStrictBoundaryStability(testCase)
discrete = exp4_defaults('discrete');
discrete.numerator = 1;
discrete.denominator = [1, -1];
discrete.frequencyMin = 0;
discrete.frequencyMax = pi;
discrete.frequencyPoints = 16;
discrete.sampleCount = 8;
discrete.symbolic = false;
resultD = exp4_analyze(discrete);
verifyFalse(testCase, resultD.stability.isStable);
verifyEqual(testCase, resultD.stability.classification, 'boundary');
verifyTrue(testCase, isnan(resultD.frequency.magnitudeDb(1)));

continuous = exp4_defaults('continuous');
continuous.numerator = 1;
continuous.denominator = [1, 0];
continuous.frequencyMax = 10;
continuous.sampleCount = 8;
continuous.symbolic = false;
resultC = exp4_analyze(continuous);
verifyFalse(testCase, resultC.stability.isStable);
verifyEqual(testCase, resultC.stability.classification, 'boundary');

discrete.denominator = [1, -3, 2]; % poles at 1 and 2
resultMixedD = exp4_analyze(discrete);
verifyEqual(testCase, resultMixedD.stability.classification, 'unstable');

continuous.denominator = [1, -1, 0]; % poles at 1 and 0
resultMixedC = exp4_analyze(continuous);
verifyEqual(testCase, resultMixedC.stability.classification, 'unstable');
end

function testContinuousUnstableAndNonProperHandling(testCase)
config = exp4_defaults('continuous');
config.numerator = 1;
config.denominator = [1, -1];
config.frequencyMax = 10;
config.sampleCount = 8;
config.symbolic = false;
result = exp4_analyze(config);
verifyFalse(testCase, result.stability.isStable);
verifyEqual(testCase, result.stability.classification, 'unstable');

config.numerator = [1, 0, 0];
verifyError(testCase, @() exp4_analyze(config), 'exp4:NonProperContinuousSystem');
end

function testSymbolicOptionRequiresFiniteBooleanScalar(testCase)
config = exp4_defaults('continuous');
config.symbolic = [true, false];
verifyError(testCase, @() exp4_analyze(config), 'exp4:InvalidSymbolicOption');
config.symbolic = NaN;
verifyError(testCase, @() exp4_analyze(config), 'exp4:InvalidSymbolicOption');
end

function testContinuousLeadingZerosAreTrimmed(testCase)
config = exp4_defaults('continuous');
config.numerator = [0, 1];
config.denominator = [0, 1, 1];
config.frequencyMax = 10;
config.sampleCount = 5;
config.symbolic = false;
result = exp4_analyze(config);
verifyEqual(testCase, result.numerator, 1);
verifyEqual(testCase, result.denominator, [1, 1]);
verifyEqual(testCase, result.poles, -1, 'AbsTol', 1e-12);
end

function testSymbolicComparisonWhenAvailable(testCase)
config = exp4_defaults('continuous');
config.sampleCount = 40;
config.maxTime = 2;
config.symbolic = true;
result = exp4_analyze(config);
if result.symbolic.available
    verifyTrue(testCase, result.symbolic.success, result.symbolic.message);
    verifyLessThan(testCase, result.symbolic.maxAbsoluteError, 1e-5);
else
    verifyEqual(testCase, result.symbolic.status, 'unavailable');
end
end

function sorted = sortComplex(values)
values = values(:);
if isempty(values)
    sorted = values;
else
    [~, order] = sortrows([real(values), imag(values)], [1, 2]);
    sorted = values(order);
end
end
