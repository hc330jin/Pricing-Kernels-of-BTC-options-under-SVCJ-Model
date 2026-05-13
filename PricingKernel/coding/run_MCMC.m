% filename: run_MCMC.m
% Written by Wendy Huang on 20250207

% INPUTS
% control: control in the setting
% param = define_param(control, param)
% Y: returns
% OUTPUTS
% outputs: a structure containing all mcmc results

function outputs = run_MCMC(control, param, Y, mySelf)
%control.update_lambda=false;

%% ======= Prepare Result Storage ========
T = control.H;
n = control.num_MCMC*0.5; % <-- Here to modify burn-in
% Initialize variables for storing results
mu_trace = zeros(1, control.num_MCMC-n);%[]
alpha_trace = zeros(1, control.num_MCMC-n);%[]
beta_trace = zeros(1, control.num_MCMC-n);%[]
sigma_v_trace = zeros(1, control.num_MCMC-n);%[]
mu_y_trace = zeros(1, control.num_MCMC-n);%[]
sigma_y_trace = zeros(1, control.num_MCMC-n);%[]
rho_trace = zeros(1, control.num_MCMC-n);%[]
rho_j_trace = zeros(1, control.num_MCMC-n);%[]
mu_v_trace = zeros(1, control.num_MCMC-n);%[]
lambda_trace = zeros(1, control.num_MCMC-n);%[]

J_trace = zeros(T, control.num_MCMC-n);%[]
ZY_trace = zeros(T, control.num_MCMC-n);%[]
ZV_trace = zeros(T, control.num_MCMC-n);%[]
V0_trace = zeros(1, control.num_MCMC-n);%[]

LL_trace = zeros(1, control.num_MCMC);% We look all LL
%% ======= Prepare Result Storage ========

%% ======= Setting Initial Value ========
% Prior distribution hyperparameter values
% Teng: These prior hyperparameters should not be set within a function.
% Do them make sence?
% Teng: these are hyper parameters values

% mu ~ N(a, A)
a = param.a;
A = param.A;

% alpha, beta ~ N(b, B)
b = param.b;
B = param.B;

% sigma_v^2 ~ InverseGamma(c, C)
c = param.c;
C = param.C;

% mu_v ~ InverseGamma(d, D)
d = param.d;
D = param.D;

% mu_y ~ N(e, E)
e = param.e;
E = param.E;

% sigma_y^2 ~ InverseGamma(f, F)
f = param.f;
F = param.F;

% rho_j ~ N(g, G)
g = param.g;
G = param.G;

% lambda ~ Beta(k, K)
k = param.k;
K = param.K;

p = param.p;
P = param.P;

tmp = [];

% Initial values
V0 = mySelf.V0; V0sum = 0; V02sum = 0;
mu = mySelf.mu; msum = 0; m2sum = 0;                 %% m=mu
kappa = 0; kappasum = 0; kappa2sum = 0;     %% kappa=-alpha/beta, the theta in equation 1
alpha = mySelf.alpha; alphasum = 0; alpha2sum = 0;   %%alpha in equation 3 %----
beta = mySelf.beta; betasum = 0; beta2sum = 0;     %% beta in eq.3 %----
sig2V = mySelf.sig2V; s2Vsum = 0; s2V2sum = 0;  %% sigma_v in eq.3 %----C/(c-2)
rho = mySelf.rho; rhosum = 0; rho2sum = 0;           %% the relation between w1 ad w2 %----
mV = mySelf.mu_v; mVsum = 0; mV2sum = 0;        %% mu_v, the param in expoential distr. of ZV
%%(jump size in variance
mu_y = mySelf.mu_y; mJsum = 0; mJ2sum = 0;              %%mu_y, the mean of jump size in price ZY
sig2Y = mySelf.sig2Y; s2Jsum = 0; s2J2sum = 0;   %% sigma_Y, the variance of jump size in price ZY
rhoJ = mySelf.rhoJ; rhoJsum = 0; rhoJ2sum = 0;        %% rho para in the jump size of price
lambda = mySelf.lambda; lambdasum = 0; lambda2sum = 0;  %% jump intensity

ZY = zeros(1, T);   % row vector
ZV = zeros(1, T);    % row vector
J = mySelf.J';%zeros(1, T);   % row vector
Z = ones(1, T);
V = ones(1, T) * param.V0;

Vsum = 0;Vsum2 = 0;
Jsum = zeros(1, T);
ZVsum = 0;
ZYsum = 0;
stdevrho = mySelf.stdevrho;%0.03; %0.01;%----
dfrho = 8; %6.5;
stdevV = mySelf.stdevV;%0.25;%----
dfV = 6.5;
acceptsumV0 = zeros(size(V0));
acceptsumV = zeros(size(V));
acceptsumrho = 0;
acceptsums2V = 0;
stdevSigV=mySelf.stdevSig2V;

%% ======= Setting Initial Value ========

%% ======= Run MCMC =======
% % Generate latent variables
% V = gen_SVCJ_V(control, param);

% finally, run_mcmc...

percent = control.num_MCMC * 0.1;

fprintf('Start MCMC iteration:\n');
for i = 1: control.num_MCMC
    if mod(i, round(percent)) == 0
            fprintf('Progress:%d%%......(%d/%d)\n',round(i*100/control.num_MCMC), i, control.num_MCMC);
    end

    % (1.10)
    if control.update_V0 == true
        
        % V0
        % Set sigma_V0
        tau = (mySelf.stdevV0)^2; % "tuning" parameters
        
        % Prior distribution (10)
        log_p_V0 = @(V0) log(gampdf(V0, p, P));
        
        % log_p_V0 = calc_log_prior_V0(V0, p, P);
        
        % Target distribution
        log_p_V1_given_V0 = @(V0) -0.5 * log(2 * pi * sig2V * V0) - ((V(1) - ((alpha + (1 / control.dt + beta) * V0) * control.dt + ZV(1) * J(1)))^2) / (2 * sig2V * V0);
        log_pi_V0 = @(V0) calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V) + log_p_V0(V0) + log_p_V1_given_V0(V0);
        
        % Proposal distribution
        pd_V0 = makedist('Normal', 'mu', V0, 'sigma', sqrt(tau)); % Teng: Set up a distribution
        truncated_pd_V0 = truncate(pd_V0, 0, inf);  % Teng: Truncate at the range [0, inf]
        V0prop = random(truncated_pd_V0);           % Teng: Generate a new sample
        
        Phi_V0 = normcdf(-V0 / sqrt(tau));
        Phi_V0prop = normcdf(-V0prop / sqrt(tau));
        
        % Acceptance
        Acc = min(log_pi_V0(V0prop) - log_pi_V0(V0) + log(1-Phi_V0) - log(1-Phi_V0prop), 0);
        if log(rand) <= Acc
            % fprintf('acceptsumV0 %g, V0 %g, V0prop %g, exp(Acc) %g\n', acceptsumV0, V0, V0prop,exp(Acc));
            V0 = V0prop;
            acceptsumV0 = acceptsumV0 + 1;
        end
        if i > n
            V0sum = V0sum + V0;
            V02sum = V02sum + V0^2;
            V0_trace(i-n) = V0;
        end
        %----V0_trace = [V0_trace, V0];
        
    end
    
    % I. (1) mu
    if control.update_mu == true
        As = ((control.dt^2 ) / (1 - rho^2) * sum(1 ./ ([V0 V(1:end-1)]*control.dt)) + 1 / A)^(-1);
        e_Y_mu = Y - ZY .* J;
        e_V_mu = V - [V0 V(1:end-1)] - alpha * control.dt - beta * [V0 V(1:end-1)] * control.dt - ZV .* J;
        
        sum_term = sum((e_Y_mu - (rho / sig2V^0.5) * e_V_mu) ./ [V0 V(1:end-1)] * control.dt);
        as = As * (control.dt / (1 - rho^2) * sum_term + a / A);
        mu = normrnd(as,sqrt(As));
        
        if i > n
            msum = msum + mu;
            m2sum = m2sum + mu.^2;
            mu_trace(i-n) = mu;
        end
    else
    end
    %----mu_trace = [mu_trace, mu];
    
    % I. (2) (alpha, beta)
    if control.update_alpha == true
        e_Y_gamma = Y - mu * control.dt - ZY .* J;
        Q = ((V - [V0 V(1:end-1)] - ZV .* J - rho * sig2V^0.5 * e_Y_gamma) ./ ([V0 V(1:end-1)] * control.dt).^0.5)';
        W = zeros(T, 2);
        W(:,1)= 1 ./ sqrt([V0 V(1:end-1)] * control.dt);
        W(:,2)= sqrt([V0 V(1:end-1)] * control.dt);
        Bs = (inv(B) + (1 / ((1 - rho^2) * sig2V)) * (W' * W))^(-1);
        bs = Bs * (inv(B) * b + (1 / ((1 - rho^2) * sig2V)) * W' * Q);
        
        temp = mvnrnd(bs,Bs);
        alpha = temp(1);
        beta = temp(2);
        kappa = - alpha/beta;
        if i > n
            alphasum = alphasum + alpha;alpha2sum = alpha2sum + alpha^2;
            betasum = betasum + beta; beta2sum = beta2sum + beta^2;
            kappasum = kappasum + kappa; kappa2sum = kappa2sum + kappa^2;
            alpha_trace(i-n) = alpha;
            beta_trace(i-n) = beta;
        end
    else
    end
    %----alpha_trace = [alpha_trace, alpha];
    %----beta_trace = [beta_trace, beta];
    
    % I. (3) mu_y
    if control.update_mu_y == true
        Es = (T/sig2Y + 1/E)^(-1);
        es = Es * (sum((ZY - rhoJ .* ZV)/sig2Y) + e/E);
        mu_y = normrnd(es,sqrt(Es));
        if i > n
            mJsum = mJsum + mu_y;
            mJ2sum = mJ2sum + mu_y^2;
            mu_y_trace(i-n) = mu_y;
        end
    else
    end
    %----mu_y_trace = [mu_y_trace, mu_y];
    
    % I. (4) s2Y
    if control.update_sigma_y == true
        fs = f + T;
        Fs = F + sum((ZY - mu_y - rhoJ*ZV).^2);
        sig2Y = iwishrnd(Fs,fs);
        if i > n
            s2Jsum = s2Jsum + sig2Y;
            s2J2sum = s2J2sum + sig2Y^2;
            sigma_y_trace(i-n) = sqrt(sig2Y);
        end
    else
    end
    %----sigma_y_trace = [sigma_y_trace, sqrt(sig2Y)];
    
    % I. (5) rhoJ
    if control.update_rho_j == true
        Gs = inv(sum(ZV.^2)/sig2Y + 1/G);
        gs = Gs * (sum((ZY - mu_y).*ZV)/sig2Y + g/G);
        rhoJ = normrnd(gs,Gs^0.5);
        if i > n
            rhoJsum = rhoJsum + rhoJ;
            rhoJ2sum = rhoJ2sum + rhoJ^2;
            rho_j_trace(i-n) = rhoJ;
        end
    else
    end
    %----rho_j_trace = [rho_j_trace, rhoJ];
    
    % I. (6) mV
    if control.update_mu_v == true;
        ds = d + 2 * T;
        Ds = D + 2 * sum(ZV);
        mV = iwishrnd(Ds,ds);
        if i > n
            mVsum = mVsum + mV;
            mV2sum = mV2sum + mV^2;
            mu_v_trace(i-n) = mV;
        end
    else
    end
    %----mu_v_trace = [mu_v_trace, mV];
    
    % I. (7) lambda
    if control.update_lambda == true
        ks = k + sum(J);
        Ks = K + T - sum(J);
        lambda = betarnd(ks,Ks);
        if i > n
            lambdasum = lambdasum + lambda;
            lambda2sum = lambda2sum + lambda^2;
            lambda_trace(i-n) = lambda;
        end
    else
    end
    %----lambda_trace = [lambda_trace, lambda];
    
    % I. (8) rho
    if control.update_rho == true
        % Prior distribution
        log_p_rho = @(rho) (rho >= -1 & rho <= 1) .* log(1 / 2); % + (rho < -1 | rho > 1) * (-Inf);
        
        % Target distribution
        % log_pi_rho = @(rho) log(1 / sqrt( 1 - rho^2 ).^ T * exp( sum( - 1 / (2 * (1 - rho^2)) *...
        %     ( Y - mu * control.dt - ZY .* J - rho / sig2V^0.5 * ( V - [V0 V(1:end-1)] - alpha * control.dt - beta * [V0 V(1:end-1)] * control.dt - ZY .* J)).^2./...
        %     [V0 V(1:end-1)] * control.dt))) + log_p_rho(rho);
        log_pi_rho = @(rho) calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V) + log_p_rho(rho);
        
        % Proposal distribution
        % Create the location-scale t-distribution
        pd_rho = makedist('tLocationScale', 'mu', rho, 'sigma', stdevrho, 'nu', dfrho);
        truncated_pd_rho = truncate(pd_rho, -1, 1);
        rhoprop = random(truncated_pd_rho);
        
        pd_rhoprop = makedist('tLocationScale', 'mu', rhoprop, 'sigma', stdevrho, 'nu', dfrho);
        
        % Acceptance
        if abs(rhoprop) < 1
            Acc = min(log_pi_rho(rhoprop) - log_pi_rho(rho) + log(cdf(pd_rho, 1) - cdf(pd_rho, -1)) - log(cdf(pd_rhoprop, 1) - cdf(pd_rhoprop, -1)), 0);
            if log(rand) <= Acc
                
                rho = rhoprop;
                acceptsumrho = acceptsumrho +1;
            end
        end
        if i > n
            rhosum = rhosum + rho;
            rho2sum = rho2sum + rho^2;
            rho_trace(i-n) = rho;
        end
    else
    end
    
    %----rho_trace = [rho_trace, rho];
    
    % I. (9) sig2V
    if control.update_sigma_v == true
        
        % --- 參數與初始設定 ---
        % 假設已定義: sig2V (當前值), Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, rho, c, C...
        proposal_sd_sig2V=stdevSigV;%mySelf.stdevSig2V; %步長，建議初值設為 0.005，觀察接受率後調整
        
        % 1. 定義先驗概率函數 (Log-Prior of Inverse-Gamma)
        % log(p(x)) \propto -(c+1)log(x) - C/x
        calc_log_prior = @(s2v) -(c + 1) * log(s2v) - (C ./ s2v);
        
        % 2. 定義全模型似然函數 (Log-Likelihood)
        % 確保你的 calc_log_likelihood 函數回傳的是 sum(log(pdf))
        log_L_old = calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V);
        log_P_old = calc_log_prior(sig2V);

        % 2. 使用截斷常態分佈生成建議值
        % 設定下限為 0 (或一個極小的正數 eps 以維持數值穩定)
        lb = 0; 
        pd_old = makedist('Normal', 'mu', sig2V, 'sigma', proposal_sd_sig2V);
        t_old = truncate(pd_old, lb, inf); 
        sig2V_prop = random(t_old);
        
        % 3. 執行 MH 判別
        % 計算新值的 Log-Posterior
        log_L_prop = calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V_prop);
        log_P_prop = calc_log_prior(sig2V_prop);
        
        % 4. 計算 Hastings Correction (因為截斷導致建議分佈不對稱)
        % q(old | prop) / q(prop | old)
        % 在 Log 空間則是: log(pdf(t_prop, old)) - log(pdf(t_old, prop))
        pd_prop = makedist('Normal', 'mu', sig2V_prop, 'sigma', proposal_sd_sig2V);
        t_prop = truncate(pd_prop, lb, inf);
        
        log_q_forward = log(pdf(t_old, sig2V_prop)); % 從舊跳到新的機率密度
        log_q_backward = log(pdf(t_prop, sig2V));    % 從新跳回舊的機率密度
        
        % 5. 完整的 MH 接受率計算
        % Log_Acc = (Log_Target_Prop - Log_Target_Old) + (Log_Q_Backward - Log_Q_Forward)
        log_acc_ratio = (log_L_prop + log_P_prop) - (log_L_old + log_P_old) + (log_q_backward - log_q_forward);
        
        if log(rand()) <= log_acc_ratio
            sig2V = sig2V_prop;
            acceptsums2V = acceptsums2V + 1;
        end
        %{
        % 3. 生成建議值 (Proposal) - 隨機走動
        sig2V_prop = sig2V + proposal_sd_sig2V * randn();
        
        % 4. 執行 MH 判別
        if sig2V_prop > 0 % 變異數必須為正
            % 計算新值的 Log-Posterior
            log_L_prop = calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V_prop);
            log_P_prop = calc_log_prior(sig2V_prop);
            
            % 計算接受機率的 Log 值 (對稱建議分布，q 抵消)
            % Acc = log( (Likelihood_new * Prior_new) / (Likelihood_old * Prior_old) )
            log_acc_ratio = (log_L_prop + log_P_prop) - (log_L_old + log_P_old);
            
            % 接受或拒絕
            if log(rand()) <= log_acc_ratio
                sig2V = sig2V_prop;
                acceptsums2V = acceptsums2V + 1; % 用於監控接受率
            end
        end
        
        % 5. 監控接受率 (建議維持在 20% - 40%)
        % if mod(iter, 100) == 0
        %    current_acc_rate = accept_count / iter;
        %    % 如果太高，增加 proposal_sd_sig2V；如果太低，減少之
        % end
        %}
        %----
        %{
        % Target distribution
        log_p_sig2V = @(sig2V) log(inverse_gamma('pdf', sig2V, c, C));
        % log_pi_sig2V = @(sig2V) log((sig2V).^(T / 2) .* exp(-0.5 * sum(((V - [V0 V(1:end-1)] - alpha * control.dt - beta * [V0 V(1:end-1)] * control.dt - ZV .* J - rho * sig2V * (Y - mu - ZY .* J)).^2) ./ ((1 - rho^2) * sig2V .* [V0 V(1:end-1)] * control.dt))) .* (sig2V).^(c + 2 / 2) .* exp(-0.5 * C ./ sig2V));
        log_pi_sig2V = @(sig2V) calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V) + log_p_sig2V(sig2V);
        % Proposal distribution
        cs = c + T / 2;
        Cs = C + 0.5 * (sum(((V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt - ZV .* J).^2)./[V0 V(1:end-1)] * control.dt));
        sig2Vprop = iwishrnd(Cs,cs);
        log_q_sig2V = @(sig2V) log(inverse_gamma('pdf', sig2V, cs, Cs));

        Acc = min(log_pi_sig2V(sig2Vprop) - log_pi_sig2V(sig2V) + log_q_sig2V(sig2V) - log_q_sig2V(sig2Vprop), 0);

        % Acc = min((f_proposed * q_current) / (f_current * q_proposed), 1);
        if log(rand) <= Acc
            sig2V = sig2Vprop;
            acceptsums2V = acceptsums2V + 1;
        end
        %}
        %----
        % cs = c + T / 2;
        % Cs = C + 0.5 * (sum(((V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt - ZV .* J).^2)./[V0 V(1:end-1)] * control.dt));
        % s2Vprop = iwishrnd(Cs,cs);
        % q = exp(-0.5*sum((V - [V0 V(1:end-1)]*(1+beta) - alpha - J.*ZV).^2./(s2Vprop*[V0 V(1:end-1)])-...
        %     (V - [V0 V(1:end-1)]*(1+beta) - alpha - J.*ZV).^2./(sig2V*[V0 V(1:end-1)])));
        % p = exp(-0.5*sum((V - [V0 V(1:end-1)]*(1+beta) - alpha - J.*ZV - rho*s2Vprop^0.5*(Y-Z*mu-J.*ZY)).^2./...
        %     ((1-rho^2)*s2Vprop*[V0 V(1:end-1)])-...
        %     (V - [V0 V(1:end-1)]*(1+beta) - alpha - J.*ZV -rho*sig2V^0.5*(Y-Z*mu-J.*ZY)).^2./...
        %     ((1-rho^2)*sig2V*[V0 V(1:end-1)])));
        % x = min(p/q,1);
        % u = rand(1);
        % if x > u
        %     sig2V = s2Vprop;
        %     if i > n; acceptsums2V = acceptsums2V + 1;end;
        % end
        
        if i > n
            s2Vsum = s2Vsum + sig2V;
            s2V2sum = s2V2sum + sig2V^2;
            sigma_v_trace(i-n) = sqrt(sig2V);
        end
        %sigma_v_trace(i) = sqrt(sig2V);
    else
    end
    %----sigma_v_trace = [sigma_v_trace, sqrt(sig2V)];
    
    % II. J
    if control.update_J == true
        %{
        % f(J_t=1|-)
        f_J1 = lambda*exp( -0.5 * (((Y - mu * control.dt - ZY - (rho/sqrt(sig2V))*(V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt - ZV)).^2)./((1-rho^2)*[V0 V(1:end-1)] * control.dt) + (( V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt - ZV).^2)./(sig2V*[V0 V(1:end-1)] * control.dt)));
        log_f_J1=log(lambda)-0.5 * (((Y - mu * control.dt - ZY - (rho/sqrt(sig2V))*(V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt - ZV)).^2)./((1-rho^2)*[V0 V(1:end-1)] * control.dt) + (( V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt - ZV).^2)./(sig2V*[V0 V(1:end-1)] * control.dt));
        %f_J1=exp(log_f_J1)
        % f(J_t=0|-)
        f_J0 = (1 - lambda) * exp( -0.5 * ( ((Y - mu * control.dt - (rho/sqrt(sig2V))*(V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt)).^2)./((1-rho^2)*[V0 V(1:end-1)] * control.dt) + ((V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt).^2)./(sig2V*[V0 V(1:end-1)] * control.dt)));
        log_f_J0= log(1-lambda) -0.5 * ( ((Y - mu * control.dt - (rho/sqrt(sig2V))*(V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt)).^2)./((1-rho^2)*[V0 V(1:end-1)] * control.dt) + ((V - [V0 V(1:end-1)] - alpha * control.dt - beta*[V0 V(1:end-1)] * control.dt).^2)./(sig2V*[V0 V(1:end-1)] * control.dt));
        %f_J0=exp(log_f_J0)
        % Probability of J_t=1
        log_p=log_f_J0-log_f_J1;
        %log_p = max(min(log_f_J0 - log_f_J1, 500), -500);
        p_J1_real = ones(T, 1)*mean(1./(1+exp(log_p)));%
        %p_J1_real=f_J1 / (f_J1 + f_J0);
        
        
        
        
        %tmp=[tmp;[f_J1 f_J0 p_J1]];
        u = rand(T,1);
        J = double(u < p_J1_real)'; % Turn to boolean
        %}

        dt=control.dt;
        prevV=[V0 V(1:end-1)];
        % 計算 Log-Likelihood
        % 增加常數項：-0.5 * log(2 * pi * var)
        log_const_J1 = -0.5 * log(2 * pi * (1-rho^2) .* [V0 V(1:end-1)] * control.dt) ...
                       -0.5 * log(2 * pi * sig2V .* [V0 V(1:end-1)] * control.dt);
        
        % 計算 f_J1 的指數部分 (原本括號內的內容)
        SSE_J1 = (((Y - mu*dt - ZY - (rho/sqrt(sig2V))*(V - prevV - alpha*dt - beta*prevV*dt - ZV)).^2) ./ ((1-rho^2)*prevV*dt) ...
                  + ((V - prevV - alpha*dt - beta*prevV*dt - ZV).^2) ./ (sig2V*prevV*dt));
        %----
        % 2. 關鍵修正：加上 ZV 和 ZY 的概率代價 (Log-PDF)
        % ZV 的指數分佈代價
        log_pdf_ZV = -log(mV) - (ZV ./ mV); 
        
        % ZY 的常態分佈代價
        log_pdf_ZY = -0.5 * log(2 * pi * sig2Y) - ((ZY - mu_y - rhoJ .* ZV).^2 ./ (2 * sig2Y));
        %----
        log_f_J1 = log(lambda) + log_const_J1 - 0.5 * SSE_J1 + log_pdf_ZV + log_pdf_ZY;
        
        % 同理計算 log_f_J0
        SSE_J0 = (((Y - mu*dt - (rho/sqrt(sig2V))*(V - prevV - alpha*dt - beta*prevV*dt)).^2) ./ ((1-rho^2)*prevV*dt) ...
                  + ((V - prevV - alpha*dt - beta*prevV*dt).^2) ./ (sig2V*prevV*dt));
        
        log_f_J0 = log(1 - lambda) + log_const_J1 - 0.5 * SSE_J0;
        
        % 使用 Log-ratio 計算機率，避免 Inf/NaN
        log_ratio = log_f_J1 - log_f_J0;%----
        p_J1 = 1 ./ (1 + exp(-log_ratio)); 
        
        % 確保 p_J1 不會因為數值問題變成 NaN
        p_J1(isnan(p_J1)) = 0;
        %tmp=[tmp;[f_J1 f_J0 p_J1]];
        u = rand(T,1);
        J = double(u < p_J1')'; % Turn to boolean
        %}
        if i > n 
            Jsum = Jsum + J;
            J_trace(:, i-n) = J;
        end
    else
    end
    
    Jindex = find(J == 1);
    %----J_trace = [J_trace; J];
    
    % III. (1) ZV
    if control.update_Z_t_V == true
        %{
        % ZV(logical(~J)) = exprnd(mV, T - sum(J), 1);
        if ~isempty(Jindex) % If Jindex is not empty
            
            if Jindex(1) == 1 % If a jump occur
                t = 1;
                eV = V(1) - param.V0 - alpha * control.dt - beta * param.V0 * control.dt;
                eY = Y(1) - mu * control.dt - ZY(1);
                L = 1 ./ ( 1 ./((1 - rho^2)*sig2V*param.V0) + rhoJ^2/sig2Y );
                l = L .* ((eV-rho*sqrt(sig2V)*eY)/((1 - rho^2)*sig2V*param.V0) + rhoJ*(ZY(1) - mu_y)/sig2Y - 1/mV);
                if l+5*sqrt(L) > 0; ZV(1) = normt_rnd(l,L,0,l+5*sqrt(L)); else ZV(1) = 0; end;
                if ZV(1) == Inf | ZV(1) == NaN; ZV(1) = 0; end;
            else
                t = Jindex(1);
                eV = V(t) - V(t-1) - alpha * control.dt - beta * V(t-1) * control.dt;
                eY = Y(t) - mu * control.dt - ZY(t);
                L = 1 ./ ( 1 ./((1 - rho^2)*sig2V*V(t-1)) + rhoJ^2/sig2Y );
                l = L .* ((eV-rho*sqrt(sig2V)*eY)/((1 - rho^2)*sig2V*V(t-1)) + rhoJ*(ZY(t) - mu_y)/sig2Y - 1/mV);
                if l+5*sqrt(L) > 0; ZV(t) = normt_rnd(l,L,0,l+5*sqrt(L)); else ZV(t) = 0; end;
                if ZV(t) == Inf | ZV(t) == NaN; ZV(t) = 0; end;
            end
            if length(Jindex) > 1
                for t = Jindex(2:end)'
                    eV = V(t) - V(t-1) - alpha * control.dt - beta * V(t-1) * control.dt;
                    eY = Y(t) - mu * control.dt - ZY(t);
                    L = 1 ./ (1 ./ ((1 - rho^2)*sig2V*V(t-1)) + rhoJ^2 / sig2Y);
                    l = L .* ((eV-rho*sqrt(sig2V)*eY)/((1 - rho^2)*sig2V*V(t-1)) + rhoJ*(ZY(t) - mu_y)/sig2Y - 1/mV);
                    if l+5*sqrt(L) > 0; ZV(t) = normt_rnd(l,L,0,l+5*sqrt(L)); else ZV(t) = 0; end;
                    if ZV(t) == Inf | ZV(t) == NaN; ZV(t) = 0; end;
                end
            end
        %}
        %----
        if ~isempty(Jindex)
            for t_idx = 1:length(Jindex)
                t = Jindex(t_idx);
                V_prev = max((t==1)*param.V0 + (t>1)*V(max(1,t-1)), 1e-6);
                
                % --- 步驟 A: 準備不含跳躍項的原始殘差 (關鍵！) ---
                % 注意：這裡的 eY 不應該扣除 ZY，因為 ZY 是我們要聯動抽樣的目標
                eps_V = V(t) - V_prev - (alpha + beta * V_prev) * control.dt;
                eps_Y = Y(t) - (mu * control.dt);
                
                % --- 步驟 B: 計算 ZV 的條件方差 L ---
                % 公式：1 / [ 1/((1-rho^2)*sig2V*V_prev) + rhoJ^2/sig2Y ]
                L = 1 / ( 1 / ((1 - rho^2) * sig2V * V_prev * control.dt) + (rhoJ^2 / sig2Y) );
                
                % --- 步驟 C: 計算 ZV 的條件均值 l ---
                % 修正點：相關性補償項 rho*sqrt(sig2V/V_prev)*eps_Y
                vol_info = (eps_V - rho * sqrt(sig2V / V_prev) * eps_Y) / ((1 - rho^2) * sig2V * V_prev * control.dt);
                jump_info = rhoJ * (ZY(t) - mu_y) / sig2Y; % 如果 ZY 尚未更新，這裡用舊值或先設為 0
                
                l = L * (vol_info + jump_info - 1/mV);
                
                % --- 步驟 D: 截斷正態抽樣 (Truncated Normal) ---
                % 修正點：下界固定為 0，上界給予足夠空間
                ZV(t) = normt_rnd(l, L, 0, l + 10*sqrt(L)); 
                
                % 防止 NaN/Inf
                if isnan(ZV(t)) || isinf(ZV(t)); ZV(t) = 0; end
            end
        
        
        %}
            
        end
        if i > n; ZVsum = ZVsum + ZV; end;
    else
    end
    %----ZV_trace = [ZV_trace; ZV];
    
    % III. (2) ZY
    if control.update_Z_t_Y == true
        %{
        % ZY(logical(~J)) = normrnd(mu_y + rhoJ*ZV(logical(~J)),sig2Y^0.5)';
        if ~isempty(Jindex)
            if Jindex(1) == 1
                t = 1;
                H = inv(1/((1 - rho^2)*param.V0) + 1/sig2Y);
                h = H * ( (V(1) - param.V0 - ZV(1) - alpha * control.dt - beta * param.V0 * control.dt - (rho/sqrt(sig2V))*(Y(1) - mu * control.dt))/((1 - rho^2)*param.V0*control.dt) + (mu_y + rhoJ*ZV(1))/sig2Y );
                ZY(1) = normrnd(h,sqrt(H));
            else
                t = Jindex(1);
                H = 1 ./ (1./((1 - rho^2) * V(t-1)) + 1/sig2Y);
                h = H .* ((V(t) - V(t-1) - ZV(t) - alpha * control.dt - beta * V(t-1) * control.dt - (rho/sqrt(sig2V))*(Y(t) - mu * control.dt))/((1 - rho^2)*V(t-1)*control.dt) + (mu_y + rhoJ*ZV(t))/sig2Y );
                ZY(t) = normrnd(h,sqrt(H));
            end
            if length(Jindex) > 1
                for t = Jindex(2:end)'
                    H = 1 ./ (1./((1 - rho^2)*V(t-1)) + 1/sig2Y);
                    h = H .* ((V(t) - V(t-1) - ZV(t) - alpha * control.dt - beta * V(t-1) * control.dt - (rho/sqrt(sig2V))*(Y(t) - mu * control.dt))/((1 - rho^2)*V(t-1)*control.dt) + (mu_y + rhoJ*ZV(t))/sig2Y );
                    ZY(t) = normrnd(h,sqrt(H));
                end
            end
        end
        %}
        %----
        
        if ~isempty(Jindex)
            % 1. 預處理所需的參數與變數
            t = Jindex;
            dt = control.dt;
            
            % 判斷是否包含第一個時間點，處理 V(t-1) 的問題
            V_prev = zeros(size(t));
            isFirst = (t == 1);
            V_prev(isFirst) = param.V0;
            V_prev(~isFirst) = V(t(~isFirst) - 1);
            
            % 2. 計算條件變異數 H (Posterior Variance)
            % 注意：這裡考慮了 dt 造成的變異數縮放
            term1_prec = 1 ./ ((1 - rho^2) * V_prev * dt);
            term2_prec = 1 / sig2Y;
            H = 1 ./ (term1_prec + term2_prec);
            
            % 3. 計算條件均值 h (Posterior Mean)
            % 修正：第一項的分母應與 Precision 一致
            part1 = (V(t) - V_prev - ZV(t) - (alpha + beta * V_prev) * dt - ...
                    (rho / sqrt(sig2V)) * (Y(t) - mu * dt)) ./ ((1 - rho^2) * V_prev * dt);
            part2 = (mu_y + rhoJ * ZV(t)) / sig2Y;
            
            h = H .* (part1 + part2);
            
            % 4. 抽樣 ZY (Matlab normrnd 使用標準差)
            ZY(t) = normrnd(h, sqrt(H));
        end
        
    end
    if i > n 
        ZYsum = ZYsum + ZY;
        ZY_trace(:, i-n) = ZY;
    end
    %----ZY_trace = [ZY_trace; ZY];
    
    % IV. Draw V

    % if control.update_V == true
    %     % Set tau (tuning parameter for proposal distribution)
    %     tau_V = (0.00003)^2;
    % 
    %     % Prior distribution (10)
    %     log_p_V = @(V) 1 ./ sqrt(2 * pi * sig2V .* [V0 V(1:end-1)]) .* exp(-((V - (alpha + (1 ./ control.dt + beta) .* [V0 V(1:end-1)]) .* control.dt) .^ 2) ./ (2 * sig2V .* [V0 V(1:end-1)]));
    % 
    %     % Target distribution
    %     log_pi_V = @(V) calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V) + log_p_V(V);
    % 
    %     % Proposal distribution
    %     pd_V = makedist('Normal', 'mu', 0, 'sigma', sqrt(tau_V)); % Set up a distribution for epsilon_t
    %     truncated_pd_V = truncate(pd_V, -min(V, [], 'all'), inf); % Truncate at the range [0, inf]
    %     epsilon_t = random(truncated_pd_V, 1, T); % Generate the proposal perturbation (epsilon_t)
    %     Vprop = V + epsilon_t; % Update V with the proposal
    % 
    %     Phi_V = normcdf(-V ./ sqrt(tau_V));
    %     Phi_Vprop = normcdf(-Vprop ./ sqrt(tau_V));
    % 
    %     % Acceptance
    %     Acc = min(log_pi_V(Vprop) - log_pi_V(V) + log(1-Phi_V) - log(1-Phi_Vprop), 0);
    %     if log(rand) <= Acc
    %         % fprintf('acceptsumV %g, V %g, Vprop %g, exp(Acc) %g\n', acceptsumV, V, Vprop,exp(Acc));
    %         % pause(2);
    %         V = Vprop;
    %         acceptsumV = acceptsumV +1;
    %     end
    % 
    %     if i > n
    %         Vsum = Vsum + V;
    %         Vsum2 = Vsum2 + V.^2;
    %     end
    % end

    if control.update_V == true
        epsilon = trnd(dfV,T,1);
        [mv, v] = tstat(dfV);
        epsilon = (stdevV/sqrt(v)) * epsilon;
        if i == floor(n / 2)
            Vindex1 = find(Vsum2 > prctile(Vsum2, 92.5));
            Vindex2 = find(Vsum2 > prctile(Vsum2, 75) & ...
                Vsum2 < prctile(Vsum2, 92.5));
            Vindex3 = find(Vsum2 < prctile(Vsum2, 25) & ...
                Vsum2 > prctile(Vsum2, 2.5));
            Vindex4 = find(Vsum2 < prctile(Vsum2, 2.5));
        end
        if i > floor(n / 2) - 1
            epsilon(Vindex1) = 1.35 * epsilon(Vindex1);
            epsilon(Vindex2) = 1.25 * epsilon(Vindex2);
            epsilon(Vindex3) = 0.75 * epsilon(Vindex3);
            epsilon(Vindex4) = 0.65 * epsilon(Vindex4);
        end
        
        j = 1;
        Vprop = V + epsilon;
        
        p1 = max(0,exp( -0.5 * (( Y(j+1) - mu(1) * control.dt - J(j+1)*ZY(j+1) - rho / sig2V^0.5 *(V(j+1) - Vprop(j) - alpha * control.dt - Vprop(j) * beta * control.dt - J(j+1)*ZV(j+1) ) )^2/( (1 - rho^2) * Vprop(j) ) +...
            ( Y(j) - mu(1) * control.dt - J(j)*ZY(j) - rho / sig2V^0.5 *(Vprop(j) - V0 - alpha * control.dt - V0 * beta * control.dt - J(j)*ZV(j)))^2/( (1 - rho^2) * V0 ) +...
            ( V(j+1) - Vprop(j) - alpha * control.dt - Vprop(j) * beta * control.dt - J(j+1)*ZV(j+1) )^2/( sig2V * Vprop(j) ) +...
            ( Vprop(j) - V0 - alpha * control.dt - V0 * beta * control.dt - J(j)*ZV(j))^2/( sig2V * V0))) / Vprop(j));
        p2 = max(0,exp( -0.5 * (( Y(j+1) - mu(1) * control.dt - J(j+1)*ZY(j+1) - rho / sig2V^0.5 *(V(j+1) - V(j) - alpha * control.dt - V(j) * beta * control.dt - J(j+1)*ZV(j+1) ) )^2/( (1 - rho^2) * V(j) ) +...
            ( Y(j) - mu(1) * control.dt - J(j)*ZY(j) -rho / sig2V^0.5 *(V(j) - V0 - alpha * control.dt - V0 * beta * control.dt - J(j)*ZV(j)) )^2/( (1 - rho^2) * V0 ) +...
            ( V(j+1) - V(j) - alpha * control.dt - V(j) * beta * control.dt - J(j+1)*ZV(j+1))^2/( sig2V * V(j) ) +...
            ( V(j) - V0 - alpha * control.dt - V0 * beta * control.dt - J(j)*ZV(j))^2/( sig2V * V0))) / V(j));
        if p2 ~= 0; acceptV = min(p1/p2, 1); elseif p1 > 0; acceptV = 1; else; acceptV = 0; end;
        u = rand(T,1);
        if u(j) < acceptV
            V(j) = Vprop(j);
            if i > n; acceptsumV(j) = acceptsumV(j) + 1; end;
        end

        for j = 2:T-1
            p1 = max(0,exp( -0.5 * (( Y(j+1) - mu(1) * control.dt - J(j+1)*ZY(j+1) - rho / sig2V^0.5 *(V(j+1) - Vprop(j) - alpha * control.dt - Vprop(j) * beta * control.dt - J(j+1)*ZV(j+1)) )^2/( (1 - rho^2) * Vprop(j) ) +...
                ( Y(j) - mu(1) * control.dt - J(j)*ZY(j) - rho / sig2V^0.5 *(Vprop(j) - V(j-1) - alpha * control.dt - V(j-1) * beta * control.dt - J(j)*ZV(j) ) )^2/( (1 - rho^2) * V(j-1) ) +...
                ( V(j+1) - Vprop(j) - alpha * control.dt - Vprop(j) * beta * control.dt - J(j+1)*ZV(j+1))^2/( sig2V * Vprop(j) ) +...
                ( Vprop(j) - V(j-1) - alpha * control.dt - V(j-1) * beta * control.dt - J(j)*ZV(j))^2/( sig2V * V(j-1)))) / Vprop(j));
            p2 = max(0,exp( -0.5 * (( Y(j+1) - mu(1) * control.dt - J(j+1)*ZY(j+1) - rho / sig2V^0.5 *(V(j+1) - V(j) - alpha * control.dt - V(j) * beta * control.dt - J(j+1)*ZV(j+1)) )^2/( (1 - rho^2) * V(j) ) +...
                ( Y(j) - mu(1) * control.dt - J(j)*ZY(j) - rho / sig2V^0.5 *(V(j) - V(j-1) - alpha * control.dt - J(j)*ZV(j) - V(j-1) * beta * control.dt) )^2/( (1 - rho^2) * V(j-1) ) +...
                ( V(j+1) - V(j) - alpha * control.dt - V(j) * beta * control.dt - J(j+1)*ZV(j+1))^2/( sig2V * V(j) ) +...
                ( V(j) - V(j-1) - alpha * control.dt - V(j-1) * beta * control.dt - J(j)*ZV(j))^2/( sig2V * V(j-1)))) / V(j));
            if p2 ~= 0; acceptV = min(p1/p2, 1); elseif p1 > 0; acceptV = 1; else; acceptV = 0; end;

            if u(j) < acceptV
                V(j) = Vprop(j);
                if i > n; acceptsumV(j) = acceptsumV(j) + 1; end;
            end
        end
        j = T;
        p1 = max(0,exp( -0.5 * (( Y(j) - mu(1) * control.dt - J(j)*ZY(j) - rho / sig2V^0.5 *(Vprop(j) - V(j-1) - alpha * control.dt - V(j-1) * beta * control.dt - J(j)*ZV(j)) )^2/( (1 - rho^2) * V(j-1) ) +...
            ( Vprop(j) - V(j-1) - alpha * control.dt - V(j-1) * beta * control.dt - J(j)*ZV(j))^2/( sig2V * V(j-1)))) / Vprop(j)^0.5);
        p2 = max(0,exp( -0.5 * (( Y(j) - mu(1) * control.dt - J(j)*ZY(j) - rho / sig2V^0.5 *(V(j) - V(j-1) - alpha * control.dt - V(j-1) * beta * control.dt - J(j)*ZV(j)) )^2/( (1 - rho^2) * V(j-1) ) +...
            ( V(j) - V(j-1) - alpha * control.dt - V(j-1) * beta * control.dt - J(j)*ZV(j))^2/( sig2V * V(j-1)))) / V(j)^0.5);
        if p2 ~= 0; acceptV = min(p1/p2, 1); elseif p1 > 0; acceptV = 1; else; acceptV = 0; end;

        if u(j) < acceptV
            V(j) = Vprop(j);
            if i > n; acceptsumV(j) = acceptsumV(j) + 1; end
        end

        if i > n; Vsum = Vsum + V; end
        if i > floor(n / 2) - 100 || i < floor(n / 2); Vsum2 = Vsum2 + V; end
        test(i,:) = [mu mu_y sig2Y lambda alpha beta  rho sig2V rhoJ mV];%----
    else
        
    
        
    end

    % Compute log likelihood
    LL = calc_log_likelihood(Y, V, V0, ZY, ZV, J, control, mu, alpha, beta, mu_y, sig2Y, rhoJ, mV, lambda, rho, sig2V);

    % Compute log-priors
    if control.update_V0 == true
        log_prior_V0 = log(gampdf(V0, p, P));
    else
        log_prior_V0 = 0;
    end

    if control.update_mu == true
        log_prior_mu = log(normpdf(mu, a, sqrt(A)));
    else
        log_prior_mu = 0;
    end

    if control.update_alpha == true
        log_prior_alpha = log(mvnpdf([alpha; beta], b, B)); %alpha, beta
    else
        log_prior_alpha = 0;
    end

    if control.update_mu_y == true
        log_prior_mu_y = log(normpdf(mu_y, e, sqrt(E)));
    else
        log_prior_mu_y = 0;
    end

    if control.update_sigma_y == true
        log_prior_sig2Y = log(inverse_gamma('pdf', sig2Y, f, F));
    else
        log_prior_sig2Y = 0;
    end

    if control.update_rho_j == true
        log_prior_rhoJ = log(normpdf(rhoJ, g, sqrt(G)));
    else
        log_prior_rhoJ = 0;
    end

    if control.update_mu_v == true
        log_prior_mV = log(inverse_gamma('pdf', mV, d, D));
    else
        log_prior_mV = 0;
    end

    if control.update_lambda == true
        log_prior_lambda = log(betapdf(lambda, k, K));
    else
        log_prior_lambda = 0;
    end

    if control.update_rho == true
        log_prior_rho = (rho >= -1 & rho <= 1) .* log(1 / 2);
    else
        log_prior_rho = 0;
    end

    if control.update_sigma_v == true
        log_prior_sig2V = log(inverse_gamma('pdf', sig2V, c, C));
    else
        log_prior_sig2V = 0;
    end
    
    % Sum log-prior terms
    log_prior = log_prior_V0 + log_prior_mu + log_prior_alpha + log_prior_mu_y + log_prior_sig2Y + log_prior_rhoJ + log_prior_mV + log_prior_lambda + log_prior_rho + log_prior_sig2V;

    % Compute log-posterior
    log_posterior = LL + log_prior;

    % Store log-posterior trace
    
    LL_trace(:, i) = log_posterior;
    %----LL_trace = [LL_trace, log_posterior];

end

%% ======= Create outputs strucutre =======
% posterior means
outputs.V0 = V0sum/(control.num_MCMC-n);
outputs.mu = msum/(control.num_MCMC-n);
outputs.mu_y = mJsum/(control.num_MCMC-n);
outputs.sigma_y = sqrt(s2Jsum)/(control.num_MCMC-n);
outputs.lambda = lambdasum/(control.num_MCMC-n);
outputs.alpha = alphasum/(control.num_MCMC-n);
outputs.beta = betasum/(control.num_MCMC-n);
outputs.rho = rhosum/(control.num_MCMC-n);
outputs.sigma_v = sqrt(s2Vsum)/(control.num_MCMC-n);
outputs.rho_j = rhoJsum/(control.num_MCMC-n);
outputs.mu_v = mVsum/(control.num_MCMC-n);
outputs.V = Vsum/(control.num_MCMC-n);
outputs.LL = log_posterior;

% mcmc paths of each parameters
outputs.V0_trace = V0_trace;
outputs.mu_trace = mu_trace;
outputs.alpha_trace = alpha_trace;
outputs.beta_trace = beta_trace;
outputs.sigma_v_trace = sigma_v_trace;
outputs.mu_y_trace = mu_y_trace;
outputs.sigma_y_trace = sigma_y_trace;
outputs.rho_trace = rho_trace;
outputs.rho_j_trace = rho_j_trace;
outputs.mu_v_trace = mu_v_trace;
outputs.lambda_trace = lambda_trace;
outputs.J_trace = J_trace;
outputs.ZY_trace = ZY_trace;
outputs.ZV_trace = ZV_trace;
outputs.LL_trace = LL_trace;
outputs.LL_trace_last=LL_trace(n+1:end);




%{outputs.J=sum(J_trace, 1)/(control.num_MCMC-n);
%outputs.ZY=sum(ZY_trace, 1)/(control.num_MCMC-n);
%outputs.ZV=sum(ZV_trace, 1)/(control.num_MCMC-n);
outputs.J = Jsum/(control.num_MCMC-n);
outputs.ZY = ZYsum/(control.num_MCMC-n);
outputs.ZV = ZVsum/(control.num_MCMC-n);

disp(acceptsumV0/control.num_MCMC)
disp(acceptsumrho/control.num_MCMC)
disp(acceptsums2V/control.num_MCMC)
disp(acceptsumV/control.num_MCMC)

outputs.acceptV0 = acceptsumV0/control.num_MCMC;
outputs.acceptrho = acceptsumrho/control.num_MCMC;
outputs.accepts2V = acceptsums2V/control.num_MCMC;
outputs.acceptV = acceptsumV/(control.num_MCMC-n);
%% ======= Create outputs strucutre =======