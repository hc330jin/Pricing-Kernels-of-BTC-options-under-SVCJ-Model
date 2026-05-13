% filename: get_SV.m
% updated by Chris Hsu on 2026/5/12

function S = get_SV(Z, param, index_price)

% get_SV simulates price paths under the stochastic volatility model.
%
% param = [mu, rho, alpha, beta, V0, sig_v]
%
% Y_t = mu + sqrt(V_{t-1}) * eps_y,t
% V_t = alpha + beta * V_{t-1} + sig_v * sqrt(V_{t-1}) * eps_v,t
% S_t = S_0 * exp(Y_1 + ... + Y_t)

mu    = param(1);
rho   = param(2);
alpha = param(3);
beta  = param(4);
V0    = param(5);
sig_v = param(6);

[n2, T] = size(Z);
n = n2 / 2;

if mod(n2, 2) ~= 0
    error('get_SV: Z must have 2*n rows.');
end

Z1 = Z(1:n, :);
Z2 = Z(n+1:2*n, :);

% Return shock and volatility shock
eps_y = Z1;
eps_v = rho * Z1 + sqrt(1 - rho^2) * Z2;

V = zeros(n, T);
Y = zeros(n, T);

% t = 1
V_prev = max(V0, 0);

Y(:,1) = mu + sqrt(V_prev) .* eps_y(:,1);

V(:,1) = alpha ...
       + beta * V_prev ...
       + sig_v * sqrt(V_prev) .* eps_v(:,1);

V(:,1) = max(V(:,1), 0);

% t = 2, ..., T
for t = 2:T

    V_prev = max(V(:,t-1), 0);

    Y(:,t) = mu + sqrt(V_prev) .* eps_y(:,t);

    V(:,t) = alpha ...
           + beta * V_prev ...
           + sig_v * sqrt(V_prev) .* eps_v(:,t);

    V(:,t) = max(V(:,t), 0);

end

S = index_price * exp(cumsum(Y, 2));

end