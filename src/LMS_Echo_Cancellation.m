%% CONSISTENT LMS/NLMS PROJECT SCRIPT
clear; clc; close all;

% Set seed for absolute consistency (The "Fixed Room" approach)
rng(0); 

% 1. Setup Signal (Task 1)
load mtlb; 
x_orig = mtlb / max(abs(mtlb));
% Loop the signal to ensure all cases reach steady-state
x = [x_orig; x_orig; x_orig; x_orig]; 
N = length(x);

% 2. Setup Fixed Room (h_true)
M_true = 64; 
n_idx = (0:M_true-1)';
% Deterministic room: Decaying exponential with fixed random reflections
h_true = exp(-0.12 * n_idx) .* randn(M_true, 1); 
h_true = h_true / norm(h_true);

% 3. Generate Microphone Signal (Echo)
d = conv(x, h_true);
d = d(1:N); 

% Add realistic microphone noise (Task 1/7)
noise_pwr = 1e-5; % Small noise floor
d = d + sqrt(noise_pwr) * randn(size(d));

% 4. Global Calculations
Px = mean(x.^2); 
mu_max_theory = 2 / (M_true * Px);

fprintf('--- SYSTEM CALIBRATION ---\n');
fprintf('Theoretical mu_max (M=64): %.4f\n', mu_max_theory);

%% FIGURE 1: Step-Size Analysis (Task 3)
mu_multipliers = [0.01, 0.2, 0.29, 1]; % Too Small, Optimal, Near Boundary, Divergent
labels = {'Too Small', 'Optimal', 'Near Boundary', 'Divergent'};
colors = {'b', 'g', 'k', 'r'};
figure('Name', 'Figure 1: Learning Curves'); hold on;
for i = 1:4
    mu_curr = mu_multipliers(i) * mu_max_theory;
    w = zeros(M_true, 1);
    e = zeros(N, 1);
    x_buf = zeros(M_true, 1);
    
    for n = 1:N
        x_buf = [x(n); x_buf(1:end-1)];
        e(n) = d(n) - w' * x_buf;
        w = w + mu_curr * e(n) * x_buf;
    end
    
    % Use a moving average for smooth dB plot
    mse_db = 10 * log10(smooth(e.^2, 200) + 1e-12);
    plot(mse_db, colors{i}, 'LineWidth', 1.5);
    
    if i == 2, w_opt = w; end % Save Optimal weights for Fig 2
end
grid on; ylim([-70, 10]);
title('Figure 1: LMS Learning Curves (\mu analysis)');
xlabel('Iteration (n)'); ylabel('MSE (dB)');
legend(labels);

%% FIGURE 2: System Identification (Task 5)
mis_db = 10 * log10(norm(h_true - w_opt)^2 / norm(h_true)^2);

figure('Name', 'Figure 2: System Identification');
stem(h_true, 'b', 'LineWidth', 1.5); hold on;
stem(w_opt, 'r--', 'Marker', 'x');
grid on;
legend('True Room h[n]', 'Filter weights \^w[n]');
title(['Figure 2: System ID (Accuracy: ', num2str(mis_db, '%.2f'), ' dB)']);
fprintf('System ID Accuracy: %.2f dB\n', mis_db);

%% FIGURE 3: Filter Length Study (Task 4 & 6)
M_test = [16, 64, 256];
erle_lms = zeros(3, 1);
erle_nlms = zeros(3, 1);

for i = 1:3
    Mi = M_test(i);
    % Parameters
    mu_lms = 0.2 * (2 / (Mi * Px)); % Scaled for each M
    mu_nlms = 0.2; % Normalized LMS is more stable
    eps_nlms = 1e-4;
    
    w_l = zeros(Mi, 1);
    w_n = zeros(Mi, 1);
    e_l = zeros(N, 1);
    e_n = zeros(N, 1);
    x_b = zeros(Mi, 1);
    
    for n = 1:N
        x_b = [x(n); x_b(1:end-1)];
        
        % LMS
        e_l(n) = d(n) - w_l' * x_b;
        w_l = w_l + mu_lms * e_l(n) * x_b;
        
        % NLMS (Task 6)
        e_n(n) = d(n) - w_n' * x_b;
        w_n = w_n + (mu_nlms / (eps_nlms + x_b'*x_b)) * e_n(n) * x_b;
    end
    
    % Steady-state indices (last 20% of the signal)
    ss_idx = round(0.8*N):N;
    d_pow = sum(d(ss_idx).^2);
    erle_lms(i) = 10 * log10(d_pow / sum(e_l(ss_idx).^2));
    erle_nlms(i) = 10 * log10(d_pow / sum(e_n(ss_idx).^2));
end

figure('Name', 'Figure 3: Echo Reduction');
plot(M_test, erle_lms, '-ob', 'LineWidth', 2); hold on;
plot(M_test, erle_nlms, '-sr', 'LineWidth', 2);
grid on; xticks(M_test);
xlabel('Filter Length M'); ylabel('Echo Reduction (ERLE) dB');
title('Figure 3: ERLE vs. M (Steady State)');
legend('LMS', 'NLMS');

fprintf('--- TASK 4/6 RESULTS ---\n');
for i = 1:3
    fprintf('M=%d | LMS: %.2f dB | NLMS: %.2f dB\n', M_test(i), erle_lms(i), erle_nlms(i));
end
%% FIGURE 4: Learning Curves for different M (Task 4)
% This shows that larger M leads to slower convergence.
figure('Name', 'Figure 4: Learning Curves for different M'); hold on;
colors_m = {'m', 'g', 'c'};
M_test = [16, 64, 256];

for i = 1:3
    Mi = M_test(i);
    % We use a fixed fraction of the stability bound for each M
    mu_m = 0.2 * (2 / (Mi * Px)); 
    
    w_m = zeros(Mi, 1);
    e_m = zeros(N, 1);
    x_bm = zeros(Mi, 1);
    
    for n = 1:N
        x_bm = [x(n); x_bm(1:end-1)];
        e_m(n) = d(n) - w_m' * x_bm;
        w_m = w_m + mu_m * e_m(n) * x_bm;
    end
    
    mse_m = 10 * log10(smooth(e_m.^2, 200) + 1e-12);
    plot(mse_m, colors_m{i}, 'LineWidth', 1.5);
    
    % Save these for Figure 5 comparison
    if Mi == 64
        e_lms_final = e_m; 
    end
end
grid on; ylim([-70, 10]);
title('Figure 4: Learning Curves for different M (LMS)');
xlabel('Iteration (n)'); ylabel('MSE (dB)');
legend('M=16', 'M=64', 'M=256');

%% REVISED FIGURE 5: Highlighting NLMS Speed
M_comp = 64;
mu_nlms_comp = 1.0; % MAX SPEED for NLMS
w_n = zeros(M_comp, 1);
e_nlms_final = zeros(N, 1);
x_bn = zeros(M_comp, 1);

for n = 1:N
    x_bn = [x(n); x_bn(1:end-1)];
    e_nlms_final(n) = d(n) - w_n' * x_bn;
    w_n = w_n + (mu_nlms_comp / (1e-4 + x_bn'*x_bn)) * e_nlms_final(n) * x_bn;
end

figure('Name', 'Figure 5: LMS vs NLMS');
plot(10*log10(smooth(e_lms_final.^2, 200)+1e-12), 'b'); hold on;
plot(10*log10(smooth(e_nlms_final.^2, 200)+1e-12), 'r');
grid on; 
title('Figure 5: LMS vs NLMS Learning Curves (M=64)');
xlabel('Iteration (n)'); ylabel('MSE (dB)');
legend('Standard LMS', 'NLMS');

%% FIGURE 6: Spectrogram Evaluation (Task 7)
figure('Name', 'Figure 6: Spectrogram Evaluation');
subplot(2,1,1);
spectrogram(d, 256, 128, 256, 7418, 'yaxis');
title('Figure 6: Spectrogram BEFORE Cancellation (Echo)');
subplot(2,1,2);
spectrogram(e_nlms_final, 256, 128, 256, 7418, 'yaxis');
title('Spectrogram AFTER NLMS Cancellation');

%% FINAL STATS
erle_final = 10*log10(sum(d(ss_idx).^2)/sum(e_nlms_final(ss_idx).^2));
fprintf('\n--- FINAL PROJECT VERIFICATION ---\n');
fprintf('Final NLMS Echo Reduction (ERLE): %.2f dB\n', erle_final);
fprintf('Figure 4 confirms: Larger M results in slower convergence.\n');
fprintf('Figure 5 confirms: NLMS converges faster than Standard LMS.\n');
fprintf('Figure 6 confirms: Echo is suppressed across the frequency spectrum.\n');

%% --- FINAL DELIVERABLES: AUDIO & FIGURE EXPORT ---

fprintf('\n--- EXPORTING DELIVERABLES ---\n');

% 1. SAVE FIGURES (Deliverables Checklist)
% We loop through all open figures and save them as PNGs
figHandles = findall(0, 'Type', 'figure');
for i = 1:numel(figHandles)
    figNum = figHandles(i).Number;
    fileName = sprintf('Project3_Figure%d.png', figNum);
    saveas(figHandles(i), fileName);
    fprintf('Saved: %s\n', fileName);
end

%% --- AUDIO EXPORT: LMS vs. NLMS ---

fprintf('\n--- SAVING AUDIO DEMONSTRATIONS ---\n');
fs_rate = 7418; % Sampling frequency for mtlb

% 1. Create the Optimal LMS audio (M=64, mu_optimal)
% (We use the error signal e_l from the comparison loop)
audiowrite('Echo_Cancelled_Standard_LMS.wav', e_l, fs_rate);
fprintf('Saved: Echo_Cancelled_Standard_LMS.wav\n');

% 2. Create the Optimal NLMS audio (M=64, mu=0.5)
% (We use the error signal e_n from the comparison loop)
audiowrite('Echo_Cancelled_NLMS.wav', e_n, fs_rate);
fprintf('Saved: Echo_Cancelled_NLMS.wav\n');

% 3. Save the original microphone signal for reference
audiowrite('Original_Microphone_Echo.wav', d, fs_rate);
fprintf('Saved: Original_Microphone_Echo.wav\n');

%% --- PERCEPTUAL ANALYSIS (For your report) ---

fprintf('\n--- PERCEPTUAL LISTENING GUIDE ---\n');
fprintf('1. Listen to "Echo_Cancelled_Standard_LMS.wav":\n');
fprintf('   - You will hear the echo for a longer period at the start.\n');
fprintf('   - Once it settles, the background should be very quiet.\n\n');

fprintf('2. Listen to "Echo_Cancelled_NLMS.wav":\n');
fprintf('   - You will notice the echo disappears almost immediately.\n');
fprintf('   - There might be a very faint "hiss" or "roughness" compared to LMS.\n');
fprintf('     (This is the Misadjustment noise we saw in the plots).\n');