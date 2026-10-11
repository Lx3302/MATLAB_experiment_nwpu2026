function result = exp3_pattern(config)
%EXP3_PATTERN Calculate the directionality of a uniformly spaced linear array.
%   RESULT = EXP3_PATTERN(CONFIG) uses a scalar configuration struct. Missing
%   fields are filled from EXP3_DEFAULTS; unknown fields are rejected.
%
%   The angle phi is measured in degrees from the array axis. The optional
%   SteeringAngleDeg phase shift defaults to 90 degrees, matching the guide's
%   broadside formula. The unnormalised magnitude has a peak of N:
%
%     abs(sin(N*q) ./ sin(q)),
%     q = pi*(d/lambda)*(cosd(phi)-cosd(phi0)).
%
%   At removable singularities q = k*pi, the limiting magnitude is set to N.
%   RESULT contains only numeric values and a configuration struct, not graphics.

if nargin < 1 || isempty(config)
    config = struct();
end
config = normalizeConfig(config);

angles = linspace(config.AngleStartDeg, config.AngleEndDeg, ...
    config.SampleCount).';
spacingRatio = config.SpacingMeters / config.WavelengthMeters;
phase = pi .* spacingRatio .* ...
    (cosd(angles) - cosd(config.SteeringAngleDeg));
if any(~isfinite(phase))
    error('exp3_pattern:InvalidPhase', ...
        '当前间距、波长和角度组合超出可计算范围。');
end

denominator = sin(phase);
rawMagnitude = abs(sin(config.ElementCount .* phase) ./ denominator);

% Replace q=k*pi points with the analytic limit. This also preserves exact
% grating-lobe maxima instead of allowing a 0/0 calculation to become NaN.
phaseInPi = phase ./ pi;
nearestInteger = round(phaseInPi);
singularityTolerance = 16 .* eps(max(1, abs(phaseInPi)));
singular = abs(phaseInPi - nearestInteger) <= singularityTolerance;
rawMagnitude(singular) = config.ElementCount;

if any(~isfinite(rawMagnitude))
    error('exp3_pattern:NumericalFailure', ...
        '阵列因子计算产生了非有限值，请检查参数范围。');
end

% The triangle inequality bounds the array factor by N. Clamp tiny floating
% point overshoots so the normalized and dB displays retain that convention.
normalizedMagnitude = min(rawMagnitude ./ config.ElementCount, 1);
floorAmplitude = 10 .^ (config.DecibelFloor ./ 20);
relativeDb = 20 .* log10(max(normalizedMagnitude, floorAmplitude));

if strcmp(config.CartesianScale, 'db')
    cartesianValues = relativeDb;
elseif config.Normalize
    cartesianValues = normalizedMagnitude;
else
    cartesianValues = rawMagnitude;
end

if config.Normalize
    polarMagnitude = normalizedMagnitude;
else
    polarMagnitude = rawMagnitude;
end

result = struct( ...
    'Config', config, ...
    'AngleDegrees', angles, ...
    'AngleRadians', deg2rad(angles), ...
    'RawMagnitude', rawMagnitude, ...
    'NormalizedMagnitude', normalizedMagnitude, ...
    'RelativeDb', relativeDb, ...
    'CartesianValues', cartesianValues, ...
    'PolarMagnitude', polarMagnitude);
end

function config = normalizeConfig(config)
defaults = exp3_defaults();
if ~isstruct(config) || ~isscalar(config)
    error('exp3_pattern:InvalidConfig', ...
        'config 必须是标量结构体。');
end

providedFields = fieldnames(config);
allowedFields = fieldnames(defaults);
unknownFields = setdiff(providedFields, allowedFields);
if ~isempty(unknownFields)
    error('exp3_pattern:UnknownConfigField', ...
        '未知参数字段：%s。', strjoin(unknownFields, ', '));
end

for k = 1:numel(allowedFields)
    name = allowedFields{k};
    if ~isfield(config, name)
        config.(name) = defaults.(name);
    end
end

config.ElementCount = requireInteger(config.ElementCount, 1, 512, ...
    '阵元数 N');
config.SampleCount = requireInteger(config.SampleCount, 2, 200001, ...
    '采样点数');
config.SpacingMeters = requirePositiveScalar(config.SpacingMeters, ...
    '阵元间距 d');
config.WavelengthMeters = requirePositiveScalar(config.WavelengthMeters, ...
    '波长 lambda');
config.SteeringAngleDeg = requireBoundedScalar( ...
    config.SteeringAngleDeg, 0, 360, '指向角 phi0');
config.AngleStartDeg = requireBoundedScalar( ...
    config.AngleStartDeg, 0, 360, '角度起点');
config.AngleEndDeg = requireBoundedScalar( ...
    config.AngleEndDeg, 0, 360, '角度终点');
if config.AngleEndDeg <= config.AngleStartDeg
    error('exp3_pattern:InvalidAngleRange', ...
        '角度终点必须大于起点；角度范围最多为 360 度。');
end
if config.AngleEndDeg - config.AngleStartDeg > 360
    error('exp3_pattern:InvalidAngleRange', ...
        '角度范围不能超过 360 度。');
end

if ~(islogical(config.Normalize) && isscalar(config.Normalize))
    error('exp3_pattern:InvalidNormalize', ...
        'Normalize 必须是标量逻辑值。');
end

scale = config.CartesianScale;
if isstring(scale) && isscalar(scale)
    scale = char(scale);
end
if ~(ischar(scale) && (isrow(scale) || isempty(scale)))
    error('exp3_pattern:InvalidScale', ...
        'CartesianScale 必须为 ''linear'' 或 ''db''。');
end
scale = lower(strtrim(scale));
if ~any(strcmp(scale, {'linear', 'db'}))
    error('exp3_pattern:InvalidScale', ...
        'CartesianScale 必须为 ''linear'' 或 ''db''。');
end
config.CartesianScale = scale;

config.DecibelFloor = requireBoundedScalar( ...
    config.DecibelFloor, -200, -1, 'dB 下限');

spacingRatio = config.SpacingMeters / config.WavelengthMeters;
if ~isfinite(spacingRatio) || spacingRatio <= 0 || spacingRatio > 1e6
    error('exp3_pattern:InvalidSpacingRatio', ...
        'd/lambda 必须是 (0, 1e6] 范围内的有限正数。');
end
end

function value = requireInteger(value, minimum, maximum, label)
value = requireNumericScalar(value, label);
if value < minimum || value > maximum || value ~= fix(value)
    error('exp3_pattern:InvalidInteger', ...
        '%s 必须是 %d 到 %d 之间的整数。', label, minimum, maximum);
end
end

function value = requirePositiveScalar(value, label)
value = requireNumericScalar(value, label);
if value <= 0
    error('exp3_pattern:InvalidPositiveValue', ...
        '%s 必须是有限正数。', label);
end
end

function value = requireBoundedScalar(value, minimum, maximum, label)
value = requireNumericScalar(value, label);
if value < minimum || value > maximum
    error('exp3_pattern:OutOfRange', ...
        '%s 必须位于 %.6g 到 %.6g 之间。', label, minimum, maximum);
end
end

function value = requireNumericScalar(value, label)
if ~(isnumeric(value) && isreal(value) && isscalar(value) && ...
        isfinite(value))
    error('exp3_pattern:InvalidNumericValue', ...
        '%s 必须是有限实数标量。', label);
end
value = double(value);
end
