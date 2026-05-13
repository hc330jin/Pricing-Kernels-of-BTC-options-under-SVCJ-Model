% filename: define_flag.m
% Created on Wendy Huang
% Reviewed by Huei-Wen Teng on 20241227
% Teng: This function define which parameters needs to be updated!
function control = define_flag(control)

control.update_V0 = true;
control.update_mu = true;
control.update_alpha = true;
control.update_beta = true;
control.update_mu_y = true;
control.update_mu_v = true;
control.update_sigma_y = true;
control.update_rho_j = true;
control.update_lambda = true;
control.update_rho = true;
control.update_sigma_v = true;
control.update_V = true;
control.update_Z_t_V = true;
control.update_Z_t_Y = true;
control.update_J = true;


switch control.model

    case 'BS'

        control.update_alpha = false;
        control.update_beta = false;
        control.update_rho = false;
        control.update_sigma_v = false;
        control.update_mu_y = false;
        control.update_mu_v = false;
        control.update_sigma_y = false;
        control.update_rho_j = false;
        control.update_lambda = false;
        control.update_V = false;
        control.update_Z_t_V = false;
        control.update_Z_t_Y = false;
        control.update_J = false;


    case 'SV'
        control.update_mu_y = false;
        control.update_sigma_y = false;
        control.update_rho_j = false;
        control.update_mu_v = false;
        control.update_lambda = false;
        control.update_Z_t_V = false;
        control.update_Z_t_Y = false;
        control.update_J = false;


    case 'SVJ'

        control.update_Z_t_V = false;

    otherwise
end