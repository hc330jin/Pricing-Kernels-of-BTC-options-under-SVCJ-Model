
function mySelf = my_self(s, i, Y, steps);

file_name = sprintf('%d_steps.csv', i);
T2=readtable(file_name)
mySelf.stdevV=T2{1, "stdevV"}
mySelf.stdevrho=T2{1, "stdevrho"}
mySelf.stdevV0=T2{1, "stdevV0"}
mySelf.stdevSig2V=T2{1, "stdevSig2V"}

%file=sprintf('SVCJ_100000estimate_GSPC_%d/parameters.csv', i)
%T=readtable(file)
mySelf.alpha=0.04%T{end, "alpha"}
mySelf.beta=-0.04%T{end, "beta"}
mySelf.rho=0%T{end, "rho"}
mySelf.sig2V=0.1%T{end, "sigma2_v"}
mySelf.mu=0%T{end, "mu"}
mySelf.V0=std(Y)^2

mySelf.sig2Y=5%T{end, "sigma2_y"}
mySelf.mu_y=0%T{end, "mu_y"}
mySelf.rhoJ=-0.25%T{end, "rho_j"}
mySelf.mu_v=0.43%T{end, "mu_v"}
mySelf.lambda=0.05%T{end, "lambda"}%0.01

file_name = sprintf('jumpDate_%s.csv', s);
T3=readtable(file_name)
mySelf.J=T3{i:i+steps-1, "Jump"}