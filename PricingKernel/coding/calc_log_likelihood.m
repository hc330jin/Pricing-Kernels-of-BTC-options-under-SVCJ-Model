% filename: calc_log_likelihood.m
% Inputs:
%   Y        - Observed data (vector)
%   V        - Latent variables (vector)
%   V0       - Initial variance
%   ZY, ZV   - Latent factors (vectors)
%   J        - Jump variables (vector)
%   control  - Struct containing dt (time step) and T (number of time steps)
%   m, alpha, beta, rho, sig2V - Model parameters
%
% Output:
%   logL - Log-likelihood value (scalar)

function logL = calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V)

% % Initialize log-likelihood
% logL = 0;
%
% % Precompute constants for efficiency
% dt = control.dt;
% T = control.T;
%
% % t=1
% logL = logL - 0.5 * log(2 * pi * (V0 * dt * (1 - rho^2))) - 0.5 * ((Y(1) - (m * dt + ZY(1) * J(1) + (rho / sqrt(sig2V)) * (V(1) - ((alpha + (1 / dt + beta) * V0) * dt + ZV(1) * J(1)))))^2 / (V0 * dt * (1 - rho^2)));
%
% % Loop over t = 2 to T
% for t = 2:T
%
%     % Compute log probability for Y_t
%     log_prob = -0.5 * log(2 * pi * (V(t-1) * dt * (1 - rho^2))) - 0.5 * ((Y(t) - (m * dt + ZY(t) * J(t) + (rho / sqrt(sig2V)) * (V(t) - ((alpha + (1 / dt + beta) * V(t-1)) * dt + ZV(t) * J(t)))))^2 / (V(t-1) * dt * (1 - rho^2)));
%
%     % Accumlate log-likelihood
%     logL = logL + log_prob;
% end

% sum(-0.5 * log(2 * pi * (1 - rho^2) .* [V0 V(1:end-1)] * control.dt) + (-(Y - (m * control.dt + ZY .* J) - ((rho / sqrt(sig2V)) * (V - (alpha + (1 / control.dt + beta) * [V0 V(1:end-1)]) * control.dt + ZV .* J)) .^ 2)/2 * [V0 V(1:end-1)] * control.dt * (1 - rho^2)));
%
%{
logL = sum( -0.5 * log(2 * pi * (1 - rho^2) .* [V0 V(1:end-1)] .* control.dt) + ...
    (-((Y - (m * control.dt + ZY .* J) - ((rho / sqrt(sig2V)) .* ...
    (V - ((alpha + (1 / control.dt + beta) .* [V0 V(1:end-1)]) .* control.dt + ZV .* J)))) .^ 2) ...
    ./ (2 * [V0 V(1:end-1)] .* control.dt * (1 - rho^2))));
%}
% 1. V 方程的殘差與 Log-L
prevV=[V0 V(1:end-1)];
dt=control.dt;
eps_V = V - prevV - (alpha + beta*prevV)*dt - ZV.*J;
logL_V = sum(-0.5*log(2*pi*sig2V*prevV*dt) - (eps_V.^2)./(2*sig2V*prevV*dt), "all");

% 2. Y 方程的殘差 (已考慮相關性 rho) 與 Log-L
% 注意：你的公式中 ZY 也要乘上 J
eps_Y = Y - mu*dt - ZY.*J - (rho/sqrt(sig2V)) * eps_V;
logL_Y_given_V = sum(-0.5*log(2*pi*(1-rho^2)*prevV*dt) - (eps_Y.^2)./(2*(1-rho^2)*prevV*dt), "all");

% 3. 總似然
logL = logL_V + logL_Y_given_V;
%}
end

