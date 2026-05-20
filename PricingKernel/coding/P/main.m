%% 
% filename: test_whole__data_param.m
% Original written by Wendy Huang
% Modify by Chris on 2026/05/13

close all;
clear all;
clc;
%% ======= Setting Control ========
% control.H = 90; % Use past H days
% control.h = 28; % Estimate future h days
control.model = 'SVCJ';
control.num_MCMC = 200000; % # MCMC iterations
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

date_p = dates_filtered;
n_dates = length(date_p);

switch control.model
    case 'BS'
        model_param_names = {'mu','V0','sigma_BS'};

    case 'SV'
        model_param_names = {'mu','rho','alpha','beta','V0','sigma_v'};

    case 'SVJ'
        model_param_names = {'mu','rho','alpha','beta','V0','sigma_v', ...
                             'lambda','mu_y','sigma_y'};

    case 'SVCJ'
        model_param_names = {'mu','rho','alpha','beta','V0','sigma_v', ...
                             'lambda','mu_y','rho_j','sigma_y','mu_v'};

    otherwise
        error('Unknown model for P parameter output: %s', control.model);
end

posterior = struct();
posterior.mu       = outputs.mu;
posterior.rho      = outputs.rho;
posterior.alpha    = outputs.alpha;
posterior.beta     = outputs.beta;
posterior.V0       = outputs.V0;
posterior.sigma_v  = outputs.sigma_v;
posterior.lambda   = outputs.lambda;
posterior.mu_y     = outputs.mu_y;
posterior.rho_j    = outputs.rho_j;
posterior.sigma_y  = outputs.sigma_y;
posterior.mu_v     = outputs.mu_v;
posterior.sigma_BS = sqrt(max(outputs.V0, 0));

trace = struct();
trace.mu       = outputs.mu_trace';
trace.rho      = outputs.rho_trace';
trace.alpha    = outputs.alpha_trace';
trace.beta     = outputs.beta_trace';
trace.V0       = outputs.V0_trace';
trace.sigma_v  = outputs.sigma_v_trace';
trace.lambda   = outputs.lambda_trace';
trace.mu_y     = outputs.mu_y_trace';
trace.rho_j    = outputs.rho_j_trace';
trace.sigma_y  = outputs.sigma_y_trace';
trace.mu_v     = outputs.mu_v_trace';
trace.sigma_BS = sqrt(max(outputs.V0_trace', 0));

T = table();
for j = 1:length(model_param_names)
    name = model_param_names{j};
    T.(name) = trace.(name);
end
T.LL = outputs.LL_trace_last';
writetable(T, fullfile(folder_name,'p_parameters_trace.csv'));

T_tmp = table(date_p, 'VariableNames', {'date'});
for j = 1:length(model_param_names)
    name = model_param_names{j};
    T_tmp.(name) = repmat(posterior.(name), n_dates, 1);
end
writetable(T_tmp, fullfile(folder_name, 'p_parameter_tmp.csv'));

T1 = table();
for j = 1:length(model_param_names)
    name = model_param_names{j};
    T1.(name) = posterior.(name);
end
T1.LL = outputs.LL;
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
if ismember(control.model, {'SVJ','SVCJ'})
    T5=table(outputs.J_trace);
    T5.Properties.VariableNames = {'J_trace'};
    writetable(T5, fullfile(folder_name,'J_trace.csv'));
end

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

plot_meta = struct();
plot_meta.mu       = {'\mu (Mean Return)', 'mu_plot.png'};
plot_meta.rho      = {'\rho (Leverage Effect)', 'rho_plot.png'};
plot_meta.alpha    = {'\alpha', 'alpha_plot.png'};
plot_meta.beta     = {'\beta', 'beta_plot.png'};
plot_meta.V0       = {'V0', 'V0_plot.png'};
plot_meta.sigma_v  = {'\sigma_v (Vol of Vol)', 'sig_v_plot.png'};
plot_meta.lambda   = {'\lambda (Jump Intensity)', 'lambda_plot.png'};
plot_meta.mu_y     = {'\mu_y (Jump Size Mean)', 'mu_y_plot.png'};
plot_meta.rho_j    = {'\rho_j (Jump Correlation)', 'rho_j_plot.png'};
plot_meta.sigma_y  = {'\sigma_y (Jump Size Vol)', 'sig_y_plot.png'};
plot_meta.mu_v     = {'\mu_v (Vol Jump Mean)', 'mu_v_plot.png'};
plot_meta.sigma_BS = {'\sigma_{BS}', 'sigma_BS_plot.png'};

for j = 1:length(model_param_names)
    name = model_param_names{j};
    meta = plot_meta.(name);
    plot_trace(trace.(name), meta{1}, meta{2}, folder_to_save);
end

% LL
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


