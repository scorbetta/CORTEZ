% Compare convergence between tanh and its piecewise approximation in the activation function
t01 = load('tanh_a01.csv');
t001 = load('tanh_a001.csv');
t0001 = load('tanh_a0001.csv');
p01 = load('pw_a0001.csv');
p001 = load('pw_a001.csv');
p0001 = load('pw_a01.csv');

figure;
subplot(5,1,2:4);
hold all;
semilogy(t01,'-b');
semilogy(t001,'-k');
semilogy(t0001,'-r');
semilogy(p01,'--b');
semilogy(p001,'--k');
semilogy(p0001,'--r');
xlabel('Epoch');
ylabel('Error');
grid on;
legend('tanh w/ \alpha=0.1', 'tanh w/ \alpha=0.01', 'tanh w/ \alpha=0.001', 'pwise w/ \=0.1', 'pwise w/ \=0.01', 'pwise w/ \=0.001');
title('Convergence comparison w/ 100 training vectors');
print -dpng compare_convergence.png;
close;
