% filename: run_daily_SVJ_calibration.m
% written by Chin HSU on 2026/05/15
% Descriptions: This file is to run daily SVJ calibration

function result_SVJ = run_daily_SVJ_calibration(T, mc_size, use_parallel)

curr_model = 'SVJ';

if use_parallel
    para_or_not = 'par';
else
    para_or_not = 'seq';
end

unique_dates = unique(T.date);
n_dates = length(unique_dates);

folder_name = sprintf('%s_calibration_%dpaths_%s', curr_model, mc_size, para_or_not);

if ~exist(folder_name, 'dir')
    mkdir(folder_name);
end

T_days = cell(n_dates, 1);

for k = 1:n_dates
    T_days{k} = T(T.date == unique_dates(k), :);
end

result_cells = cell(n_dates, 1);

if use_parallel % 如果用平行處理
    pool = gcp('nocreate');
    if isempty(pool)
        parpool;
    end

    % Use calibrate_one_SVJ_day 處理單日的校正
    parfor k = 1:n_dates
        fprintf('\n===== Calibrating SVJ date: %s (%d/%d) =====\n', ...
            string(unique_dates(k)), k, n_dates);
        result_cells{k} = calibrate_one_SVJ_day( ...
            T_days{k}, unique_dates(k), k, mc_size, curr_model);
    end
else
    for k = 1:n_dates
        fprintf('\n===== Calibrating SVJ date: %s (%d/%d) =====\n', ...
            string(unique_dates(k)), k, n_dates);

        result_cells{k} = calibrate_one_SVJ_day( ...
            T_days{k}, unique_dates(k), k, mc_size, curr_model);
    end
end

result_SVJ = vertcat(result_cells{:});
result_SVJ = sortrows(result_SVJ, 'date');

writetable(result_SVJ, fullfile(folder_name, 'daily_SVJ_calibration.csv'));

end
