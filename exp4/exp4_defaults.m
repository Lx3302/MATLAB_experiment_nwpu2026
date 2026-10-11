function config = exp4_defaults(domain)
%EXP4_DEFAULTS Default configurations for the experiment 4 stability app.
% Discrete coefficients are listed in ascending powers of z^-1. Continuous
% coefficients are listed in descending powers of s.

if nargin < 1 || isempty(domain)
    domain = 'continuous';
end
domain = lower(char(string(domain)));

switch domain
    case {'discrete', 'z'}
        config.domain = 'discrete';
        config.numerator = [0.021, 0, -0.042, 0, 0.021];
        config.denominator = [1, -1.491, 2.848, -1.68, 1.2732];
        config.frequencyMin = 0;
        config.frequencyMax = pi;
        config.sampleCount = 120;
    case {'continuous', 's'}
        config.domain = 'continuous';
        config.numerator = [1, 7, 24, 24];
        config.denominator = [1, 10, 35, 50, 24];
        config.frequencyMin = 0;
        config.frequencyMax = 50;
        config.sampleCount = 1001;
    otherwise
        error('exp4:UnknownDomain', 'domain must be ''discrete'' or ''continuous''.');
end

config.stabilityTolerance = 1e-8;
config.frequencyPoints = 1024;
config.maxTime = 10;
config.symbolic = true;
end
