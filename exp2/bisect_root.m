function result = bisect_root(f, interval, options)
%BISECT_ROOT Bisection for a real-valued scalar function on a real interval.
%   RESULT = BISECT_ROOT(F, [A B], OPTIONS) reports bad intervals and
%   endpoint roots as normal method results. The history includes each
%   midpoint and the interval that produced it.

if ~isa(f, 'function_handle')
    error('exp2:InvalidFunctionHandle', 'f 必须是函数句柄。');
end
if nargin < 3
    options = struct();
end
options = normalizeOptions(options);
result = makeResult();

if ~(isnumeric(interval) && isreal(interval) && numel(interval) == 2 && ...
        allFinite(interval))
    result.status = 'invalid-bracket';
    result.message = '区间必须由两个有限实数端点组成。';
    return;
end
a = double(interval(1));
b = double(interval(2));
if a >= b
    result.status = 'invalid-bracket';
    result.message = '二分区间必须满足左端点小于右端点。';
    return;
end

[fa, ok, message] = evaluateReal(f, a);
if ~ok
    result.status = 'evaluation-error';
    result.message = ['左端点求值失败：' message];
    return;
end
[fb, ok, message] = evaluateReal(f, b);
if ~ok
    result.status = 'evaluation-error';
    result.message = ['右端点求值失败：' message];
    return;
end

if abs(fa) <= options.residualTolerance
    result = endpointResult(result, a, fa, '左端点已满足残差容差。');
    result.history(1) = historyRow(0, a, fa, abs(fa), 0, a, b);
    return;
end
if abs(fb) <= options.residualTolerance
    result = endpointResult(result, b, fb, '右端点已满足残差容差。');
    result.history(1) = historyRow(0, b, fb, abs(fb), 0, a, b);
    return;
end
if sign(fa) == sign(fb)
    result.status = 'invalid-bracket';
    result.message = '区间端点函数值同号，二分法无法保证根在区间内。';
    return;
end

for iteration = 1:options.maxIterations
    midpoint = a + (b - a) / 2;
    if midpoint == a || midpoint == b
        result.status = 'stagnated';
        result.message = '区间端点已无法继续浮点细分。';
        return;
    end
    [fm, ok, message] = evaluateReal(f, midpoint);
    if ~ok
        result.status = 'evaluation-error';
        result.message = ['中点求值失败：' message];
        return;
    end

    residual = abs(fm);
    halfWidth = (b - a) / 2;
    result.history(end + 1) = historyRow( ...
        iteration, midpoint, fm, residual, halfWidth, a, b); %#ok<AGROW>
    result.iterations = iteration;
    result.x = midpoint;
    result.fValue = fm;
    result.residual = residual;
    if residual <= options.residualTolerance || ...
            halfWidth <= options.xTolerance * max(1, abs(midpoint))
        result.converged = true;
        result.status = 'converged';
        result.message = '区间宽度或函数残差已满足容差。';
        return;
    end

    if sign(fm) == sign(fa)
        a = midpoint;
        fa = fm;
    else
        b = midpoint;
        fb = fm;
    end
end

result.status = 'max-iterations';
result.message = '达到最大迭代次数，区间宽度和函数残差仍未满足容差。';
end

function result = makeResult()
result = struct( ...
    'method', 'Bisection', ...
    'x', NaN, ...
    'fValue', NaN, ...
    'residual', Inf, ...
    'iterations', 0, ...
    'converged', false, ...
    'status', 'not-started', ...
    'message', '', ...
    'history', repmat(historyRow(0, NaN, NaN, NaN, NaN, NaN, NaN), 0, 1));
end

function row = historyRow(iteration, x, fValue, residual, step, lower, upper)
row = struct( ...
    'iteration', iteration, ...
    'x', x, ...
    'fValue', fValue, ...
    'residual', residual, ...
    'step', step, ...
    'lower', lower, ...
    'upper', upper);
end

function result = endpointResult(result, x, fx, message)
result.x = x;
result.fValue = fx;
result.residual = abs(fx);
result.converged = true;
result.status = 'converged';
result.message = message;
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

function [value, ok, message] = evaluateReal(fun, x)
try
    value = fun(x);
catch exception
    value = NaN;
    ok = false;
    message = exception.message;
    return;
end
if ~(isnumeric(value) && isscalar(value) && isreal(value) && ...
        ~isnan(value) && ~isinf(value))
    value = NaN;
    ok = false;
    message = '二分法要求函数返回有限实数标量。';
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

function tf = allFinite(values)
tf = all(~isnan(values(:)) & ~isinf(values(:)));
end
