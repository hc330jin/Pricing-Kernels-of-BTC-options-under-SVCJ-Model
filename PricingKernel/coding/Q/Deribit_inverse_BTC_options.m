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
fprintf('Start calibrating BS model\n')
curr_model = 'BS';
mc_size = 50; % Monte Carlo sample size
para_or_not = '';

folder_name = sprintf('%s_calibration_%dpaths', curr_model, mc_size);

result_BS = run_daily_BS_calibration(T, mc_size);

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

% ===== Analysis of BS =====

analyze_Q_results(curr_model, mc_size, para_or_not);



%% ======= Daily Calibration: SV Model =======
fprintf('Start calibrating SV model\n')

curr_model = 'SV';
mc_size = 50;
use_parallel = true;
labels = {'seq', 'par'};
para_or_not = labels{use_parallel + 1};


result_SV = run_daily_SV_calibration(T, mc_size, use_parallel);

folder_name = sprintf('%s_calibration_%dpaths_%s', curr_model, mc_size, para_or_not);

% ===== Analyze result =====
analyze_Q_results(curr_model, mc_size, para_or_not);

%% ======= Daily Calibration: SVJ Model =======
fprintf('Start calibrating SVJ model\n')

curr_model = 'SVJ';
mc_size = 50;
use_parallel = true;
labels = {'seq', 'par'};
para_or_not = labels{use_parallel + 1};

result_SVJ = run_daily_SVJ_calibration(T, mc_size, use_parallel);

folder_name = sprintf('%s_calibration_%dpaths_%s', curr_model, mc_size, para_or_not);

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

% ===== Analyze result =====
analyze_Q_results(curr_model, mc_size, para_or_not);


%% ======= Daily Calibration: SVCJ Model =======
curr_model = 'SVCJ';
mc_size = 50;
use_parallel = true;
labels = {'seq', 'par'};
para_or_not = labels{use_parallel + 1};

folder_name = sprintf('%s_calibration_%dpaths_%s', curr_model, mc_size, para_or_not);

if ~exist(folder_name, 'dir')
    mkdir(folder_name);
end

result_SVCJ = run_daily_SVCJ_calibration(T, mc_size, use_parallel);


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
% ===== Analysis of SVCJ =====
analyze_Q_results(curr_model, mc_size, para_or_not);
