%% y=tanh(x)
x = [-3:0.01:3];
y = tanh(x);
figure;
subplot(5,1,2:4);
plot(x, y, 'linewidth', 1.5);
axis tight;
grid on;
title('y = tanh(x)');
print -dpng plot_tanh.png;
close;

%% f() and its derivatives, zoomed
x = [0:0.01:3];
y = tanh(x);
yp = 1 - tanh(x) .^ 2;
ypp = -2 .* tanh(x) .^ 2 .* yp;
yppp = 2 .* yp .* (3 .* tanh(x) .^ 2 - 1);
ypppp = -8 .* y .* yp .* (3 .* tanh(x) .^ 2 - 2);
figure;
subplot(2,1,1);
hold all;
grid on;

% d
plot(x, yp, '--', 'linewidth', 1.5);
% d2
plot(x, ypp, '--', 'linewidth', 1.5);
% d3
plot(x, yppp, '--', 'linewidth', 1.5);
% d4
plot(x, ypppp, '--', 'linewidth', 1.5);
% d3=0
px = atanh(sqrt(1/3)); py = 2 * (1 - tanh(px) ^ 2) * (3 * tanh(px) ^ 2 - 1);
plot(px, py, 'ok', 'linewidth', 1.5, 'markersize',6.0);
text(px+0.05, py, 'Z_3', 'color', 'black');
% d4=0
px = atanh(sqrt(2/3)); py = -8 * tanh(px) * (1 - tanh(px) ^ 2) * (3 * tanh(px) ^ 2 - 2);
plot(px, py, 'ok', 'linewidth', 1.5, 'markersize',6.0);
text(px+0.05, py, 'Z_4', 'color', 'black');

%axis tight;
title('y = tanh(x) and its derivatives');
legend('d/dx', 'd^2/dx^2', 'd^3/dx^3', 'd^4/dx^4');

subplot(2,1,2);
x = [-3:0.01:3];
% f(x)
y = tanh(x);
plot(x, y, '--k');
hold all;
grid on;
% piecewise approximateion
ypw = piecewise(x);
plot(x, ypw, '-r');
% interesting points
px = 0; py = tanh(px);
plot(px, py, 'or', 'linewidth', 1.5, 'markersize', 6.0);
px = atanh(sqrt(1/3)); py = tanh(px);
plot(px, py, 'or', 'linewidth', 1.5, 'markersize', 6.0);
px = atanh(sqrt(2/3)); py = tanh(px);
plot(px, py, 'or', 'linewidth', 1.5, 'markersize', 6.0);
px = 2; py = tanh(px);
plot(px, py, 'or', 'linewidth', 1.5, 'markersize', 6.0);

px = atanh(-sqrt(1/3)); py = tanh(px);
plot(px, py, 'or', 'linewidth', 1.5, 'markersize', 6.0);
px = atanh(-sqrt(2/3)); py = tanh(px);
plot(px, py, 'or', 'linewidth', 1.5, 'markersize', 6.0);
px = -2; py = tanh(px);
plot(px, py, 'or', 'linewidth', 1.5, 'markersize', 6.0);

legend('f(x)', 'Piecewise');
print -dpng plot_derivatives.png;
close;
