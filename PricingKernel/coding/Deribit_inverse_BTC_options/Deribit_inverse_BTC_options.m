% filename: GitHub_calibrate_BS.m
% written by Huei-Wen Teng and updated on 2022/9/6
% Descriptions: This main file demonstrate how to calibrate the BS, SV,
% SVJ, and SVCJ using Deribit inverse options
% It also calcualte delta under the BS, SV, SVJ, SVCJ model.
clc; clear all; close all;

%% ===== Load Deribit Option Data =====

% Time range from 2021/01/01 to 2022/01/31
filename = 'Deribit_20210101_20220131.csv';

T = readtable(filename);

% Rename variable name
T.Properties.VariableNames = ...
{'q','p','s','timestamp','date','trade_seq','trade_id', ...
 'tick_direction','iv','instrument_name','index_price','direction'};

% Convert date type
T.date = datetime(T.date,'InputFormat','yyyy-MM-dd');

% Filter data range
start_date = datetime(2021,11,1);
end_date   = datetime(2022,1,29);

T = T(T.date >= start_date & T.date <= end_date , :);

% Parse instrument name
temp = split(string(T.instrument_name), '-');

T.underlying = temp(:,1);

T.maturity = datetime(temp(:,2), ...
    'InputFormat','ddMMMyy');

T.strike = str2double(temp(:,3));

T.cp = temp(:,4);

% Create variables

q = T.q;

p = T.p;

iv = T.iv / 100;

index_price = T.index_price;

strike = T.strike;

% C/P indicator
omega = double(T.cp == "C") ...
      - double(T.cp == "P");
T.omega = omega;

% Time to maturity
DTM = days(T.maturity - T.date);
T.DTM = DTM;

tau = DTM / 365;
T.tau = tau;

% Moneyness
moneyness = index_price ./ strike;
T.moneyness = moneyness;

% Maximum Maturity
nDay_max = max(DTM);

disp("Data loading complete!")

%% ======= Setting common random numbers =======
% n = 50; % Monte Carlo sample size
% disp('Start setting common random numbers...\n')
% U_base = unifrnd(0, 1, [2*n,  nDay_max]);
% Z_base = normrnd(0, 1, [3*n, nDay_max]);
% disp('Done!')
%% ======= Construct Unique Contracts =======
% disp('Start construct unique contracts...\n')
% contract_table = table( ...
%     T.omega, ...
%     T.DTM, ...
%     T.strike, ...
%     T.index_price, ...
%     'VariableNames', {'omega','DTM','strike','index_price'} ...
% );
% [contract_base_table, ia, ic] = unique(contract_table, 'rows', 'stable');
% 
% n_base = height(contract_base_table);
% 
% omega_base       = contract_base_table.omega;
% maturity_base    = contract_base_table.DTM;          % t = T, in days
% strike_base      = contract_base_table.strike;
% index_price_base = contract_base_table.index_price;
% d_base           = zeros(n_base, 1);                 % t = 0
% 
% p = T.p;
% disp('Done!')
% 

%% ======= Daily Calibration: BS Model =======
curr_model = 'BS';

unique_dates = unique(T.date);
n_dates = length(unique_dates);

mc_size = 50; % Monte Carlo sample size

folder_name = sprintf('%s_calibration_%dpaths', curr_model, mc_size);

% Ensure folder exists
if ~exist(folder_name, 'dir')
    mkdir(folder_name);
end


result_BS = table( ...
    unique_dates, ...
    nan(n_dates,1), ...
    nan(n_dates,1), ...
    nan(n_dates,1), ...
    nan(n_dates,1), ...
    nan(n_dates,1), ...
    'VariableNames', {'date','sigma_BS','SSE_BS','RMSE_BS','n_obs','n_contract'} ...
);

for k = 1:n_dates

    current_date = unique_dates(k);

    fprintf('\n===== Calibrating date: %s =====\n', string(current_date));

    %% ===== Extract one-day data =====
    T_day = T(T.date == current_date, :);

    if height(T_day) == 0
        continue;
    end

    %% ===== Market prices =====
    p_day = T_day.p;

    %% ===== Common random numbers for this day =====
    nDay_max_day = max(T_day.DTM);

    rng(114514);

    U_base_day = unifrnd(0, 1, [2*mc_size, nDay_max_day]);
    Z_base_day = normrnd(0, 1, [3*mc_size, nDay_max_day]);

    %% ===== Construct unique contracts for this day =====
    contract_table_day = table( ...
        T_day.omega, ...
        T_day.DTM, ...
        T_day.strike, ...
        T_day.index_price, ...
        'VariableNames', {'omega','DTM','strike','index_price'} ...
    );

    [contract_base_table_day, ia_day, ic_day] = ...
        unique(contract_table_day, 'rows', 'stable');

    n_base_day = height(contract_base_table_day);

    omega_base_day       = contract_base_table_day.omega;
    maturity_base_day    = contract_base_table_day.DTM;
    strike_base_day      = contract_base_table_day.strike;
    index_price_base_day = contract_base_table_day.index_price;
    d_base_day           = zeros(n_base_day, 1);

    curr_model = 'BS';
    param0 = 0.0267;

    if k == 1 % For day 1, we look at # of iterations and function plot
        options = optimset( ...
        'Display', 'iter', ...
        'PlotFcns', @optimplotfval, ...
        'TolFun', 1e-8, ...
        'TolX', 1e-6 ...
    );
    else
    options = optimset( ...
        'Display', 'off', ...
        'TolFun', 1e-8, ...
        'TolX', 1e-6 ...
    );
    end

    fun = @(param)obj_fminsearch( ...
        param, curr_model, mc_size, U_base_day, Z_base_day, p_day, ...
        index_price_base_day, omega_base_day, d_base_day, ...
        maturity_base_day, strike_base_day, ic_day ...
    );
    
    tic;

    [param_BS_day, fval_BS_day, exitflag_BS_day, output_BS_day] = ...
        fminsearch(fun, param0, options);
    
    elapsed_time = toc;

    %% ===== Save daily result =====
    result_BS.sigma_BS(k)    = param_BS_day;
    result_BS.SSE_BS(k)      = fval_BS_day;
    result_BS.RMSE_BS(k)     = sqrt(fval_BS_day / length(p_day));
    result_BS.n_obs(k)       = length(p_day);
    result_BS.n_contract(k)  = n_base_day;

    fprintf('Date = %s | sigma = %.6f | RMSE = %.6f | time = %.2f sec\n', ...
    string(current_date), ...
    param_BS_day, ...
    sqrt(fval_BS_day / length(p_day)), ...
    elapsed_time);

end

% ===== Save results =====
writetable(result_BS, fullfile(folder_name, 'daily_BS_calibration.csv'));

% ===== Plot =====
result_BS.sigma_BS_annualized = result_BS.sigma_BS * sqrt(365); % Annualized

fig = figure;
plot(result_BS.date, result_BS.sigma_BS, '-o');
xlabel('Date');
ylabel('BS implied volatility');
title('Daily calibrated BS implied volatility');

set(gcf,'color','none');
set(gca,'color','none');
export_fig(fullfile(folder_name, 'Daily calibrated BS implied volatility'), '-png', '-transparent', '-r300', '-opengl');
close(fig);
fprintf('BS Model Calibration Done!')

%% ===== Analysis of BS =====

analyze_Q_results(curr_model, mc_size);



%% ======= Daily Calibration: SV Model =======
curr_model = 'SV';

unique_dates = unique(T.date);
n_dates = length(unique_dates);

mc_size = 50; % Monte Carlo sample size

folder_name = sprintf('%s_calibration_%dpaths', curr_model, mc_size);

% Ensure folder exists
if ~exist(folder_name, 'dir')
    mkdir(folder_name);
end


result_SV = table( ...
    unique_dates, ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), ...
    'VariableNames', {'date','mu','rho','alpha','beta','V0','sigma_v', ...
                      'SSE_SV','RMSE_SV','n_obs','n_contract'} ...
);

for k = 1:n_dates

    current_date = unique_dates(k);
    fprintf('\n===== Calibrating SV date: %s =====\n', string(current_date));

    T_day = T(T.date == current_date, :);

    if height(T_day) == 0
        continue;
    end

    p_day = T_day.p;

    nDay_max_day = max(T_day.DTM);

    rng(114514);

    U_base_day = unifrnd(0, 1, [2*mc_size, nDay_max_day]);
    Z_base_day = normrnd(0, 1, [3*mc_size, nDay_max_day]);

    contract_table_day = table( ...
        T_day.omega, ...
        T_day.DTM, ...
        T_day.strike, ...
        T_day.index_price, ...
        'VariableNames', {'omega','DTM','strike','index_price'} ...
    );

    [contract_base_table_day, ia_day, ic_day] = ...
        unique(contract_table_day, 'rows', 'stable');

    n_base_day = height(contract_base_table_day);

    omega_base_day       = contract_base_table_day.omega;
    maturity_base_day    = contract_base_table_day.DTM;
    strike_base_day      = contract_base_table_day.strike;
    index_price_base_day = contract_base_table_day.index_price;
    d_base_day           = zeros(n_base_day, 1);

    param0 = [0.0009 -0.9970 0.0002 0.8706 0.0019 0.0015];

    lb = -5 * ones(6,1);
    ub =  5 * ones(6,1);

    lb(2) = -1;
    ub(2) =  1;

    lb(3) = 0;   % alpha > 0
    lb(5) = 0;   % V0 > 0
    lb(6) = 0;   % sigma_v > 0

    ub(4) = 1;   % beta < 1

    if k == 1
        options = optimoptions(@lsqnonlin, ...
            'Algorithm', 'trust-region-reflective', ...
            'Display', 'iter', ...
            'FunctionTolerance', 1e-8, ...
            'MaxIterations', 50, ...
            'StepTolerance', 1e-6);
    else
        options = optimoptions(@lsqnonlin, ...
            'Algorithm', 'trust-region-reflective', ...
            'Display', 'off', ...
            'FunctionTolerance', 1e-8, ...
            'MaxIterations', 50, ...
            'StepTolerance', 1e-6);
    end

    fun = @(param)obj_lsqnonlin( ...
        param, curr_model, mc_size, p_day, U_base_day, Z_base_day, ...
        index_price_base_day, omega_base_day, d_base_day, ...
        maturity_base_day, strike_base_day, ic_day ...
    );

    tic;

    [param_SV_day, resnorm_SV_day, residual_SV_day, exitflag_SV_day, output_SV_day] = ...
        lsqnonlin(fun, param0, lb, ub, options);

    elapsed_time = toc;

    result_SV.mu(k)         = param_SV_day(1);
    result_SV.rho(k)        = param_SV_day(2);
    result_SV.alpha(k)      = param_SV_day(3);
    result_SV.beta(k)       = param_SV_day(4);
    result_SV.V0(k)         = param_SV_day(5);
    result_SV.sigma_v(k)    = param_SV_day(6);

    result_SV.SSE_SV(k)     = resnorm_SV_day;
    result_SV.RMSE_SV(k)    = sqrt(resnorm_SV_day / length(p_day));
    result_SV.n_obs(k)      = length(p_day);
    result_SV.n_contract(k) = n_base_day;

    fprintf('Date = %s | RMSE = %.6f | time = %.2f sec\n', ...
        string(current_date), result_SV.RMSE_SV(k), elapsed_time);

end

writetable(result_SV, fullfile(folder_name, 'daily_SV_calibration.csv'));

fig = figure;
plot(result_SV.date, result_SV.V0, '-o');
xlabel('Date');
ylabel('SV implied V0');
title('Daily calibrated SV implied V0');

set(gcf,'color','none');
set(gca,'color','none');
export_fig(fullfile(folder_name, 'Daily calibrated SV implied V0'), ...
    '-png', '-transparent', '-r300', '-opengl');
close(fig);

%% ===== Analysis of SV =====

analyze_Q_results(curr_model, mc_size);


%% ======= Daily Calibration: SVJ Model =======
curr_model = 'SVJ';

unique_dates = unique(T.date);
n_dates = length(unique_dates);

mc_size = 50;

folder_name = sprintf('%s_calibration_%dpaths', curr_model, mc_size);

if ~exist(folder_name, 'dir')
    mkdir(folder_name);
end

result_SVJ = table( ...
    unique_dates, ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), ...
    'VariableNames', {'date','mu','rho','alpha','beta','V0','sigma_v', ...
                      'lambda','mu_y','sigma_y', ...
                      'SSE_SVJ','RMSE_SVJ','n_obs','n_contract'} ...
);

for k = 1:n_dates

    current_date = unique_dates(k);
    fprintf('\n===== Calibrating SVJ date: %s =====\n', string(current_date));

    T_day = T(T.date == current_date, :);

    if height(T_day) == 0
        continue;
    end

    p_day = T_day.p;

    nDay_max_day = max(T_day.DTM);

    rng(114514);

    U_base_day = unifrnd(0, 1, [2*mc_size, nDay_max_day]);
    Z_base_day = normrnd(0, 1, [3*mc_size, nDay_max_day]);

    contract_table_day = table( ...
        T_day.omega, ...
        T_day.DTM, ...
        T_day.strike, ...
        T_day.index_price, ...
        'VariableNames', {'omega','DTM','strike','index_price'} ...
    );

    [contract_base_table_day, ia_day, ic_day] = ...
        unique(contract_table_day, 'rows', 'stable');

    n_base_day = height(contract_base_table_day);

    omega_base_day       = contract_base_table_day.omega;
    maturity_base_day    = contract_base_table_day.DTM;
    strike_base_day      = contract_base_table_day.strike;
    index_price_base_day = contract_base_table_day.index_price;
    d_base_day           = zeros(n_base_day, 1);

    param0 = [ ...
        0.0003   -0.1705   -0.0000   -4.9991    0.0000 ...
        1.9627    0.2340    0.0035    0.0792 ...
    ];

    lb = -5 * ones(9,1);
    ub =  5 * ones(9,1);

    lb(2) = -1;
    ub(2) =  1;

    lb(3) = 0;
    lb(5) = 0;
    lb(6) = 0;

    ub(4) = 1;

    lb(7) = 0;
    ub(7) = 1;

    lb(9) = 0;

    if k == 1
        options = optimoptions(@lsqnonlin, ...
            'Algorithm', 'trust-region-reflective', ...
            'Display', 'iter', ...
            'FunctionTolerance', 1e-8, ...
            'MaxIterations', 50, ...
            'StepTolerance', 1e-6);
    else
        options = optimoptions(@lsqnonlin, ...
            'Algorithm', 'trust-region-reflective', ...
            'Display', 'off', ...
            'FunctionTolerance', 1e-8, ...
            'MaxIterations', 50, ...
            'StepTolerance', 1e-6);
    end

    fun = @(param)obj_lsqnonlin( ...
        param, curr_model, mc_size, p_day, U_base_day, Z_base_day, ...
        index_price_base_day, omega_base_day, d_base_day, ...
        maturity_base_day, strike_base_day, ic_day ...
    );

    tic;

    [param_SVJ_day, resnorm_SVJ_day, residual_SVJ_day, exitflag_SVJ_day, output_SVJ_day] = ...
        lsqnonlin(fun, param0, lb, ub, options);

    elapsed_time = toc;

    result_SVJ.mu(k)         = param_SVJ_day(1);
    result_SVJ.rho(k)        = param_SVJ_day(2);
    result_SVJ.alpha(k)      = param_SVJ_day(3);
    result_SVJ.beta(k)       = param_SVJ_day(4);
    result_SVJ.V0(k)         = param_SVJ_day(5);
    result_SVJ.sigma_v(k)    = param_SVJ_day(6);
    result_SVJ.lambda(k)     = param_SVJ_day(7);
    result_SVJ.mu_y(k)       = param_SVJ_day(8);
    result_SVJ.sigma_y(k)    = param_SVJ_day(9);

    result_SVJ.SSE_SVJ(k)     = resnorm_SVJ_day;
    result_SVJ.RMSE_SVJ(k)    = sqrt(resnorm_SVJ_day / length(p_day));
    result_SVJ.n_obs(k)       = length(p_day);
    result_SVJ.n_contract(k)  = n_base_day;

    fprintf('Date = %s | RMSE = %.6f | time = %.2f sec\n', ...
        string(current_date), result_SVJ.RMSE_SVJ(k), elapsed_time);

end

writetable(result_SVJ, fullfile(folder_name, 'daily_SVJ_calibration.csv'));

fig = figure;
plot(result_SVJ.date, result_SVJ.lambda, '-o');
xlabel('Date');
ylabel('SVJ implied lambda');
title('Daily calibrated SVJ implied lambda');

set(gcf,'color','none');
set(gca,'color','none');
export_fig(fullfile(folder_name, 'Daily calibrated SVJ implied lambda'), ...
    '-png', '-transparent', '-r300', '-opengl');
close(fig);

%% ======= Daily Calibration: SVCJ Model =======
curr_model = 'SVCJ';

unique_dates = unique(T.date);
n_dates = length(unique_dates);

mc_size = 50;

folder_name = sprintf('%s_calibration_%dpaths', curr_model, mc_size);

result_SVCJ = table( ...
    unique_dates, ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), nan(n_dates,1), nan(n_dates,1), ...
    nan(n_dates,1), ...
    'VariableNames', {'date','mu','rho','alpha','beta','V0','sigma_v', ...
                      'lambda','mu_y','rho_j','sigma_y','mu_v', ...
                      'SSE_SVCJ','RMSE_SVCJ','n_obs','n_contract'} ...
);

for k = 1:n_dates

    current_date = unique_dates(k);
    fprintf('\n===== Calibrating SVCJ date: %s =====\n', string(current_date));

    T_day = T(T.date == current_date, :);

    if height(T_day) == 0
        continue;
    end

    p_day = T_day.p;

    nDay_max_day = max(T_day.DTM);

    rng(114514);

    U_base_day = unifrnd(0, 1, [2*mc_size, nDay_max_day]);
    Z_base_day = normrnd(0, 1, [3*mc_size, nDay_max_day]);

    contract_table_day = table( ...
        T_day.omega, ...
        T_day.DTM, ...
        T_day.strike, ...
        T_day.index_price, ...
        'VariableNames', {'omega','DTM','strike','index_price'} ...
    );

    [contract_base_table_day, ia_day, ic_day] = ...
        unique(contract_table_day, 'rows', 'stable');

    n_base_day = height(contract_base_table_day);

    omega_base_day       = contract_base_table_day.omega;
    maturity_base_day    = contract_base_table_day.DTM;
    strike_base_day      = contract_base_table_day.strike;
    index_price_base_day = contract_base_table_day.index_price;
    d_base_day           = zeros(n_base_day, 1);

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

    if k == 1
        options = optimoptions(@lsqnonlin, ...
                                'Algorithm', 'trust-region-reflective', ...
                                'Display', 'iter', ...
                                'FunctionTolerance', 1e-8, ...
                                'StepTolerance', 1e-6, ...
                                'MaxIterations', 50, ...
                                'MaxFunctionEvaluations', 500); % set max iterations for testing
    else
        options = optimoptions(@lsqnonlin, ...
                                'Algorithm', 'trust-region-reflective', ...
                                'Display', 'off', ...
                                'FunctionTolerance', 1e-8, ...
                                'StepTolerance', 1e-6, ...
                                'MaxIterations', 50, ...
                                'MaxFunctionEvaluations', 500); % set max iterations for testing
    end

    fun = @(param)obj_lsqnonlin( ...
        param, curr_model, mc_size, p_day, U_base_day, Z_base_day, ...
        index_price_base_day, omega_base_day, d_base_day, ...
        maturity_base_day, strike_base_day, ic_day ...
    );

    tic;

    [param_SVCJ_day, resnorm_SVCJ_day, residual_SVCJ_day, exitflag_SVCJ_day, output_SVCJ_day] = ...
        lsqnonlin(fun, param0, lb, ub, options);

    elapsed_time = toc;

    result_SVCJ.mu(k)         = param_SVCJ_day(1);
    result_SVCJ.rho(k)        = param_SVCJ_day(2);
    result_SVCJ.alpha(k)      = param_SVCJ_day(3);
    result_SVCJ.beta(k)       = param_SVCJ_day(4);
    result_SVCJ.V0(k)         = param_SVCJ_day(5);
    result_SVCJ.sigma_v(k)    = param_SVCJ_day(6);
    result_SVCJ.lambda(k)     = param_SVCJ_day(7);
    result_SVCJ.mu_y(k)       = param_SVCJ_day(8);
    result_SVCJ.rho_j(k)      = param_SVCJ_day(9);
    result_SVCJ.sigma_y(k)    = param_SVCJ_day(10);
    result_SVCJ.mu_v(k)       = param_SVCJ_day(11);

    result_SVCJ.SSE_SVCJ(k)     = resnorm_SVCJ_day;
    result_SVCJ.RMSE_SVCJ(k)    = sqrt(resnorm_SVCJ_day / length(p_day));
    result_SVCJ.n_obs(k)        = length(p_day);
    result_SVCJ.n_contract(k)   = n_base_day;

    fprintf('Date = %s | RMSE = %.6f | time = %.2f sec\n', ...
        string(current_date), result_SVCJ.RMSE_SVCJ(k), elapsed_time);

end

writetable(result_SVCJ, fullfile(folder_name, 'daily_SVCJ_calibration.csv'));

fig = figure;
plot(result_SVCJ.date, result_SVCJ.lambda, '-o');
xlabel('Date');
ylabel('SVCJ implied lambda');
title('Daily calibrated SVCJ implied lambda');

set(gcf,'color','none');
set(gca,'color','none');
export_fig(fullfile(folder_name, 'Daily calibrated SVCJ implied lambda'), ...
    '-png', '-transparent', '-r300', '-opengl');
close(fig);




% About Delta calculation
%{
%% Task 5: calcualte BS delta
omega = 1;
sig = 0.0267;
sig2 = sig*sig;
index_price = 5000;
strike = 4000;
r = 0;
y = 0;
strikehat = 1/strike;
tau = 100;
d1 = log(index_price/strike)/(sig*sqrt(tau))+(r-y+0.5*sig)*sqrt(tau);
d2 = d1-sig*sqrt(tau);
d3 = d2-sig *sqrt(tau);
delta = omega * (exp((sig2)*tau) * (1/index_price^2)*strike*normcdf(omega*d3));

%% Task 6: calculate SV delta
omega = 1;
sig = 0.0267;
sig2 = sig*sig;
index_price = 5000;
strike = 4000;
r = 0;
y = 0;
strikehat = 1/strike;
tau = 100;

mu = 0.0009;  rho = -0.9970; alpha = 0.0002; beta = 0.8706; V0 = 0.0019;  sig_v = 0.0015;
n = 200; % Monte Carlo sample size
Z1 = normrnd(0, 1, [n, tau]);
Z2 = normrnd(0, 1, [n, tau]);
x1 = Z1; % noise for the return yt
x2 = rho* Z1 + sqrt(1-rho^2)*Z2; % noise for the volatiltiy Vt
V = zeros(n, tau);
t = 1;
V(:, 1) = alpha +  beta * V0 + sig_v * sqrt(V0) .* x2(:, t);
for t = 2: tau
    index = find( V(:, (t-1)) < 0 );
    if ~isempty(index)
        V(index, (t-1)) = 0;
    end
    V(:, t) = alpha +  beta * V(:, (t-1)) + sig_v * sqrt(V(:, t-1)) .* x2(:, t);
end
Y = zeros(n, tau);
t = 1;
Y(:, t) = mu + sqrt(V0) * x1(:, t);
for t = 2: tau
    Y(:, t) = mu + sqrt(V(:, t-1)) .* x1(:, t);
end
S = index_price * exp(cumsum(Y, 2));
Shat = 1/index_price;
delta_temp =  exp(-r*tau) * omega* Shat^2 * max( omega *(index_price - strike), 0);
delta = mean(delta_temp);


%% Task 7: calculate SVJ delta
omega = 1;
sig = 0.0267;
sig2 = sig*sig;
index_price = 5000;
strike = 4000;
r = 0;
y = 0;
strikehat = 1/strike;
tau = 100;
mu = 0.0009;  rho = -0.9970; alpha = 0.0002; beta = 0.8706; V0 = 0.0019;  sig_v = 0.0015;
n = 100;
U1 = unifrnd(0, 1, [n,  tau]);
Z1 = normrnd(0, 1, [n, tau]);
Z2 = normrnd(0, 1, [n, tau]);
Z3 = normrnd(0, 1, [n, tau]);

param = [0.0003   -0.1705   -0.0000   -4.9991    0.0000    1.9627    0.2340    0.0035    0.0792];
mu = param(1); rho = param(2); alpha = param(3); beta = param(4); V0 = param(5); sig_v = param(6); lambda = param(7); mu_y = param(8); sig_y = param(9);

J = get_Bernoulli(lambda, U1);
jump1 = ( mu_y ) + abs(sig_y) * Z1; % Jump for the return
x1 = Z2; % noise for the return yt
x2 = rho* Z2 + sqrt(1-rho^2)*Z3; % noise for the volatiltiy Vt
V = zeros(n, tau);
t = 1;
V(:, 1) = alpha +  beta * V0 + sig_v * sqrt(V0) .* x2(:, t);

for t = 2: tau
    index = find( V(:, (t-1)) < 0 );
    if ~isempty(index)
        V(index, (t-1)) = 0;
    end
    V(:, t) = alpha +  beta * V(:, (t-1)) + sig_v * sqrt(V(:, t-1)) .* x2(:, t);
end
Y = zeros(n, tau);
t = 1;
Y(:, t) = mu + sqrt(V0) * x1(:, t) + jump1(:,t).*J(:, t);
for t = 2: tau
    Y(:, t) = mu + sqrt(V(:, t-1)) .* x1(:, t) + jump1(:,t).*J(:, t);
end
S = index_price * exp(cumsum(Y, 2));

Shat = 1/index_price;
delta_temp =  exp(-r*tau) * omega* Shat^2 * max( omega *(index_price - strike), 0);
delta = mean(delta_temp);

%% Task 8: calculate SVCJ delta
omega = 1;
sig = 0.0267;
sig2 = sig*sig;
index_price = 5000;
strike = 4000;
r = 0;
y = 0;
strikehat = 1/strike;
tau = 100;

mu = 0.0009;  rho = -0.9970; alpha = 0.0002; beta = 0.8706; V0 = 0.0019;  sig_v = 0.0015;
n = 100; 
U1 = unifrnd(0, 1, [n,  tau]);
U2 = unifrnd(0, 1, [n,  tau]);
Z1 = normrnd(0, 1, [n, tau]);
Z2 = normrnd(0, 1, [n, tau]);
Z3 = normrnd(0, 1, [n, tau]);

param = [ -0.0002   -0.8922    0.0025   -2.0661    0.0025    0.0603    0.0067    0.1010   -1.0588    0.0212    0.0000];
mu = param(1);  rho = param(2); alpha = param(3); beta = param(4); V0 = param(5); sig_v = param(6); lambda = param(7); mu_y = param(8); rho_j = param(9); sig_y = param(10); mu_v = param(11);
J = get_Bernoulli(lambda, U1);
jump2 =  get_exp(1/mu_v, U2); 
jump1 = ( mu_y + rho_j * jump2 ) + abs(sig_y) * Z1; 
x1 = Z2; 
x2 = rho* Z2 + sqrt(1-rho^2)*Z3; 
V = zeros(n, tau);
t = 1;
V(:, 1) = alpha +  beta * V0 + sig_v * sqrt(V0) .* x2(:, t) + jump2(:, t).*J(:, t);

for t = 2: tau
    index = find( V(:, (t-1)) < 0 );
    if ~isempty(index)
        V(index, (t-1)) = 0;
    end
    V(:, t) = alpha +  beta * V(:, (t-1)) + sig_v * sqrt(V(:, t-1)) .* x2(:, t) + jump2(:, t).*J(:, t);
end

Y = zeros(n, tau);
t = 1;
Y(:, t) = mu + sqrt(V0) * x1(:, t) + jump1(:,t).*J(:, t);
for t = 2: tau
    Y(:, t) = mu + sqrt(V(:, t-1)) .* x1(:, t) + jump1(:,t).*J(:, t);
end
S = index_price * exp(cumsum(Y, 2));

Shat = 1/index_price;
delta_temp =  exp(-r*tau) * omega* Shat^2 * max( omega *(index_price - strike), 0);
delta = mean(delta_temp);
%}