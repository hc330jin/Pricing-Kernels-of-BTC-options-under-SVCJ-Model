%% 
% filename: test_whole__data_param.m
% Written by Wendy Huang on 20250210
% Modify by Chris on 2026/05/13

close all;
clear all;
clc;
%% ======= Setting Control ========
% control.H = 90; % Use past H days
% control.h = 28; % Estimate future h days
control.model = 'SVCJ';
control.num_MCMC = 100000; % # MCMC iterations
control = define_flag(control);
control.num_paths = 1000;
% control.T = control.h; % Generate h days of return
control.dt = 1;
control.SMALL = 1e-10;
control.Alpha = 0.05;


%% ======= Loading Data ========
data = readtable("whole_data.csv");
price = load_real_data(data);

start_date = datetime('2021-11-01'); % <-- Here to modify start date
end_date   = datetime('2022-01-29'); % <-- Here to modify  end  date

date_col = price.date_column;

if ~isdatetime(date_col)
    date_col = datetime(date_col, 'InputFormat', 'yyyy-MM-dd');
end

mask = (date_col >= start_date) & (date_col <= end_date);

assetMap = containers.Map( ...
    {'SPX','DTTF','EUS','HSI','BITCOIN','GOLD','USD'}, ...
    [1,2,3,4,5,6,7] ...
);

asset_to_estimate = 'BITCOIN'; % <-- Here to modify asset
no_asset = assetMap(asset_to_estimate);

prices_filtered = price.numericData(mask, no_asset);
Returns_all = diff(log(prices_filtered)); % Daily return

% Returns_all=(prices(2:end)-prices(1:end-1)) ./prices(1:end-1);

steps = length(Returns_all);
dates_filtered = date_col(mask);

N = 1;
s = asset_to_estimate;

%% ======= Save Setting ========
% Create folder
folder_name = sprintf('%s_%d_estimate_%s_%d', control.model, control.num_MCMC, s, N);
% Ensure folder exists
if ~exist(folder_name, 'dir')
    mkdir(folder_name);
end

% Create the filename for saving
filename_mat = fullfile(folder_name, sprintf('%s_%d_mcmc_results_%s_%d.mat', control.model, control.num_MCMC, s, N));



%% ======= MCMC Setting ========
% Returns = Returns_all(N:N+steps-1);
Volatility = std(Returns_all)^2; % Daily volatility
Y = Returns_all';
mySelf = my_self(s, N, Y, steps);

% Modify step (if needed)
mySelf.stdevSig2V = 0.005;
% mySelf.stdevV = ;
% mySelf.stdevV0 = ;
% mySelf.stdevrho = ;

% disp(Y)
control.T = length(Returns_all);
control.H = length(Returns_all);

param = define_param(control.model);

control = define_flag(control);


%% ======= RUNNING MCMC ========
tic
outputs = run_MCMC(control, param, Y, mySelf);
toc


%% ======= Writing Table =======

% T: Parameters trace (after burn-in)
T=table(outputs.V0_trace',outputs.mu_trace' ,outputs.alpha_trace' ,outputs.beta_trace' ,outputs.sigma_v_trace',...
outputs.mu_y_trace',outputs.sigma_y_trace',outputs.rho_trace',outputs.rho_j_trace',outputs.mu_v_trace',...
outputs.lambda_trace', outputs.LL_trace_last');
T.Properties.VariableNames = {'V0', 'mu', 'alpha', 'beta', 'sigma_v', 'mu_y', 'sigma_y', 'rho', 'rho_j', 'mu_v', 'lambda', 'LL'};
writetable(T, fullfile(folder_name,'p_parameters_trace.csv'));


% T_tmp: save one P-measure posterior mean for all 90 days

% 90-day dates
date_p = dates_filtered;   % size should be 90 x 1

% Posterior means after burn-in / final posterior mean
V0_p       = outputs.V0;
mu_p       = outputs.mu;
alpha_p    = outputs.alpha;
beta_p     = outputs.beta;
sigma_v_p  = outputs.sigma_v;
mu_y_p     = outputs.mu_y;
sigma_y_p  = outputs.sigma_y;
rho_p      = outputs.rho;
rho_j_p    = outputs.rho_j;
mu_v_p     = outputs.mu_v;
lambda_p   = outputs.lambda;

% Repeat the same posterior mean for each date
n_dates = length(date_p);

T_tmp = table( ...
    date_p, ...
    repmat(mu_p,      n_dates, 1), ...
    repmat(rho_p,     n_dates, 1), ...
    repmat(alpha_p,   n_dates, 1), ...
    repmat(beta_p,    n_dates, 1), ...
    repmat(V0_p,      n_dates, 1), ...
    repmat(sigma_v_p, n_dates, 1), ...
    repmat(lambda_p,  n_dates, 1), ...
    repmat(mu_y_p,    n_dates, 1), ...
    repmat(rho_j_p,   n_dates, 1), ...
    repmat(sigma_y_p, n_dates, 1), ...
    repmat(mu_v_p,    n_dates, 1), ...
    'VariableNames', {'date','mu','rho','alpha','beta','V0','sigma_v', ...
                      'lambda','mu_y','rho_j','sigma_y','mu_v'} ...
);

writetable(T_tmp, fullfile(folder_name, 'p_parameter_tmp.csv'));



% T1: parameters (posterior mean)
T1=table(outputs.V0', outputs.mu', outputs.mu_y', outputs.sigma_y', ...
outputs.lambda', outputs.alpha', outputs.beta', outputs.rho', ...
outputs.sigma_v', outputs.rho_j', outputs.mu_v, outputs.LL);
T1.Properties.VariableNames = {'V0', 'mu', 'mu_y', 'sigma_y', 'lambda', 'alpha', 'beta', 'rho', 'sigma_v', 'rho_j', 'mu_v', 'LL'};
writetable(T1, fullfile(folder_name,'p_parameter.csv'));

% T2: Latent Variable to latent_trace.csv
if strcmp(control.model, 'SVCJ')
    T2=table(outputs.V', outputs.J', outputs.ZY', outputs.ZV');
    T2.Properties.VariableNames = {'V', 'J', 'ZY', 'ZV'};
    writetable(T2, fullfile(folder_name,'latent_trace.csv'));
elseif strcmp(control.model, 'SV')
    T2=table(outputs.V');
    T2.Properties.VariableNames = {'V'};
    writetable(T2, fullfile(folder_name,'latent_trace.csv'));
end

% T3: Return to return.csv
% T3 = table(price.date_column(N+1:N+steps), Y');
T3 = table(dates_filtered(N+1:N+steps), Y');
writetable(T3, fullfile(folder_name,'return.csv'), 'WriteVariableNames',false);

% T4: All LL trace to LL_trace.csv
T4=table(outputs.LL_trace');
T4.Properties.VariableNames = {'LL'};
writetable(T4, fullfile(folder_name,'LL_trace.csv'));

% T5: J trace to J_trace.csv
T5=table(outputs.J_trace);
T5.Properties.VariableNames = {'J_trace'};
writetable(T5, fullfile(folder_name,'J_trace.csv'));

% T6: Accept Rate to acceptRate.csv
T6=table(outputs.acceptV0, outputs.acceptrho, outputs.accepts2V, outputs.acceptV);
T6.Properties.VariableNames = {'acceptV0', 'acceptrho', 'accepts2V', 'acceptV'};
writetable(T6, fullfile(folder_name,'acceptRate.csv'));

% Save the param and output structures
save(filename_mat, 'control', '-v7.3');
fprintf('Saved control for model %s in %s\n', control.model, filename_mat);

% Save the outputs structure in mcmc_results.mat file
save(filename_mat, 'outputs', '-append');
fprintf('Saved outputs to %s\n', filename_mat);


%% ======= Plotting =======
% --- Visualization & Saving Trace Plots ---
fprintf('Plotting and saving parameter trace plots...\n');
folder_to_save = folder_name; 

% plot_trace
plot_trace = @(data, title_str, fname, path) ...
    save_plot_func(data, title_str, fname, path);

% 1. Mu (Mean Return)
if isfield(outputs, 'mu_trace')
    plot_trace(outputs.mu_trace, '\mu (Mean Return)', 'mu_plot.png', folder_to_save);
end

% 2. Alpha (Mean Reversion Level component)
if isfield(outputs, 'alpha_trace')
    plot_trace(outputs.alpha_trace, '\alpha', 'alpha_plot.png', folder_to_save);
end

% 3. Beta (Mean Reversion Speed component)
if isfield(outputs, 'beta_trace')
    plot_trace(outputs.beta_trace, '\beta', 'beta_plot.png', folder_to_save);
end

% 4. Sigma_v (Vol of Vol)
if isfield(outputs, 'sigma_v_trace')
    plot_trace(outputs.sigma_v_trace, '\sigma_v (Vol of Vol)', 'sig_v_plot.png', folder_to_save);
end

% 5. Rho (Correlation)
if isfield(outputs, 'rho_trace')
    plot_trace(outputs.rho_trace, '\rho (Leverage Effect)', 'rho_plot.png', folder_to_save);
end

% 6. Mu_y (Jump Size Mean)
if isfield(outputs, 'mu_y_trace')
    plot_trace(outputs.mu_y_trace, '\mu_y (Jump Size Mean)', 'mu_y_plot.png', folder_to_save);
end

% 7. Sigma_y (Jump Size Volatility)
if isfield(outputs, 'sigma_y_trace')
    plot_trace(outputs.sigma_y_trace, '\sigma_y (Jump Size Vol)', 'sig_y_plot.png', folder_to_save);
end

% 8. Rho_j (Jump Correlation)
if isfield(outputs, 'rho_j_trace')
    plot_trace(outputs.rho_j_trace, '\rho_j (Jump Correlation)', 'rho_j_plot.png', folder_to_save);
end

% 9. Mu_v (Volatility Jump Mean)
if isfield(outputs, 'mu_v_trace')
    plot_trace(outputs.mu_v_trace, '\mu_v (Vol Jump Mean)', 'mu_v_plot.png', folder_to_save);
end

% 10. Lambda (Jump Intensity)
if isfield(outputs, 'lambda_trace')
    plot_trace(outputs.lambda_trace, '\lambda (Jump Intensity)', 'lambda_plot.png', folder_to_save);
end

% 11. LL
if isfield(outputs, 'LL_trace')
    plot_trace(outputs.LL_trace, 'LL (likelihood)', 'LL_plot.png', folder_to_save);
end

fprintf('All figures saved to: %s\n', folder_to_save);
% N=N+steps;

% --- Local Function for Plotting  ---
function save_plot_func(data, title_str, fname, path)
    fig = figure('Visible', 'off'); 
    plot(data);
    title(title_str, 'FontSize', 14, 'Interpreter', 'tex');
    xlabel('Iterations'); 
    ylabel('Value');
    grid off;
    
    % saveas(fig, fullfile(path, fname));

    set(gcf,'color','none');
    set(gca,'color','none');
    export_fig(fullfile(path, fname), '-png', '-transparent', '-r300', '-opengl');
    close(fig);
end
%% ======= Plotting =======


%% ======= Check result =======


