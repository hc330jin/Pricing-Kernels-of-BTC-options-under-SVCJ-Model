% filename : define_param.m
% Created by Wendy Huang
% Reviewed by Huei-Wen teng on 20250910

function param = define_param(model);

 %param.model = control.model;
 %param.T = control.T;
 %param.dt = control.dt;
%
 %control.num_MCMC = 10000; % # MCMC iterations
 %control.model = 'SVCJ';
 %control = define_flag(control);
 %control.num_paths = 1;
control.T = 10;    % Teng 20250910: I don't understand why control.T is needed???
 %control.dt = 1;
 control.SMALL = 1e-10;

%param.T = control.T;

switch model
    
    case {'BS', 'SV', 'SVJ', 'SVCJ'}
        
        DEN = 1; %100;
        
        rng(42);
        param.V0 = 0.0014/DEN;
        param.mu = 0.0009/DEN;
        param.alpha = 0.000594/DEN;
        param.beta = -0.7425/DEN;
        param.mu_y = 0.3166/DEN;
        param.sigma_y = 0.1267/DEN;
        param.sigma2_y = param.sigma_y ^ 2;
        param.rho_j = -1.0821/DEN;
        param.mu_v = 0.0206/DEN;
        param.lambda = 0.0033/DEN;
        param.rho = -0.6245/DEN;
        param.sigma_v = 0.0489/DEN;
        param.sigma2_v = param.sigma_v ^ 2;
        
        % Pre-allocate structures for Z_t_v, Z_t_y, and J for each T
        param.Z_t_V = cell(1, length(control.T));
        param.Z_t_Y = cell(1, length(control.T));
        param.J = cell(1, length(control.T));
        
        % Generate the random variables for each T
        for i = 1:length(control.T)
            T = control.T(i);
            param.Z_t_V{i} = exprnd(param.mu_v, [T, 1]);
            param.Z_t_Y{i} = normrnd(param.mu_y + param.rho_j * param.Z_t_V{i}, param.sigma_y);
            param.J{i} = binornd(1, param.lambda, [T, 1]);
        end
        
        % hyperparameters for mcmc algorithm
        param.a = 0;
        param.A = 25;
        param.b = [0 0]'; %prior for alpha and beta,
        param.B = 1*eye(length(param.b)); %prior for alpha and beta
        param.c = 2.5;   %prior for sigma2_v
        param.C = 0.1; %prior for signma2_v
        param.d = 10;  %prior for mu_v
        param.D = 20; % prior for mu_v
        param.e = 0;
        param.E = 100; %prior for mu_y
        param.f = 5;  %prior for sigma2_y
        param.F = 40;  %prior for sigma2_y
        param.g = 0;
        param.G = 4;
        param.k = 2;  %prior for lambda
        param.K = 30; %prior for lambda
        param.p = 0.02; %prior for V0
        param.P = 0.07; %prior for V0
        
    case 'HISIM'    % Historical simulation
        
        param.rho = 0;
        
        
    case 'GARCH'
        
        param.mu    = 0.01;             % mean (drift), e.g. 1% per period
        param.omega = 0.02;             % > 0, GARCH constant
        param.alpha = 0.10;             % >= 0, ARCH term
        param.beta  = 0.85;             % >= 0, GARCH term; alpha+beta < 1 for stationarity
        param.rho = 0; % correlation between two Weiner processes
        
        
    case 'EGARCH'
        
        % --- Parameters (given) ---
        param.mu    = 0.01;
        param.omega = -0.05;     % EGARCH constant (omega)
        param.alpha = 0.10;      % magnitude effect
        param.beta  = 0.92;      % persistence
        param.gamma = -0.12;     % leverage effect
        param.rho   = 0;         % (not used in EGARCH(1,1); included for completeness; this is used in as the correlation in the two Wiener process)
        
        
    case 'GJR_GARCH'
        
        % --- Parameters (proposed) ---
        param.mu    = 0.01;       % unconditional mean of returns
        param.omega = 5e-6;       % variance constant (omega > 0)
        param.alpha = 0.06;       % reaction to past shocks (ARCH)
        param.beta  = 0.89;       % volatility persistence (GARCH)
        param.gamma = 0.08;       % asymmetry (extra effect when eps_{t-1} < 0)
        param.rho   = 0;         % (not used in GRJ_GARCH(1,1); included for completeness; this is used in as the correlation in the two Wiener process)
        
    otherwise
        
        fprintf('Warning in define_param.m parameters for %s is not defined \n', model);
        param.rho = 0;
        
        
        
end