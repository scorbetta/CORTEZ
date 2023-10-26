function y = piecewise(x)
    y = zeros(size(x));

    % (-inf,-2]
    ind = x <= -2;
    y(ind) = -1;
    % [-2,atanh(-sqrt(2/3))]
    ind = x >= -2.0 & x <= atanh(-sqrt(2/3));
    y(ind) = 0.2149 * x(ind) - 0.5702;
    % [atanh(-sqrt(2/3)),atanh(-sqrt(1/3))]
    ind = x >= atanh(-sqrt(2/3)) & x <= atanh(-sqrt(1/3));
    y(ind) = 0.4903 * x(ind) - 0.2545;
    % [atanh(sqrt(-1/3)),0]
    ind = x >= atanh(-sqrt(1/3)) & x <= 0;
    y(ind) = 0.8768 * x(ind);

    % [0,atanh(sqrt(1/3))]
    ind = x >= 0 & x <= atanh(sqrt(1/3));
    y(ind) = 0.8768 * x(ind);
    % [atanh(sqrt(1/3)),atanh(sqrt(2/3))]
    ind = x >= atanh(sqrt(1/3)) & x <= atanh(sqrt(2/3));
    y(ind) = 0.4903 * x(ind) + 0.2545;
    % [atanh(sqrt(2/3)),2]
    ind = x >= atanh(sqrt(2/3)) & x <= 2.0;
    y(ind) = 0.2149 * x(ind) + 0.5702;
    % [2,+inf)
    ind = x >= 2;
    y(ind) = 1;
endfunction
