clc;
clear;
close all;

% Define the window size for the moving standard derivations
windowSize = 100;

load("Dataset\Demo.mat");

%% GET HARDWARE INFORMATION
% Check CUDA availability and get GPU information
if gpuDeviceCount == 0
    error('No CUDA-capable GPU is available.\n');
else
    gpuInfo = gpuDevice;
end

% Get CPU information
[~, cpuInfo] = system('wmic cpu get name');
cpuInfo = splitlines(strtrim(cpuInfo));
cpuInfo = cpuInfo{2};

% Get MATLAB version
matlabVersion = initMatlab;

%% GET Z FIT
tic;
% Transfer image stack to GPU
grefs = gpuArray(refs);

% Select reference images for registration
nz = size(refs, 3);
mid_idx = floor(nz/2) + 1;
gref3 = grefs(:, :, [mid_idx nz 1]);

% Initialize registration results
zeta = ones([nz, 3], 'single');

% Register each images in the stack and store the zeta values
p = ones(3, 1, 'single');
for i = 1:nz
    [~, zeta(i,:)] = regisXpress3(grefs(:, :, i), p, i == 1, align, gref3);
end

% Linear fit to the registration results
etaRaw = (zeta(:,2) - zeta(:,3)) ./ zeta(:,1);
p = polyfit(absPos, etaRaw, 1);

% Compute Z offset (actual)
p(3) = (-p(2)/p(1)) - absPos(mid_idx);

% Compute Z offset (fitted)
% p(3) = (zeta(mid_idx, 2) - zeta(mid_idx, 3)) / zeta(mid_idx, 1);

zfitTime = toc;

%% CALCULATE 3D DRIFT
% Initialize drift records
driftRecords = zeros(3, size(imgs, 3), 'single');
timeResults = zeros(size(imgs, 3), 1);

% Calculate 3D Drifts of images captured during active drift correction
for i = 1:size(imgs, 3)
    tic;
    % Send one image to GPU every time
    driftRecords(:, i) = regisXpress3(gpuArray(imgs(:,:,i)), p, false);
    % Record time consuming
    timeResults(i) = toc;
end

%% EXTRACT RESULTS
% correct z offset
driftRecords(3, :) = driftRecords(3, :) - p(3);

% convert time to ms & drift to nm
timeResults = timeResults * 1e3;
driftRecords = driftRecords * 1e3;

% Initialize the moving average and moving std for drifts
driftMovStd = zeros([3, size(imgs, 3) - windowSize + 1], 'single');
driftMovMean = driftMovStd;
for i = 1:(size(imgs, 3) - windowSize + 1)
    tmp = driftRecords(:, i:i+windowSize-1);
    driftMovStd(:, i) = std(tmp, 0, 2);
    driftMovMean(:, i) = mean(tmp, 2);
end

% Padding
driftMovMean = [nan(3, windowSize-1) driftMovMean];

% Fit to normal distribution
pd_time = fitdist(timeResults, 'Normal');
for i = 1:3
    pd(i) = fitdist(driftMovStd(i, :)', 'Normal');
end

%% DISPLAY RESULTS
% figure for z-fit
figure;
subplot(2, 3, 1);
imagesc(refs(:, :, 1));
axis image off;

subplot(2, 3, 2);
imagesc(refs(:, :, mid_idx));
axis image off;
title(sprintf('The initial z-fit took %.0f ms\nReference Images', ...
    zfitTime*1e3));

subplot(2, 3, 3);
imagesc(refs(:, :, nz));
axis image off; colormap('hot');

subplot(2, 3, [4 5 6]);
plot(absPos, etaRaw, '--ok');
hold on;
plot(absPos, p(1) * absPos + p(2), 'LineWidth', 1.5);
hold off;
axis tight;
xlabel('Stage Position_z (\mum)');
ylabel('\eta');
legend('Raw', 'Fit', 'Location', 'northwest');
title([sprintf('Z Offset: %.2f', p(3)*1e3) 'nm']);

% figure for drifts
figure;
for i = 1:3
    subplot(5, 3, [1 2 3] + (i-1)*3);
    plot(driftRecords(i, :));
    hold on;
    plot(driftMovMean(i, :), 'LineWidth', 1.5);
    hold off;
    ylim([-2 2]);

    switch i
        case 1
            ylabel('\Delta x (nm)');
        case 2
            ylabel('\Delta y (nm)');
        case 3
            ylabel('\Delta z (nm)');
    end

    if i == 3
        xlabel('frames');
    end

    subplot(5,3,i+9);
    histogram(driftMovStd(i, :), 'Normalization', 'pdf');
    hold on;
    plot(0.2:1e-3:0.5, normpdf(0.2:1e-3:0.5, pd(i).mu, pd(i).sigma), 'LineWidth', 1.5);
    
    switch i
        case 1
            text(0.42, 15, sprintf('\\sigma_x = %.2f nm', pd(i).mu));
            ylabel('Probability Density');
            xlabel('\sigma_x (nm)');
        case 2
            text(0.42, 15, sprintf('\\sigma_y = %.2f nm', pd(i).mu));
            xlabel('\sigma_y (nm)');
        case 3
            text(0.42, 15, sprintf('\\sigma_z = %.2f nm', pd(i).mu));
            xlabel('\sigma_z (nm)');
    end

    hold off;
    xlim([0.2 0.5]);
    ylim([0 20]);

    subplot(5,3,[13 14 15]);
    histogram(timeResults, 'Normalization', 'pdf');
    hold on;
    plot(min(xlim):1e-2:max(xlim), normpdf(min(xlim):1e-2:max(xlim), ...
        pd_time.mu, pd_time.std), 'LineWidth', 1.5);
    hold off;
    xlabel('Time Consuming (ms)');
    ylabel('Probability Density');
    
    text(max(xlim)*0.85, max(ylim)*0.65, sprintf('%.3f ± %.3f ms', ...
        pd_time.mu, pd_time.std));
end
