% filename: estimate_one_pk.m
% written by Chin HSU and updated on 2026/05/13
% Descriptions: To estimate one day pricing kernel

clc;
clear;
close all;

%% ===== Settings =====

q_file = fullfile('SVCJ_calibration_50paths', 'daily_SVCJ_calibration.csv');
p_file = fullfile('../P/SVCJ_100000_estimate_BITCOIN_1', 'p_parameter_tmp.csv');

Q = readtable(q_file);
P = readtable(p_file);

date_id = 1;      % 先測第1天
tau = 7;          % pricing kernel horizon: 7 days
n_sim = 50000;    % simulation paths

S0 = 1;           % 對log return分布而言，S0可設為1

rng(114514);
fprintf('Finish loading p and q\n');

%% ===== Extract Q-measure parameters =====

param_Q = [ ...
    Q.mu(date_id), ...
    Q.rho(date_id), ...
    Q.alpha(date_id), ...
    Q.beta(date_id), ...
    Q.V0(date_id), ...
    Q.sigma_v(date_id), ...
    Q.lambda(date_id), ...
    Q.mu_y(date_id), ...
    Q.rho_j(date_id), ...
    Q.sigma_y(date_id), ...
    Q.mu_v(date_id) ...
];

%% ===== Extract P-measure parameters =====

param_P = [ ...
    P.mu(date_id), ...
    P.rho(date_id), ...
    P.alpha(date_id), ...
    P.beta(date_id), ...
    P.V0(date_id), ...
    P.sigma_v(date_id), ...
    P.lambda(date_id), ...
    P.mu_y(date_id), ...
    P.rho_j(date_id), ...
    P.sigma_y(date_id), ...
    P.mu_v(date_id) ...
];
fprintf('Finish extracting parameters\n');
%% ===== Generate random numbers =====

U_Q = unifrnd(0, 1, [2*n_sim, tau]);
Z_Q = normrnd(0, 1, [3*n_sim, tau]);

U_P = unifrnd(0, 1, [2*n_sim, tau]);
Z_P = normrnd(0, 1, [3*n_sim, tau]);

%% ===== Simulate SVCJ paths under Q and P =====

S_Q = get_SVCJ(U_Q, Z_Q, param_Q, S0);
S_P = get_SVCJ(U_P, Z_P, param_P, S0);
fprintf('Finish simulating price paths\n');
%% ===== Terminal log returns =====

R_Q = log(S_Q(:,tau) ./ S0);
R_P = log(S_P(:,tau) ./ S0);
fprintf('Finish calculating returns\n');

%% ===== KDE density estimation =====

x_min = max(prctile(R_Q, 1), prctile(R_P, 1));
x_max = min(prctile(R_Q, 99), prctile(R_P, 99));

x_grid = linspace(x_min, x_max, 300);

[f_Q, x_grid] = ksdensity(R_Q, x_grid);
[f_P, ~]      = ksdensity(R_P, x_grid);
fprintf('Finish estimating KDE\n');

%% ===== Pricing Kernel =====

eps0 = 1e-8;

PK = f_Q ./ max(f_P, eps0);

%% ===== Normalize pricing kernel for visualization =====
% Optional: normalize so that mean PK scale is easier to read

PK_normalized = PK ./ mean(PK, 'omitnan');
fprintf('Finish calculating PK\n');

%% ===== Save result =====

folder_name = 'PricingKernel_result';

if ~exist(folder_name, 'dir')
    mkdir(folder_name);
end

result_PK = table( ...
    x_grid(:), ...
    f_Q(:), ...
    f_P(:), ...
    PK(:), ...
    PK_normalized(:), ...
    'VariableNames', {'log_return','q_density','p_density','pricing_kernel','pricing_kernel_normalized'} ...
);

writetable(result_PK, fullfile(folder_name, 'one_day_pricing_kernel.csv'));
fprintf('Finish saving results\n');

%% ===== Plot Q and P densities =====

fig = figure;
plot(x_grid, f_Q, 'LineWidth', 1.5);
hold on;
plot(x_grid, f_P, 'LineWidth', 1.5);
xlabel('Log return');
ylabel('Density');
title('Q-density vs P-density');
legend('Q density', 'P density');


set(gcf,'color','none');
set(gca,'color','none');
export_fig(fullfile(folder_name, 'Q_density_vs_P_density'), ...
    '-png', '-transparent', '-r300', '-opengl');

close(fig);
fprintf('Finish plotting\n');

%% ===== Plot Pricing Kernel =====

fig = figure;
plot(x_grid, PK_normalized, 'LineWidth', 1.5);
xlabel('Log return');
ylabel('Normalized pricing kernel');
title('Estimated pricing kernel: q(x) / p(x)');
grid on;

set(gcf,'color','none');
set(gca,'color','none');
export_fig(fullfile(folder_name, 'Estimated_pricing_kernel'), ...
    '-png', '-transparent', '-r300', '-opengl');

close(fig);

fprintf('Pricing kernel estimation finished.\n');