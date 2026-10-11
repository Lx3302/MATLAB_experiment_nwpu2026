function result = newton_root(f, df, initialX, options)
%NEWTON_ROOT Newton iteration for a scalar function, including complex x.
%   RESULT = NEWTON_ROOT(F, DF, X0, OPTIONS) records the initial point and
%   every completed step. Success requires a finite residual within the
%   requested tolerance. A small step with a large residual is stagnation.

validateFunction(f, 'f');
validateFunction(df, 'df');
if nargin < 4
    options = struct();
end
options = normalizeOptions(options);
if ~isFiniteScalar(initialX)
    error('exp2:InvalidInitialPoint', '初始点必须是有限数值标量。');
end

result = makeResult();
x = double(initialX);
[fx, ok, message] = evaluateScalar(f, x);
if ~ok
    result.status = 'evaluation-error';
    result.message = message;
    return;
end

residual = abs(fx);
result.x = x;
result.fValue = fx;
result.residual = residual;
result.history(1) = historyRow(0, x, fx, residual, NaN);
if residual <= options.residualTolerance
    result.converged = true;
    result.status = 'converged';
    result.message = '初始点的函数残差已满足容差。';
    return;
end

for iteration = 1:options.maxIterations
    [derivative, ok, message] = evaluateScalar(df, x);
    if ~ok
        result.status = 'evaluation-error';
        result.message = ['导数求值失败：' message];
        return;
    end
    if derivative == 0
        result.status = 'derivative-zero';
        result.message = '当前点导数为零，无法继续迭代。';
        return;
    end

    step = fx ./ derivative;
    nextX = x - step;
    if ~isFiniteScalar(nextX)
        result.status = 'nonfinite-value';
        result.message = '迭代点变成了非有限值。';
        return;
    end
    [nextF, ok, message] = evaluateScalar(f, nextX);
    if ~ok
        result.status = 'evaluation-error';
        result.message = ['函数求值失败：' message];
        return;
    end

    nextResidual = abs(nextF);
    stepSize = abs(nextX - x);
    result.history(end + 1) = historyRow( ...
        iteration, nextX, nextF, nextResidual, stepSize); %#ok<AGROW>
    result.iterations = iteration;
    result.x = nextX;
    result.fValue = nextF;
    result.residual = nextResidual;
    if nextResidual <= options.residualTolerance
        result.converged = true;
        result.status = 'converged';
        result.message = '函数残差已满足容差。';
        return;
    end
    if stepSize <= options.xTolerance * max(1, abs(nextX))
        result.status = 'stagnated';
        result.message = '迭代步长已达到相对容差，但函数残差仍未达标。';
        return;
    end

    x = nextX;
    fx = nextF;
end

result.status = 'max-iterations';
result.message = '达到最大迭代次数，函数残差仍未满足容差。';
end

function result = makeResult()
result = struct( ...
    'method', 'Newton', ...
    'x', NaN, ...
    'fValue', NaN, ...
    'residual', Inf, ...
    'iterations', 0, ...
    'converged', false, ...
    'status', 'not-started', ...
    'message', '', ...
    'history', repmat(historyRow(0, NaN, NaN, NaN, NaN), 0, 1));
end

function row = historyRow(iteration, x, fValue, residual, step)
row = struct( ...
    'iteration', iteration, ...
    'x', x, ...
    'fValue', fValue, ...
    'residual', residual, ...
    'step', step, ...
    'lower', NaN, ...
    'upper', NaN);
end

function validateFunction(value, label)
if ~isa(value, 'function_handle')
    error('exp2:InvalidFunctionHandle', '%s 必须是函数句柄。', label);
end
end

function options = normalizeOptions(options)
if nargin < 1 || isempty(options)
    options = struct();
end
if ~isstruct(options) || ~isscalar(options)
    error('exp2:InvalidOptions', 'options 必须是标量结构体。');
end
if ~isfield(options, 'xTolerance')
    options.xTolerance = 1e-10;
end
if ~isfield(options, 'residualTolerance')
    options.residualTolerance = 1e-10;
end
if ~isfield(options, 'maxIterations')
    options.maxIterations = 100;
end
if ~isPositiveFinite(options.xTolerance) || ...
        ~isPositiveFinite(options.residualTolerance)
    error('exp2:InvalidOptions', '相对容差和残差容差必须是正有限数值。');
end
if ~(isnumeric(options.maxIterations) && isscalar(options.maxIterations) && ...
        isreal(options.maxIterations) && isfinite(options.maxIterations) && ...
        options.maxIterations >= 1 && options.maxIterations == fix(options.maxIterations))
    error('exp2:InvalidOptions', '最大迭代次数必须是正整数。');
end
options.maxIterations = double(options.maxIterations);
end

function [value, ok, message] = evaluateScalar(fun, x)
try
    value = fun(x);
catch exception
    value = NaN;
    ok = false;
    message = exception.message;
    return;
end
if ~(isnumeric(value) && isscalar(value) && isFiniteScalar(value))
    value = NaN;
    ok = false;
    message = '函数必须返回有限数值标量。';
    return;
end
value = double(value);
ok = true;
message = '';
end

function tf = isPositiveFinite(value)
tf = isnumeric(value) && isscalar(value) && isreal(value) && ...
    ~isnan(value) && ~isinf(value) && value > 0;
end

function tf = isFiniteScalar(value)
tf = isnumeric(value) && isscalar(value) && ...
    ~isnan(real(value)) && ~isinf(real(value)) && ...
    ~isnan(imag(value)) && ~isinf(imag(value));
end
