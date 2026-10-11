function result = exp4_analyze(config)
%EXP4_ANALYZE Analyze a causal discrete- or continuous-time transfer function.
%   Discrete numerator and denominator vectors use ascending powers of z^-1.
%   Continuous vectors use descending powers of s. Pole-zero factors are not
%   cancelled: stability is judged from every pole in the entered denominator.

if nargin < 1 || ~isstruct(config)
    error('exp4:InvalidConfig', 'Provide a configuration structure.');
end
if ~isfield(config, 'domain')
    config.domain = 'continuous';
end
domain = lower(char(string(config.domain)));
if strcmp(domain, 'z')
    domain = 'discrete';
elseif strcmp(domain, 's')
    domain = 'continuous';
end
defaults = exp4_defaults(domain);
defaultFields = fieldnames(defaults);
for k = 1:numel(defaultFields)
    name = defaultFields{k};
    if ~isfield(config, name)
        config.(name) = defaults.(name);
    end
end
config.domain = domain;

if ~any(strcmp(domain, {'discrete', 'continuous'}))
    error('exp4:UnknownDomain', 'domain must be ''discrete'' or ''continuous''.');
end
if ~isnumeric(config.numerator) || isempty(config.numerator) || ...
        ~isnumeric(config.denominator) || isempty(config.denominator)
    error('exp4:InvalidCoefficients', 'Numerator and denominator must be nonempty numeric vectors.');
end
if ~isvector(config.numerator) || ~isvector(config.denominator)
    error('exp4:InvalidCoefficients', 'Enter each coefficient list as a vector.');
end
b = double(config.numerator(:).');
a = double(config.denominator(:).');
if any(~isFiniteNumber(b)) || any(~isFiniteNumber(a))
    error('exp4:InvalidCoefficients', 'Coefficients must be finite real numbers.');
end
if ~isreal(b) || ~isreal(a)
    error('exp4:InvalidCoefficients', 'Coefficients must be real numbers.');
end
if all(a == 0)
    error('exp4:ZeroDenominator', 'The denominator cannot be all zeros.');
end
config.numerator = b;
config.denominator = a;

config.stabilityTolerance = scalarInRange(config.stabilityTolerance, ...
    'stabilityTolerance', 0, 1);
config.frequencyMin = scalarInRange(config.frequencyMin, 'frequencyMin', 0, Inf);
config.frequencyMax = scalarInRange(config.frequencyMax, 'frequencyMax', 0, Inf);
config.frequencyPoints = integerInRange(config.frequencyPoints, 'frequencyPoints', 2, 200000);
config.sampleCount = integerInRange(config.sampleCount, 'sampleCount', 2, 200000);
if strcmp(domain, 'continuous')
    config.maxTime = scalarInRange(config.maxTime, 'maxTime', 0, Inf);
    if config.maxTime == 0
        error('exp4:InvalidTimeRange', 'Maximum time must be greater than zero.');
    end
else
    config.maxTime = defaults.maxTime;
end
symbolicIsLogical = islogical(config.symbolic) && isscalar(config.symbolic);
symbolicIsNumericBoolean = isnumeric(config.symbolic) && isscalar(config.symbolic) && ...
    isreal(config.symbolic) && isFiniteNumber(config.symbolic) && ...
    any(config.symbolic == [0, 1]);
if ~(symbolicIsLogical || symbolicIsNumericBoolean)
    error('exp4:InvalidSymbolicOption', 'symbolic must be a finite Boolean scalar (true/false or 0/1).');
end
config.symbolic = logical(config.symbolic);
if config.frequencyMax <= config.frequencyMin
    error('exp4:InvalidFrequencyRange', 'Maximum frequency must be greater than minimum frequency.');
end
if strcmp(domain, 'discrete') && config.frequencyMax > pi + 10*eps(pi)
    error('exp4:InvalidFrequencyRange', 'Discrete frequency limits must lie between 0 and pi rad/sample.');
end

result = struct();
result.config = config;
result.domain = domain;
result.originalNumerator = b;
result.originalDenominator = a;

if strcmp(domain, 'discrete')
    result = analyzeDiscrete(result, b, a);
else
    result = analyzeContinuous(result, b, a);
end

if config.symbolic
    result.symbolic = exp4_symbolic_response(config, result);
else
    result.symbolic = struct('status', 'disabled', 'available', false, ...
        'success', false, 'comparisonPerformed', false, ...
        'message', '符号响应已关闭。', 'expression', '', ...
        'samples', [], 'maxAbsoluteError', NaN, 'rmse', NaN);
end
end

function result = analyzeDiscrete(result, b, a)
% In q=z^-1 notation the first denominator coefficient must be nonzero for
% a causal recurrence. Leading zero numerator coefficients encode delay.
if a(1) == 0
    error('exp4:DiscreteDenominatorLeadingZero', ...
        'Discrete denominator a(1) must be nonzero; leading zero numerator coefficients are allowed as delays.');
end
b = trimTrailingZeros(b);
a = trimTrailingZeros(a);
a0 = a(1);
b = b ./ a0;
a = a ./ a0;
degreeB = numel(b) - 1;
degreeA = numel(a) - 1;
if max(degreeA, degreeB) > 64
    error('exp4:DegreeLimit', 'Discrete polynomial degree is limited to 64 for responsive analysis.');
end
commonDegree = max(degreeB, degreeA);
bz = [b, zeros(1, commonDegree - degreeB)];
az = [a, zeros(1, commonDegree - degreeA)];
result.numerator = b;
result.denominator = a;
result.zNumeratorPolynomial = bz;
result.zDenominatorPolynomial = az;
result.zeros = polynomialRoots(bz);
result.poles = polynomialRoots(az);
result.stability = classifyDiscrete(result.poles, result.config.stabilityTolerance);

omega = linspace(result.config.frequencyMin, result.config.frequencyMax, ...
    result.config.frequencyPoints).';
q = exp(-1i .* omega);
numValue = zeros(size(q));
denValue = zeros(size(q));
for k = 1:numel(b)
    numValue = numValue + b(k) .* q.^(k - 1);
end
for k = 1:numel(a)
    denValue = denValue + a(k) .* q.^(k - 1);
end
scale = max(1, sum(abs(a)));
singular = abs(denValue) <= 10 * eps(scale);
h = numValue ./ denValue;
h(singular) = complex(NaN, NaN);
magDb = 20 .* log10(abs(h));
magDb(isinf(magDb) & magDb > 0) = NaN;
result.frequency = struct('axis', omega, 'response', h, 'magnitudeDb', magDb, ...
    'axisLabel', 'ω (rad/sample)', 'title', '代数频率响应 |H(e^{jω})|', ...
    'singularMask', singular);
if result.stability.isStable
    result.frequency.note = '未约分分母极点均在单位圆内；频响按输入系数直接计算。';
else
    result.frequency.note = '显示 H(e^{jω}) 的代数取值；未约分分母判稳未通过，约分后的传递函数性质需另行判断。';
end
if any(singular)
    result.frequency.note = [result.frequency.note, ' 极点采样点已留空。'];
end

samples = result.config.sampleCount;
x = [1, zeros(1, samples - 1)];
y = filter(b, a, x);
result.impulse = struct('axis', (0:samples-1).', 'numerical', y(:), ...
    'axisLabel', 'n', 'title', '因果离散冲激响应', 'deltaWeight', 0, ...
    'regularResponseLabel', '数值响应');
end

function result = analyzeContinuous(result, b, a)
b = trimLeadingZeros(b);
a = trimLeadingZeros(a);
if isempty(a) || all(a == 0)
    error('exp4:ZeroDenominator', 'The denominator cannot be all zeros.');
end
a0 = a(1);
bIsZero = all(b == 0);
if bIsZero
    b = 0;
end
degreeA = numel(a) - 1;
degreeB = -Inf;
if ~bIsZero
    degreeB = numel(b) - 1;
end
if degreeA > 64 || degreeB > 64
    error('exp4:DegreeLimit', 'Continuous polynomial degree is limited to 64 for responsive analysis.');
end
if degreeB > degreeA
    error('exp4:NonProperContinuousSystem', ...
        'Continuous systems must be proper (numerator degree no greater than denominator degree).');
end
b = b ./ a0;
a = a ./ a0;
result.numerator = b;
result.denominator = a;
result.zeros = polynomialRoots(b);
result.poles = polynomialRoots(a);
result.stability = classifyContinuous(result.poles, result.config.stabilityTolerance);

omega = linspace(result.config.frequencyMin, result.config.frequencyMax, ...
    result.config.frequencyPoints).';
s = 1i .* omega;
numValue = polyval(b, s);
denValue = polyval(a, s);
scale = polyval(abs(a), abs(s));
scale(~isFiniteNumber(scale)) = realmax;
singular = abs(denValue) <= 10 .* eps(max(1, scale));
h = numValue ./ denValue;
h(singular) = complex(NaN, NaN);
magDb = 20 .* log10(abs(h));
magDb(isinf(magDb) & magDb > 0) = NaN;
result.frequency = struct('axis', omega, 'response', h, 'magnitudeDb', magDb, ...
    'axisLabel', 'ω (rad/s)', 'title', '代数频率响应 |H(jω)|', ...
    'singularMask', singular);
if result.stability.isStable
    result.frequency.note = '未约分分母极点均在左半平面；频响按输入系数直接计算。';
else
    result.frequency.note = '显示 H(jω) 的代数取值；未约分分母判稳未通过，约分后的传递函数性质需另行判断。';
end
if any(singular)
    result.frequency.note = [result.frequency.note, ' 极点采样点已留空。'];
end

time = linspace(0, result.config.maxTime, result.config.sampleCount).';
[regular, deltaWeight] = continuousImpulse(b, a, time);
result.impulse = struct('axis', time, 'numerical', regular, ...
    'axisLabel', 't (s)', 'title', '因果连续冲激响应（不含 δ(t) 图形）', ...
    'deltaWeight', deltaWeight, 'regularResponseLabel', '常规响应，不含 Dirac 项');
end

function [y, deltaWeight] = continuousImpulse(b, a, time)
order = numel(a) - 1;
if order == 0
    deltaWeight = b(1) / a(1);
    y = zeros(size(time));
    return;
end
beta = [zeros(1, numel(a) - numel(b)), b];
deltaWeight = beta(1);
residual = beta(2:end) - deltaWeight .* a(2:end);
% Controllable companion realization. Its input vector is e1 and the
% residual numerator coefficients are the output row.
A = [-a(2:end); eye(order - 1), zeros(order - 1, 1)];
B = zeros(order, 1);
B(1) = 1;
C = residual;
y = zeros(size(time));
state = B;
if numel(time) > 1
    transition = expm(A .* (time(2) - time(1)));
else
    transition = eye(order);
end
for k = 1:numel(time)
    y(k) = real(C * state);
    state = transition * state;
end
end

function stability = classifyDiscrete(poles, tolerance)
radii = abs(poles);
if isempty(radii)
    maxRadius = 0;
    margin = Inf;
else
    maxRadius = max(radii);
    margin = 1 - maxRadius;
end
isStable = all(radii < 1 - tolerance);
outside = any(radii > 1 + tolerance);
onBoundary = any(abs(radii - 1) <= tolerance);
if isStable
    classification = 'stable';
elseif outside
    classification = 'unstable';
elseif onBoundary
    classification = 'boundary';
else
    classification = 'unstable';
end
stability = struct('isStable', isStable, 'classification', classification, ...
    'margin', margin, 'maximumPoleRadius', maxRadius, ...
    'scope', 'raw_denominator_conservative', ...
    'criterion', '保守判据：所有原始分母极点满足 |p| < 1 - 容差；不自动约去公因子');
end

function stability = classifyContinuous(poles, tolerance)
realParts = real(poles);
if isempty(realParts)
    rightmost = -Inf;
    margin = Inf;
else
    rightmost = max(realParts);
    margin = -rightmost;
end
isStable = all(realParts < -tolerance);
outside = any(realParts > tolerance);
onBoundary = any(abs(realParts) <= tolerance);
if isStable
    classification = 'stable';
elseif outside
    classification = 'unstable';
elseif onBoundary
    classification = 'boundary';
else
    classification = 'unstable';
end
stability = struct('isStable', isStable, 'classification', classification, ...
    'margin', margin, 'rightmostPoleRealPart', rightmost, ...
    'scope', 'raw_denominator_conservative', ...
    'criterion', '保守判据：所有原始分母极点满足 Re(p) < -容差；不自动约去公因子');
end

function rootsOut = polynomialRoots(coefficients)
coefficients = coefficients(:).';
if isempty(coefficients) || all(coefficients == 0) || numel(coefficients) <= 1
    rootsOut = zeros(0, 1);
else
    rootsOut = roots(coefficients);
end
end

function coefficients = trimTrailingZeros(coefficients)
while numel(coefficients) > 1 && coefficients(end) == 0
    coefficients(end) = [];
end
if isempty(coefficients)
    coefficients = 0;
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

function value = scalarInRange(value, name, minimum, maximum)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isFiniteNumber(value)
    error('exp4:InvalidParameter', '%s must be a finite real scalar.', name);
end
if value < minimum || value > maximum
    error('exp4:InvalidParameter', '%s is outside the allowed range.', name);
end
end

function value = integerInRange(value, name, minimum, maximum)
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ...
        ~isFiniteNumber(value) || value ~= fix(value) || value < minimum || value > maximum
    error('exp4:InvalidParameter', '%s must be an integer from %d to %d.', name, minimum, maximum);
end
end

function tf = isFiniteNumber(value)
tf = ~isnan(value) & ~isinf(value);
end
