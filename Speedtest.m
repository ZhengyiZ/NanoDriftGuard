clear;
addpath('Utils\');

%% PARAMETERS
numImgs = 3;                % Number of images, must be at least 3
imgSize = [128, 256, 512];  % Image size for speed test
times = 5e2;                % Number of times to run the algorithm

align.usfac = 100;          % Upsampling factor
align.ample = 1;
align.angle = 0;

%% GET HARDWARE
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

%% SPEED TEST
timeResults = zeros(times, length(imgSize));
p = ones(1, 3, 'single');

for i = 1:length(imgSize)
    imgs = rand(imgSize(i), imgSize(i), numImgs, 'single'); % Random images

    gref = gpuArray(imgs);

    for j = 1:times
        tic;
        coor = regisXpress3(gpuArray(imgs(:,:,1)), p, j==1, align, gref);   % only set true for the first call
        timeResults(j, i) = toc;
    end
end

timeResults = timeResults * 1e3; % Convert to ms

%% PLOT
avgTime = mean(timeResults, 1);
stdTime = std(timeResults, 0, 1);

fprintf('CPU: %s\n', cpuInfo);
fprintf('GPU: %s\n', gpuInfo.Name);
fprintf('Usfac: %d\n', align.usfac);

figure;
for i = 1:length(imgSize)
    % Calculate the display limits based on mean and std
    lowerLimit = avgTime(i) - 3 * stdTime(i);
    upperLimit = avgTime(i) + 3 * stdTime(i);

    histogram(timeResults(:, i), 'normalization', 'probability', ...
        'BinLimits', [max(0, lowerLimit), upperLimit]);
    if i == 1
        hold on;
    end
    fprintf('For %d x %d x %d images, the algorithm took an average of %.3f ms ± %.3f ms\n', ...
        imgSize(i), imgSize(i), numImgs, avgTime(i), stdTime(i));
end
hold off;
xlabel('Time (ms)');
ylabel('Probability');
title('Histogram of Algorithm Execution Time');
legend(arrayfun(@(x) sprintf('%d x %d x %d', x, x, numImgs), imgSize, 'UniformOutput', false));
