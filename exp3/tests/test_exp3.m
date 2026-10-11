function tests = test_exp3
%TEST_EXP3 Focused numerical and validation tests for the exp3 service.
tests = functiontests(localfunctions);
end

function testDefaultsMatchUnnormalizedBroadsideGuide(testCase)
config = exp3_defaults();
result = exp3_pattern(config);

verifyFalse(testCase, config.Normalize);
verifyEqual(testCase, config.ElementCount, 8);
verifyEqual(testCase, result.AngleDegrees(1), 0);
verifyEqual(testCase, result.AngleDegrees(end), 360);
verifyEqual(testCase, result.RawMagnitude(901), 8, 'AbsTol', 1e-12);
verifyEqual(testCase, result.NormalizedMagnitude(901), 1, 'AbsTol', 1e-12);
verifyEqual(testCase, result.RelativeDb(901), 0, 'AbsTol', 1e-12);
verifySize(testCase, result.AngleRadians, [config.SampleCount 1]);
verifySize(testCase, result.CartesianValues, [config.SampleCount 1]);
end

function testSingleElementHasUnitMagnitudeAtEveryAngle(testCase)
config = exp3_defaults();
config.ElementCount = 1;
config.SampleCount = 361;
result = exp3_pattern(config);

verifyEqual(testCase, result.RawMagnitude, ones(361, 1), 'AbsTol', 1e-12);
verifyEqual(testCase, result.NormalizedMagnitude, ones(361, 1), 'AbsTol', 1e-12);
end

function testAnalyticNullForEightElements(testCase)
config = exp3_defaults();
config.SampleCount = 361;
result = exp3_pattern(config);

% For d/lambda=0.5 and broadside steering, phi=60 degrees gives q=pi/4;
% N*q=2*pi for N=8, so the numerator is zero while the denominator is not.
verifyEqual(testCase, result.RawMagnitude(61), 0, 'AbsTol', 1e-12);
end

function testRemovableSingularityPreservesGratingLobeMaximum(testCase)
config = exp3_defaults();
config.SpacingMeters = 1;
config.SampleCount = 361;
result = exp3_pattern(config);

% At phi=180 degrees, q=-pi. The limiting magnitude is N even though the
% direct quotient is 0/0; this is the endfire grating lobe for d=lambda.
verifyEqual(testCase, result.RawMagnitude(181), config.ElementCount, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, all(isfinite(result.RawMagnitude)));
end

function testBroadsideSymmetry(testCase)
config = exp3_defaults();
config.SampleCount = 361;
result = exp3_pattern(config);

verifyEqual(testCase, result.RawMagnitude(31), result.RawMagnitude(331), ...
    'AbsTol', 1e-12);
verifyEqual(testCase, result.RawMagnitude(91), result.RawMagnitude(271), ...
    'AbsTol', 1e-12);
end

function testSteeringPeakAndNormalizedValues(testCase)
config = exp3_defaults();
config.SteeringAngleDeg = 45;
config.SampleCount = 361;
config.Normalize = true;
config.CartesianScale = 'linear';
result = exp3_pattern(config);

verifyEqual(testCase, result.RawMagnitude(46), config.ElementCount, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, result.CartesianValues(46), 1, 'AbsTol', 1e-12);
verifyEqual(testCase, result.PolarMagnitude(46), 1, 'AbsTol', 1e-12);
end

function testDbScaleUsesPeakReferencedValuesAndConfiguredFloor(testCase)
config = exp3_defaults();
config.CartesianScale = 'db';
config.DecibelFloor = -25;
config.SampleCount = 361;
result = exp3_pattern(config);

verifyEqual(testCase, result.CartesianValues, result.RelativeDb);
verifyEqual(testCase, max(result.RelativeDb), 0, 'AbsTol', 1e-12);
verifyGreaterThanOrEqual(testCase, min(result.RelativeDb), -25);
end

function testPartialConfigUsesDefaults(testCase)
result = exp3_pattern(struct('ElementCount', 4));

verifyEqual(testCase, result.Config.ElementCount, 4);
verifyEqual(testCase, result.Config.SpacingMeters, 0.5);
verifyEqual(testCase, result.Config.SteeringAngleDeg, 90);
end

function testRejectsInvalidElementCount(testCase)
config = exp3_defaults();
config.ElementCount = 2.5;
verifyError(testCase, @() exp3_pattern(config), ...
    'exp3_pattern:InvalidInteger');

config.ElementCount = 513;
verifyError(testCase, @() exp3_pattern(config), ...
    'exp3_pattern:InvalidInteger');
end

function testRejectsInvalidRangeAndScale(testCase)
config = exp3_defaults();
config.AngleStartDeg = 200;
config.AngleEndDeg = 100;
verifyError(testCase, @() exp3_pattern(config), ...
    'exp3_pattern:InvalidAngleRange');

config = exp3_defaults();
config.CartesianScale = 'log';
verifyError(testCase, @() exp3_pattern(config), ...
    'exp3_pattern:InvalidScale');
end

function testRejectsUnknownFieldsAndNonFiniteValues(testCase)
config = exp3_defaults();
config.Unexpected = 1;
verifyError(testCase, @() exp3_pattern(config), ...
    'exp3_pattern:UnknownConfigField');

config = exp3_defaults();
config.WavelengthMeters = Inf;
verifyError(testCase, @() exp3_pattern(config), ...
    'exp3_pattern:InvalidNumericValue');
end

function testRejectsUnrepresentableSpacingRatio(testCase)
config = exp3_defaults();
config.SpacingMeters = 1e9;
config.WavelengthMeters = 1e-3;
verifyError(testCase, @() exp3_pattern(config), ...
    'exp3_pattern:InvalidSpacingRatio');
end
