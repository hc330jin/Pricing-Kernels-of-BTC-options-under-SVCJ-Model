% filename: run_daily_SV_calibration.m
% written by Chin HSU on 2026/05/17
% Descriptions: This file is to run daily SV calibration.

function result_SV = run_daily_SV_calibration(T, mc_size, use_parallel)

curr_model = 'SV';

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

if use_parallel
    pool = gcp('nocreate');
    if isempty(pool)
        parpool;
    end

    parfor k = 1:n_dates
        fprintf('\n===== Calibrating SV date: %s (%d/%d) =====\n', ...
            string(unique_dates(k)), k, n_dates);
        result_cells{k} = calibrate_one_SV_day( ...
            T_days{k}, unique_dates(k), k, mc_size, curr_model);
    end
else
    for k = 1:n_dates
        fprintf('\n===== Calibrating SV date: %s (%d/%d) =====\n', ...
            string(unique_dates(k)), k, n_dates);
        result_cells{k} = calibrate_one_SV_day( ...
            T_days{k}, unique_dates(k), k, mc_size, curr_model);
    end
end

result_SV = vertcat(result_cells{:});
result_SV = sortrows(result_SV, 'date');

writetable(result_SV, fullfile(folder_name, 'daily_SV_calibration.csv'));

end
