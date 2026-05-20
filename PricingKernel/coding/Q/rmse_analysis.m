% filename: rmse_analysis.m
% written by Chin HSU on 2026/05/14
% Descriptions: to analyze RMSE for 4 models
clc; clear all; close all;

%% ===== Settings =====

mc_size = 50;

models = {'BS','SV','SVJ','SVCJ'};

para_or_not = 'par'; % or 'seq'

rmse_vars = containers.Map;
rmse_vars('BS')   = 'RMSE_BS';
rmse_vars('SV')   = 'RMSE_SV';
rmse_vars('SVJ')  = 'RMSE_SVJ';
rmse_vars('SVCJ') = 'RMSE_SVCJ';

file_names = containers.Map;
file_names('BS')   = 'daily_BS_calibration.csv';
file_names('SV')   = 'daily_SV_calibration.csv';
file_names('SVJ')  = 'daily_SVJ_calibration.csv';
file_names('SVCJ') = 'daily_SVCJ_calibration.csv';

%% ===== Load RMSE data =====

rmse_table = table;

for i = 1:length(models)

    model = models{i};

    switch model
        case 'BS'
            folder_name = sprintf('%s_calibration_%dpaths', model, mc_size);

        otherwise
            folder_name = sprintf('%s_calibration_%dpaths_%s', model, mc_size, para_or_not);
    end

    input_file = fullfile(folder_name, file_names(model));

    if ~isfile(input_file)
        warning('File not found: %s', input_file);
        continue;
    end

    T_model = readtable(input_file);

    if i == 1
        rmse_table.date = T_model.date;
    end

    rmse_table.(model) = T_model.(rmse_vars(model));

end

%% ===== Output Folder =====

output_folder = sprintf('RMSE_analysis_%dpaths', mc_size);

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

writetable(rmse_table, fullfile(output_folder, 'rmse_summary_timeseries.csv'));

%% ===== Prepare matrix for plotting =====

available_models = rmse_table.Properties.VariableNames(2:end);

RMSE = rmse_table{:, available_models};

%% ===== Figure: Boxplot + Time Series =====

fig = figure;
set(fig, 'Position', [100, 100, 1000, 750]);

%% ===== Upper Panel: Boxplot =====

subplot(2,1,1);

boxplot(RMSE, ...
    'Labels', available_models, ...
    'Orientation', 'horizontal', ...
    'Colors','b', ...
    'Symbol','r+', ...
    'Widths',0.5);

h = findobj(gca,'Tag','Box');

for j = 1:length(h)
    set(h(j), ...
        'Color','b', ...
        'LineWidth',1.5);
end

title('In-sample RMSE', 'Color',[0,0,0]);
xlabel('RMSE');
grid off;

set(gca, 'YDir', 'reverse');


ax1 = gca;

set(ax1, ...
    'Color', 'none', ...
    'XColor', 'k', ...
    'YColor', 'k');

%% ===== Lower Panel: Time Series =====

subplot(2,1,2);
hold on;

line_styles = {'c-', 'r-', 'g-', 'b:'};
line_widths = [2.5, 1.8, 2.5, 2.5];

for i = 1:length(available_models)

    plot(rmse_table.date, rmse_table.(available_models{i}), ...
        line_styles{i}, ...
        'LineWidth', line_widths(i));

end

xlabel('Date');
ylabel('In-sample RMSE');
title('');
legend(available_models, 'Location', 'northeast');

ax2 = gca;

set(ax2, ...
    'Color', 'none', ...
    'XColor', 'k', ...
    'YColor', 'k');

%% ===== Save Figure =====


% saveas(fig, fullfile(output_folder, 'In_sample_RMSE_comparison.png'));

set(gcf,'color','none');
set(gca,'color','none');

if exist('export_fig', 'file')
    export_fig(fullfile(output_folder, 'In_sample_RMSE_comparison'), ...
        '-png', '-r300');
end

close(fig);

%% ===== Summary Table =====

summary_RMSE = table;

for i = 1:length(available_models)

    model = available_models{i};
    x = rmse_table.(model);

    summary_RMSE.Model(i,1)  = string(model);
    summary_RMSE.Mean(i,1)   = mean(x, 'omitnan');
    summary_RMSE.Std(i,1)    = std(x, 'omitnan');
    summary_RMSE.Min(i,1)    = min(x, [], 'omitnan');
    summary_RMSE.Median(i,1) = median(x, 'omitnan');
    summary_RMSE.Max(i,1)    = max(x, [], 'omitnan');

end

writetable(summary_RMSE, fullfile(output_folder, 'rmse_summary_statistics.csv'));

disp(summary_RMSE);

fprintf('\nRMSE analysis finished.\n');
fprintf('Results saved in: %s\n', output_folder);