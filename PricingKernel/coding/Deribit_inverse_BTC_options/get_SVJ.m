% filename: get_SVJ.m
% updated by Chris Hsu on 2026/5/12

function S = get_SVJ(U, Z, param, index_price)

% get_SVJ
%
% Simulate asset price paths under the SVJ model.
%
% param =
% [mu, rho, alpha, beta, V0, sig_v, lambda, mu_y, sig_y]

mu      = param(1);
rho     = param(2);
alpha   = param(3);
beta    = param(4);
V0      = param(5);
sig_v   = param(6);
lambda  = param(7);
mu_y    = param(8);
sig_y   = param(9);

[n, T] = size(U);

[n3, T2] = size(Z);

if T ~= T2
    error('get_SVJ: U and Z must have same number of columns.');
end

if n3 ~= 3*n
    error('get_SVJ: Z must have 3*n rows.');
end

%% ===== Extract random variables =====

Z1 = Z(1:n, :);
Z2 = Z(n+1:2*n, :);
Z3 = Z(2*n+1:3*n, :);

%% ===== Jump indicator =====

J = get_Bernoulli(lambda, U);

%% ===== Return jump =====

jump_y = mu_y + abs(sig_y) .* Z1;

%% ===== Correlated shocks =====

eps_y = Z2;

eps_v = rho .* Z2 + sqrt(1-rho^2) .* Z3;

%% ===== Initialize =====

V = zeros(n, T);
Y = zeros(n, T);

%% ===== t = 1 =====

V_prev = max(V0, 0);

Y(:,1) = mu ...
       + sqrt(V_prev) .* eps_y(:,1) ...
       + jump_y(:,1) .* J(:,1);

V(:,1) = alpha ...
       + beta .* V_prev ...
       + sig_v .* sqrt(V_prev) .* eps_v(:,1);

V(:,1) = max(V(:,1), 0);

%% ===== t = 2,...,T =====

for t = 2:T

    V_prev = max(V(:,t-1), 0);

    Y(:,t) = mu ...
           + sqrt(V_prev) .* eps_y(:,t) ...
           + jump_y(:,t) .* J(:,t);

    V(:,t) = alpha ...
           + beta .* V_prev ...
           + sig_v .* sqrt(V_prev) .* eps_v(:,t);

    V(:,t) = max(V(:,t), 0);

end

%% ===== Price process =====

S = index_price .* exp(cumsum(Y,2));

end