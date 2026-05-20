function [omega_base_day, maturity_base_day, strike_base_day, ...
          index_price_base_day, d_base_day, ic_day, n_base_day, ...
          contract_base_table_day] = make_daily_contract_base(T_day)

% make_daily_contract_base
%
% Construct unique option contracts for one trading day.
%
% Inputs:
%   T_day : one-day option data table
%
% Outputs:
%   omega_base_day       : call/put indicator for unique contracts
%   maturity_base_day    : days to maturity for unique contracts
%   strike_base_day      : strike for unique contracts
%   index_price_base_day : index price for unique contracts
%   d_base_day           : current day index, fixed at zero
%   ic_day               : map from original rows to unique contracts
%   n_base_day           : number of unique contracts
%   contract_base_table_day : unique contract table

contract_table_day = table( ...
    T_day.omega, ...
    T_day.DTM, ...
    T_day.strike, ...
    T_day.index_price, ...
    'VariableNames', {'omega','DTM','strike','index_price'} ...
);

[contract_base_table_day, ~, ic_day] = ...
    unique(contract_table_day, 'rows', 'stable');

n_base_day = height(contract_base_table_day);

omega_base_day       = contract_base_table_day.omega;
maturity_base_day    = contract_base_table_day.DTM;
strike_base_day      = contract_base_table_day.strike;
index_price_base_day = contract_base_table_day.index_price;

d_base_day = zeros(n_base_day, 1);

end