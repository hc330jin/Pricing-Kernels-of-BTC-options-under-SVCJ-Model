% filename: calibrate_one_SVJ_day.m
% written by Chin HSU on 2026/05/15
% Descriptions: This file is to run SVJ calibration for just ONE DAY

function result_row = calibrate_one_SVJ_day(T_day, current_date, k, mc_size, curr_model)

result_row = make_SVJ_result_row(current_date);

try
    if height(T_day) == 0
        return;
    end

    p_day = T_day.p;

    nDay_max_day = max(T_day.DTM);

    rng(114514 + k, 'twister'); % fixed stream for sequential/parallel comparison

    U_base_day = rand([2 * mc_size, nDay_max_day]);
    Z_base_day = randn([3 * mc_size, nDay_max_day]);

    [omega_base_day, maturity_base_day, strike_base_day, ...
        index_price_base_day, d_base_day, ic_day, n_base_day] = ...
        make_daily_contract_base(T_day);

    [param0, lb, ub, options] = make_SVJ_settings();
    % Use make_SVJ_settings to set initial values, upper/lower bound
    % number of max iteration, function tolerance

    fun = @(param)obj_lsqnonlin( ...
        param, curr_model, mc_size, p_day, U_base_day, Z_base_day, ...
        index_price_base_day, omega_base_day, d_base_day, ...
        maturity_base_day, strike_base_day, ic_day ...
    );

    tic;

    [param_SVJ_day, resnorm_SVJ_day, ~, exitflag_SVJ_day, output_SVJ_day] = ...
        lsqnonlin(fun, param0, lb, ub, options);

    elapsed_time = toc;

    result_row.mu       = param_SVJ_day(1);
    result_row.rho      = param_SVJ_day(2);
    result_row.alpha    = param_SVJ_day(3);
    result_row.beta     = param_SVJ_day(4);
    result_row.V0       = param_SVJ_day(5);
    result_row.sigma_v  = param_SVJ_day(6);
    result_row.lambda   = param_SVJ_day(7);
    result_row.mu_y     = param_SVJ_day(8);
    result_row.sigma_y  = param_SVJ_day(9);

    result_row.SSE_SVJ    = resnorm_SVJ_day;
    result_row.RMSE_SVJ   = sqrt(resnorm_SVJ_day / length(p_day));
    result_row.n_obs       = length(p_day);
    result_row.n_contract  = n_base_day;
    result_row.exitflag    = exitflag_SVJ_day;
    result_row.elapsed_sec = elapsed_time;

    fprintf('Finished %s | RMSE = %.6f | time = %.2f sec\n', ...
    string(current_date), result_row.RMSE_SVJ, elapsed_time);

catch ME
    warning('SVJ calibration failed for %s: %s', ...
        string(current_date), ME.message);
end

end
