% filename: run_daily_BS_calibration.m
% written by Chin HSU on 2026/05/17
% Descriptions: This file is to run daily BS calibration.

function result_BS = run_daily_BS_calibration(T, mc_size)

curr_model = 'BS';

unique_dates = unique(T.date);
n_dates = length(unique_dates);

folder_name = sprintf('%s_calibration_%dpaths', curr_model, mc_size);

if ~exist(folder_name, 'dir')
    mkdir(folder_name);
end

result_cells = cell(n_dates, 1);

for k = 1:n_dates
    current_date = unique_dates(k);

    fprintf('\n===== Calibrating BS date: %s (%d/%d) =====\n', ...
        string(current_date), k, n_dates);

    T_day = T(T.date == current_date, :);

    result_cells{k} = calibrate_one_BS_day( ...
        T_day, current_date, mc_size, curr_model);
end

result_BS = vertcat(result_cells{:});
result_BS = sortrows(result_BS, 'date');

writetable(result_BS, fullfile(folder_name, 'daily_BS_calibration.csv'));

end
