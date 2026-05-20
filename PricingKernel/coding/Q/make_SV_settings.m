% filename: make_SV_settings.m
% written by Chin HSU on 2026/05/17
% Descriptions: This file sets SV initial values, bounds, and optimizer options.

function [param0, lb, ub, options] = make_SV_settings()

param0 = [ ...
    0.0003, -0.1705, 0.0002, 0.8076, 0.0010, ...
    0.0200 ...
];

lb = -5 * ones(6,1);
ub =  5 * ones(6,1);

lb(2) = -1;
ub(2) =  1;

lb(3) = 1e-8;

lb(4) = 0;
ub(4) = 0.999;

lb(5) = 1e-8;

lb(6) = 1e-8;
ub(6) = 1;

options = optimoptions(@lsqnonlin, ...
    'Algorithm', 'trust-region-reflective', ...
    'Display', 'off', ...
    'UseParallel', false, ...
    'FunctionTolerance', 1e-8, ...
    'MaxIterations', 100, ...
    'MaxFunctionEvaluations', 1000, ...
    'StepTolerance', 1e-6);

end
