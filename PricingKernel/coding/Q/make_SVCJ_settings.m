% filename: make_SVCJ_settings.m
% written by Chin HSU on 2026/05/15
% Descriptions: This file is to set SVCJ settings like initial value and
% upper/lower bound

function [param0, lb, ub, options] = make_SVCJ_settings()

param0 = [ ...
   -0.0002   -0.8922    0.0025   -2.0661    0.0025 ...
    0.0603    0.0067    0.1010   -1.0588    0.0212 ...
    0.0000 ...
];

lb = -5 * ones(11,1);
ub =  5 * ones(11,1);

lb(2) = -1;
ub(2) =  1;

lb(3) = 0;
lb(5) = 0;
lb(6) = 0;

ub(4) = 1;

lb(7) = 0;
ub(7) = 1;

lb(10) = 0;
lb(11) = 0;

options = optimoptions(@lsqnonlin, ...
    'Algorithm', 'trust-region-reflective', ...
    'Display', 'off', ...
    'FunctionTolerance', 1e-8, ...
    'StepTolerance', 1e-6, ...
    'MaxIterations', 50, ...
    'MaxFunctionEvaluations', 500);

end