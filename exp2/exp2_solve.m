function result = exp2_solve(config)
%EXP2_SOLVE Run Newton and bisection for a configurable real polynomial.
%   The configuration is normally obtained from EXP2_DEFAULTS. The returned
%   struct contains independent method results and roots(coefficients) as an
%   algebraic verification, including complex roots.

if nargin < 1 || isempty(config)
    config = exp2_defaults();
end
config = validateConfiguration(config);
coefficients = config.coefficients;
derivativeCoefficients = polyder(coefficients);
f = @(x) polyval(coefficients, x);
df = @(x) polyval(derivativeCoefficients, x);
options = struct( ...
    'xTolerance', config.xTolerance, ...
    'residualTolerance', config.residualTolerance, ...
    'maxIterations', config.maxIterations);

% Each method returns its own failure status, so one failure cannot erase
% the successful result from the other method.
newton = newton_root(f, df, config.initialX, options);
bisection = bisect_root(f, config.bracket, options);

verificationMessage = '';
try
    verificationRoots = roots(coefficients);
    verificationResiduals = abs(polyval(coefficients, verificationRoots));
catch exception
    verificationRoots = complex(zeros(0, 1));
    verificationResiduals = zeros(0, 1);
    verificationMessage = exception.message;
end
result = struct( ...
    'config', config, ...
    'equationName', config.equationName, ...
    'formula', config.formula, ...
    'coefficients', coefficients, ...
    'newton', newton, ...
    'bisection', bisection, ...
    'verificationRoots', verificationRoots, ...
    'verificationResiduals', verificationResiduals(:), ...
    'verificationMessage', verificationMessage);
end

function config = validateConfiguration(config)
if ~isstruct(config) || ~isscalar(config)
    error('exp2:InvalidConfiguration', '配置必须是标量结构体。');
end
requiredFields = {'coefficients', 'initialX', 'bracket', 'xTolerance', ...
    'residualTolerance', 'maxIterations', 'plotBounds'};
for index = 1:numel(requiredFields)
    if ~isfield(config, requiredFields{index})
        error('exp2:InvalidConfiguration', ...
            '配置缺少字段 %s。', requiredFields{index});
    end
end

coefficients = config.coefficients;
if ~(isnumeric(coefficients) && isreal(coefficients) && isvector(coefficients) && ...
        ~isempty(coefficients) && allFinite(coefficients))
    error('exp2:InvalidCoefficients', '系数必须是有限实数向量。');
end
coefficients = double(coefficients(:).');
while numel(coefficients) > 1 && coefficients(1) == 0
    coefficients(1) = [];
end
if numel(coefficients) < 2 || all(coefficients == 0)
    error('exp2:InvalidCoefficients', '请输入次数至少为 1 的非零多项式。');
end
config.coefficients = coefficients;

if ~isFiniteScalar(config.initialX)
    error('exp2:InvalidInitialPoint', '初始点必须是有限数值标量。');
end
config.initialX = double(config.initialX);
if ~(isnumeric(config.bracket) && isreal(config.bracket) && ...
        numel(config.bracket) == 2 && allFinite(config.bracket))
    error('exp2:InvalidBracket', '二分区间必须包含两个有限实数端点。');
end
config.bracket = double(config.bracket(:).');
if ~isPositiveFinite(config.xTolerance) || ...
        ~isPositiveFinite(config.residualTolerance)
    error('exp2:InvalidTolerance', '相对容差和残差容差必须是正有限数值。');
end
if ~(isnumeric(config.maxIterations) && isscalar(config.maxIterations) && ...
        isreal(config.maxIterations) && isfinite(config.maxIterations) && ...
        config.maxIterations >= 1 && config.maxIterations == fix(config.maxIterations))
    error('exp2:InvalidIterationLimit', '最大迭代次数必须是正整数。');
end
config.xTolerance = double(config.xTolerance);
config.residualTolerance = double(config.residualTolerance);
config.maxIterations = double(config.maxIterations);

if ~(isnumeric(config.plotBounds) && isreal(config.plotBounds) && ...
        numel(config.plotBounds) == 2 && allFinite(config.plotBounds))
    error('exp2:InvalidPlotBounds', '绘图区间必须包含两个有限实数端点。');
end
config.plotBounds = double(config.plotBounds(:).');
if config.plotBounds(1) >= config.plotBounds(2)
    error('exp2:InvalidPlotBounds', '绘图区间左端点必须小于右端点。');
end
matchedPreset = false;
if isfield(config, 'presets') && isstruct(config.presets) && ...
        ~isempty(config.presets) && isfield(config, 'presetIndex') && ...
        isnumeric(config.presetIndex) && isscalar(config.presetIndex) && ...
        isfinite(config.presetIndex) && config.presetIndex == fix(config.presetIndex) && ...
        config.presetIndex >= 1 && config.presetIndex <= numel(config.presets)
    preset = config.presets(config.presetIndex);
    if isfield(preset, 'coefficients') && ...
            isequal(coefficients, double(preset.coefficients(:).'))
        matchedPreset = true;
        config.equationName = preset.name;
        config.formula = preset.formula;
    end
end
if ~matchedPreset
    config.equationName = '自定义多项式';
    config.formula = polynomialText(coefficients);
end
end

function textValue = polynomialText(coefficients)
degree = numel(coefficients) - 1;
terms = cell(1, numel(coefficients));
for index = 1:numel(coefficients)
    power = degree - index + 1;
    if power == 0
        terms{index} = sprintf('%g', coefficients(index));
    elseif power == 1
        terms{index} = sprintf('(%g)x', coefficients(index));
    else
        terms{index} = sprintf('(%g)x^%d', coefficients(index), power);
    end
end
textValue = strjoin(terms, ' + ');
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

function tf = allFinite(values)
tf = all(~isnan(values(:)) & ~isinf(values(:)));
end
