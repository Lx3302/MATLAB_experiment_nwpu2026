function symbolic = exp4_symbolic_response(config, numericResult)
%EXP4_SYMBOLIC_RESPONSE Optional symbolic inverse Z/Laplace response.
% The numeric response remains available when the toolbox is absent, the
% requested symbolic transform fails, or its order exceeds the safe limit.

symbolic = struct('status', '', 'available', false, 'success', false, ...
    'comparisonPerformed', false, 'message', '', 'expression', '', ...
    'samples', [], 'maxAbsoluteError', NaN, 'rmse', NaN);

[available, unavailableStatus, unavailableMessage] = symbolicAvailability();
if ~available
    symbolic.status = unavailableStatus;
    symbolic.message = unavailableMessage;
    return;
end
symbolic.available = true;

b = double(config.numerator(:).');
a = double(config.denominator(:).');
if strcmpi(char(string(config.domain)), 'discrete')
    b = trimTrailingZeros(b);
    a = trimTrailingZeros(a);
    transformOrder = max(numel(b), numel(a)) - 1;
else
    b = trimLeadingZeros(b);
    a = trimLeadingZeros(a);
    transformOrder = max(numel(b), numel(a)) - 1;
end
if transformOrder > 16
    symbolic.status = 'skipped';
    symbolic.message = '符号变换仅对最高 16 阶模型运行；数值冲激响应仍可用。';
    return;
end

try
    if strcmpi(char(string(config.domain)), 'discrete')
        z = sym('z');
        n = sym('n');
        numerator = qPolynomial(b, z);
        denominator = qPolynomial(a, z);
        transfer = simplify(numerator / denominator);
        response = simplify(iztrans(transfer, z, n));
        if ~isempty(strfind(char(response), 'iztrans(')) %#ok<STREMP>
            error('exp4:SymbolicTransformUnevaluated', '逆 Z 变换未能化简为显式序列。');
        end
        symbolic.expression = char(response);
        sampleIndex = numericResult.impulse.axis(:).';
        values = double(subs(response, n, sym(sampleIndex)));
        symbolic.samples = expandToCount(values, numel(sampleIndex));
        numericValues = numericResult.impulse.numerical(:);
        compareAll = true;
    else
        s = sym('s');
        t = sym('t');
        b = trimLeadingZeros(b);
        a = trimLeadingZeros(a);
        numerator = descendingPolynomial(b, s);
        denominator = descendingPolynomial(a, s);
        transfer = simplify(numerator / denominator);

        direct = sym(0);
        if numel(a) == numel(b) && ~all(b == 0)
            direct = exactSymbolic(b(1)) / exactSymbolic(a(1));
        end
        regularTransfer = simplify(transfer - direct);
        regularResponse = simplify(ilaplace(regularTransfer, s, t));
        if ~isempty(strfind(char(regularResponse), 'ilaplace(')) %#ok<STREMP>
            error('exp4:SymbolicTransformUnevaluated', '逆 Laplace 变换未能化简为显式函数。');
        end
        if numericResult.impulse.deltaWeight ~= 0
            expression = direct * dirac(t) + regularResponse;
        else
            expression = regularResponse;
        end
        symbolic.expression = char(expression);

        sampleTime = numericResult.impulse.axis(:);
        values = zeros(size(sampleTime));
        zeroIndex = (sampleTime == 0);
        if any(zeroIndex)
            rightLimit = limit(regularResponse, t, 0, 'right');
            values(zeroIndex) = real(double(rightLimit));
        end
        positiveIndex = ~zeroIndex;
        if any(positiveIndex)
            values(positiveIndex) = vectorEvaluate(regularResponse, t, sampleTime(positiveIndex));
        end
        symbolic.samples = values;
        numericValues = numericResult.impulse.numerical(:);
        compareAll = true;
    end

    symbolic.samples = symbolic.samples(:);
    numericValues = numericValues(:);
    count = min(numel(symbolic.samples), numel(numericValues));
    if count ~= numel(numericValues) || ...
            any(~isFiniteNumber(symbolic.samples(1:count))) || ...
            any(~isFiniteNumber(numericValues(1:count)))
        symbolic.status = 'partial';
        symbolic.message = '符号表达式已求出，但样本不完整或包含非有限值，未报告对照误差。';
        return;
    end
    [symbolic.maxAbsoluteError, symbolic.rmse] = compareSamples( ...
        numericValues(1:count), symbolic.samples(1:count), compareAll);
    if ~isFiniteNumber(symbolic.maxAbsoluteError) || ~isFiniteNumber(symbolic.rmse)
        symbolic.status = 'partial';
        symbolic.message = '符号表达式已求出，但未能得到有限的数值对照误差。';
        return;
    end
    symbolic.status = 'success';
    symbolic.success = true;
    symbolic.comparisonPerformed = true;
    symbolic.message = sprintf('符号逆变换完成；与数值响应最大误差 %.3g，RMSE %.3g。', ...
        symbolic.maxAbsoluteError, symbolic.rmse);
catch exception
    symbolic.status = 'error';
    symbolic.success = false;
    symbolic.message = ['符号逆变换失败，数值响应仍可用：', exception.message];
end
end

function [tf, status, message] = symbolicAvailability()
hasSym = exist('sym', 'file') == 2 || exist('sym', 'class') == 8;
if ~hasSym
    tf = false;
    status = 'unavailable';
    message = '未检测到 Symbolic Math Toolbox；当前使用数值冲激响应。';
    return;
end
licenseOk = true;
try
    licenseOk = license('test', 'Symbolic_Toolbox');
catch
    % Presence of the symbolic functions is the fallback on older releases.
end
tf = logical(licenseOk);
if tf
    status = '';
    message = '';
else
    status = 'license_unavailable';
    message = '检测到符号工具箱，但当前会话没有可用许可证；数值冲激响应仍可用。';
end
end

function value = qPolynomial(coefficients, z)
value = sym(0);
for k = 1:numel(coefficients)
    value = value + exactSymbolic(coefficients(k)) .* z.^(-(k - 1));
end
end

function value = descendingPolynomial(coefficients, variable)
value = sym(0);
degree = numel(coefficients) - 1;
for k = 1:numel(coefficients)
    value = value + exactSymbolic(coefficients(k)) .* variable.^(degree - k + 1);
end
end

function value = exactSymbolic(number)
value = sym(sprintf('%.15g', number));
end

function values = vectorEvaluate(expression, variable, coordinates)
try
    values = double(subs(expression, variable, sym(coordinates(:).')));
catch
    responseFunction = matlabFunction(expression, 'Vars', variable);
    try
        values = responseFunction(coordinates(:).');
    catch
        values = arrayfun(responseFunction, coordinates(:).');
    end
end
values = expandToCount(real(values), numel(coordinates));
values = values(:);
end

function values = expandToCount(values, count)
values = values(:);
if isscalar(values) && count > 1
    values = repmat(values, count, 1);
end
end

function [maximum, rmse] = compareSamples(numericValues, symbolicValues, compareAll)
numericValues = numericValues(:);
symbolicValues = symbolicValues(:);
count = min(numel(numericValues), numel(symbolicValues));
if count == 0
    maximum = NaN;
    rmse = NaN;
    return;
end
if ~compareAll && count > 1
    indices = 2:count;
else
    indices = 1:count;
end
errors = abs(numericValues(indices) - symbolicValues(indices));
if isempty(errors) || any(~isFiniteNumber(errors))
    maximum = NaN;
    rmse = NaN;
else
    maximum = max(errors);
    rmse = sqrt(mean(errors.^2));
end
end

function coefficients = trimTrailingZeros(coefficients)
while numel(coefficients) > 1 && coefficients(end) == 0
    coefficients(end) = [];
end
end

function coefficients = trimLeadingZeros(coefficients)
firstNonzero = find(coefficients ~= 0, 1, 'first');
if isempty(firstNonzero)
    coefficients = 0;
else
    coefficients = coefficients(firstNonzero:end);
end
end

function tf = isFiniteNumber(value)
tf = ~isnan(value) & ~isinf(value);
end
