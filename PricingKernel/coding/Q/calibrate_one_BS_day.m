% filename: calibrate_one_BS_day.m
% written by Chin HSU on 2026/05/17
% Descriptions: This file is to run BS calibration for just ONE DAY.

function result_row = calibrate_one_BS_day(T_day, current_date, mc_size, curr_model)

result_row = make_BS_result_row(current_date);

try
    if height(T_day) == 0
        return;
    end

    p_day = T_day.p;

    [omega_base_day, maturity_base_day, strike_base_day, ...
        index_price_base_day, d_base_day, ic_day, n_base_day] = ...
        make_daily_contract_base(T_day);

    [param0, options] = make_BS_settings();

    U_base_day = [];
    Z_base_day = [];

    fun = @(param)obj_fminsearch( ...
        param, curr_model, mc_size, U_base_day, Z_base_day, p_day, ...
        index_price_base_day, omega_base_day, d_base_day, ...
        maturity_base_day, strike_base_day, ic_day ...
    );

    tic;

    [param_BS_day, fval_BS_day, exitflag_BS_day] = ...
        fminsearch(fun, param0, options);

    elapsed_time = toc;

    result_row.sigma_BS   = param_BS_day;
    result_row.SSE_BS     = fval_BS_day;
    result_row.RMSE_BS    = sqrt(fval_BS_day / length(p_day));
    result_row.n_obs      = length(p_day);
    result_row.n_contract = n_base_day;
    result_row.exitflag   = exitflag_BS_day;
    result_row.elapsed_sec = elapsed_time;

    fprintf('Date = %s | sigma = %.6f | RMSE = %.6f | time = %.2f sec\n', ...
        string(current_date), param_BS_day, result_row.RMSE_BS, elapsed_time);

catch ME
    warning('BS calibration failed for %s: %s', ...
        string(current_date), ME.message);
end

end
