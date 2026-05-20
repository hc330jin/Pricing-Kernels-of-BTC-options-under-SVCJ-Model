% filename: make_BS_settings.m
% written by Chin HSU on 2026/05/17
% Descriptions: This file sets BS initial value and optimizer options.

function [param0, options] = make_BS_settings()

param0 = 0.0267;

options = optimset( ...
    'Display', 'off', ...
    'TolFun', 1e-8, ...
    'TolX', 1e-6 ...
);

end
