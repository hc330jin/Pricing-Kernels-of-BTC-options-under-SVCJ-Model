function result = inverse_gamma(action, x, c, C)
% inverse_gamma - Implements the Inverse-Gamma distribution
%
% Usage:
%   p = inverse_gamma('pdf', x, c, C)   % PDF
%   P = inverse_gamma('cdf', x, c, C)   % CDF
%   r = inverse_gamma('rnd', c, C, n)   % Random sampling
%
% Inputs:
%   action: 'pdf', 'cdf', or 'rnd'
%   x: value(s) where PDF or CDF is evaluated (for 'pdf' and 'cdf')
%   c: shape parameter (must be > 0)
%   C: scale parameter (must be > 0)
%   n: number of samples (for 'rnd' only)
%
% Outputs:
%   result: PDF, CDF, or random samples (numeric array).

    switch lower(action)
        case 'pdf'
            % PDF of the inverse-gamma
            if nargin < 4, error('Usage: inverse_gamma(''pdf'', x, c, C)'); end
            if any(x <= 0), error('x must be > 0 for the inverse-gamma PDF.'); end
            result = (C^c / gamma(c)) * x.^(-c-1) .* exp(-C ./ x);

        case 'cdf'
            % CDF of the inverse-gamma (numerical integration of the PDF)
            if nargin < 4, error('Usage: inverse_gamma(''cdf'', x, c, C)'); end
            if any(x <= 0), error('x must be > 0 for the inverse-gamma CDF.'); end
            pdf_fun = @(t) (C^c / gamma(c)) * t.^(-c-1) .* exp(-C ./ t);
            result = arrayfun(@(xi) integral(pdf_fun, 0, xi), x);

        case 'rnd'
            % Random sampling from the inverse-gamma
            if nargin < 4, error('Usage: inverse_gamma(''rnd'', c, C, n)'); end
            c = x; % For 'rnd', c is the second input
            n = C; % For 'rnd', n is the third input
            if c <= 0 || n <= 0, error('Shape c and sample size n must be > 0.'); end
            result = 1 ./ gamrnd(c, 1/C, n, 1);

        otherwise
            error('Invalid action. Use ''pdf'', ''cdf'', or ''rnd''.');
    end
end