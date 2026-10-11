function tests = test_exp2
%TEST_EXP2 Numerical checks for the GUI-free root-finding API.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
exp2Folder = fileparts(fileparts(mfilename('fullpath')));
existingPaths = strsplit(path, pathsep);
testCase.TestData.addedExp2Path = ~any(strcmp(existingPaths, exp2Folder));
if testCase.TestData.addedExp2Path
    addpath(exp2Folder);
end
testCase.TestData.exp2Folder = exp2Folder;
end

function teardownOnce(testCase)
if testCase.TestData.addedExp2Path
    rmpath(testCase.TestData.exp2Folder);
end
end

function testPresetEquationsConvergeAndExposeVerificationRoots(testCase)
for presetIndex = 1:2
    result = exp2_solve(exp2_defaults(presetIndex));
    verifyTrue(testCase, result.newton.converged, result.newton.message);
    verifyTrue(testCase, result.bisection.converged, result.bisection.message);
    verifyLessThanOrEqual(testCase, result.newton.residual, 1e-10);
    nearestRootError = min(abs(result.bisection.x - result.verificationRoots));
    permittedError = result.config.xTolerance * ...
        max(1, abs(result.bisection.x)) + 5e-12;
    verifyLessThanOrEqual(testCase, nearestRootError, permittedError);
    verifyEqual(testCase, numel(result.verificationRoots), ...
        numel(result.coefficients) - 1);
end
end

function testKnownCubicRoots(testCase)
result = exp2_solve(exp2_defaults(2));
actual = sort(real(result.verificationRoots));
verifyEqual(testCase, actual, [1; 2; 5], 'AbsTol', 1e-9);
verifyLessThan(testCase, max(result.verificationResiduals), 1e-9);
end

function testBisectionAcceptsEndpointRoot(testCase)
f = @(x) (x - 1) .* (x + 2);
result = bisect_root(f, [1 4]);
verifyTrue(testCase, result.converged);
verifyEqual(testCase, result.x, 1, 'AbsTol', 0);
verifyEqual(testCase, result.iterations, 0);
verifyEqual(testCase, result.history(1).iteration, 0);
end

function testBisectionRejectsSameSignInterval(testCase)
result = bisect_root(@(x) x.^2 + 1, [0 2], struct());
verifyFalse(testCase, result.converged);
verifyEqual(testCase, result.status, 'invalid-bracket');
end

function testNewtonSupportsComplexInitialPoint(testCase)
f = @(x) x.^2 + 1;
df = @(x) 2 .* x;
options = struct('xTolerance', 1e-12, ...
    'residualTolerance', 1e-12, 'maxIterations', 50);
result = newton_root(f, df, 1 + 1i, options);
verifyTrue(testCase, result.converged, result.message);
verifyLessThan(testCase, abs(result.x - 1i), 1e-10);
verifyLessThan(testCase, result.residual, 1e-12);
end

function testNewtonReportsZeroDerivative(testCase)
result = newton_root(@(x) x.^2 + 1, @(x) 2 .* x, 0, struct());
verifyFalse(testCase, result.converged);
verifyEqual(testCase, result.status, 'derivative-zero');
end

function testNewtonReportsIterationLimit(testCase)
options = struct('xTolerance', 1e-15, ...
    'residualTolerance', 1e-15, 'maxIterations', 1);
result = newton_root(@(x) x.^2 - 2, @(x) 2 .* x, 10, options);
verifyFalse(testCase, result.converged);
verifyEqual(testCase, result.status, 'max-iterations');
verifyEqual(testCase, result.iterations, 1);
end

function testOneMethodFailurePreservesOtherResult(testCase)
config = exp2_defaults(2);
config.bracket = [0 0.5];
result = exp2_solve(config);
verifyTrue(testCase, result.newton.converged, result.newton.message);
verifyFalse(testCase, result.bisection.converged);
verifyEqual(testCase, result.bisection.status, 'invalid-bracket');
end

function testMalformedCoefficientsAreRejected(testCase)
config = exp2_defaults();
config.coefficients = [0 0 0];
verifyError(testCase, @() exp2_solve(config), 'exp2:InvalidCoefficients');
end

function testEditedPresetCoefficientsGetCustomFormula(testCase)
defaults = exp2_defaults(2);
config = defaults;
config.coefficients = [1 -3 2];
result = exp2_solve(config);
verifyEqual(testCase, result.equationName, '自定义多项式');
verifyNotEqual(testCase, result.formula, defaults.formula);
end
