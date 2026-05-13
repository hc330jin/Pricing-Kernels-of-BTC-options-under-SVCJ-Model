% filename: get_SVCJ.m
% updated by Chris Hsu on 2026/5/12

function S = get_SVCJ(U, Z, param, index_price)

% get_SVCJ
%
% Simulate asset price paths under the SVCJ model.
%
% param =
% [mu, rho, alpha, beta, V0, sig_v,
%  lambda, mu_y, rho_j, sig_y, mu_v]

mu      = param(1);
rho     = param(2);
alpha   = param(3);
beta    = param(4);
V0      = param(5);
sig_v   = param(6);

lambda  = param(7);

mu_y    = param(8);
rho_j   = param(9);
sig_y   = param(10);

mu_v    = param(11);

%% ===== Dimensions =====

[n2, T] = size(U);

n = n2 / 2;

if mod(n2,2) ~= 0
    error('get_SVCJ: U must have 2*n rows.');
end

[n3, T2] = size(Z);

if T ~= T2
    error('get_SVCJ: U and Z must have same number of columns.');
end

if n3 ~= 3*n
    error('get_SVCJ: Z must have 3*n rows.');
end

%% ===== Extract random variables =====

U1 = U(1:n,:);
U2 = U(n+1:2*n,:);

Z1 = Z(1:n,:);
Z2 = Z(n+1:2*n,:);
Z3 = Z(2*n+1:3*n,:);

%% ===== Jump indicator =====

J = get_Bernoulli(lambda, U1);

%% ===== Variance jump =====

jump_v = get_exp(1/mu_v, U2);

%% ===== Return jump =====

jump_y = (mu_y + rho_j .* jump_v) ...
       + abs(sig_y) .* Z1;

%% ===== Correlated diffusion shocks =====

eps_y = Z2;

eps_v = rho .* Z2 + sqrt(1-rho^2) .* Z3;

%% ===== Initialize =====

V = zeros(n, T);
Y = zeros(n, T);

%% ===== t = 1 =====

V_prev = max(V0,0);

Y(:,1) = mu ...
       + sqrt(V_prev) .* eps_y(:,1) ...
       + jump_y(:,1) .* J(:,1);

V(:,1) = alpha ...
       + beta .* V_prev ...
       + sig_v .* sqrt(V_prev) .* eps_v(:,1) ...
       + jump_v(:,1) .* J(:,1);

V(:,1) = max(V(:,1),0);

%% ===== t = 2,...,T =====

for t = 2:T

    V_prev = max(V(:,t-1),0);

    Y(:,t) = mu ...
           + sqrt(V_prev) .* eps_y(:,t) ...
           + jump_y(:,t) .* J(:,t);

    V(:,t) = alpha ...
           + beta .* V_prev ...
           + sig_v .* sqrt(V_prev) .* eps_v(:,t) ...
           + jump_v(:,t) .* J(:,t);

    V(:,t) = max(V(:,t),0);

end

%% ===== Price paths =====

S = index_price .* exp(cumsum(Y,2));

end