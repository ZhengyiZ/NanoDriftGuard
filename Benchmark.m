clear;

%% PARAMETERS
numImgs = 3;                % Number of images, must be at least 3
imgSize = [128 256 512];    % Image size for speed test
times = 1e3;                % Number of times to run the algorithm

skipCpu = true;

align.usfac = 100;          % Upsampling factor
align.ample = 1;
align.angle = 0;

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

%% BENCHMARK
timeResults = zeros(times, length(imgSize)*2);
p = ones(1, 3, 'single');

for i = 1:length(imgSize)
    imgs = rand(imgSize(i), imgSize(i), numImgs, 'single'); % Random images
    imgFT = fft2(imgs);
    gref = gpuArray(imgs);

    if ~skipCpu
        for j = 1:times
            tic;
            for k = 1:numImgs
                out = dftregistration(fft2(imgs(:,:,1)), imgFT(:,:,k), align.usfac);
            end
            timeResults(j, i) = toc;
        end
    end

    for j = 1:times
        tic;
        coor = regisXpress3(gpuArray(imgs(:,:,1)), p, j==1, align, gref);   % only set true for the first call
        timeResults(j, length(imgSize)+i) = toc;
    end
end

timeResults = timeResults * 1e3; % Convert to ms

%% PLOT
avgTime = mean(timeResults(2:end, :), 1);
stdTime = std(timeResults(2:end, :), 0, 1);

fprintf('MATLAB: %s\n', matlabVersion);
fprintf('CPU: %s\n', cpuInfo);
fprintf('GPU: %s\n', gpuInfo.Name);
fprintf('Usfac: %d\n', align.usfac);

% Determine the global X-axis limits based on all data
globalLowerLimit = min(avgTime - 3 * stdTime);
globalUpperLimit = max(avgTime + 3 * stdTime);

figure;
if skipCpu
    fprintf('For regisXpress3:\n');
    for i = length(imgSize)+1:2*length(imgSize)
        histogram(timeResults(2:end, i), 'Normalization', 'probability', ...
            'BinLimits', [max(0, globalLowerLimit), globalUpperLimit]);
        hold on;

        fprintf('For %d x %d x %d images, the algorithm took an average of %.3f ms ± %.3f ms\n', ...
            imgSize(i-length(imgSize)), imgSize(i-length(imgSize)), numImgs, avgTime(i), stdTime(i));
    end
else
    % Plot for CPU
    subplot(2, 1, 1);
    fprintf('For CPU:\n');
    for i = 1:length(imgSize)
        histogram(timeResults(2:end, i), 'Normalization', 'probability', ...
            'BinLimits', [max(0, globalLowerLimit), globalUpperLimit]);
        hold on;

        fprintf('For %d x %d x %d images, the algorithm took an average of %.3f ms ± %.3f ms\n', ...
            imgSize(i), imgSize(i), numImgs, avgTime(i), stdTime(i));
    end
    hold off;
    xlabel('Time (ms)');
    ylabel('Probability');
    title('Histogram of Algorithm Execution Time (CPU)');
    xlim([max(0, globalLowerLimit), globalUpperLimit]);

    % Plot for regisXpress3
    subplot(2, 1, 2);
    fprintf('For regisXpress3:\n');
    for i = length(imgSize)+1:2*length(imgSize)
        histogram(timeResults(2:end, i), 'Normalization', 'probability', ...
            'BinLimits', [max(0, globalLowerLimit), globalUpperLimit]);
        hold on;

        fprintf('For %d x %d x %d images, the algorithm took an average of %.3f ms ± %.3f ms\n', ...
            imgSize(i-length(imgSize)), imgSize(i-length(imgSize)), numImgs, avgTime(i), stdTime(i));
    end
end
hold off;
xlabel('Time (ms)');
ylabel('Probability');
title('Histogram of Algorithm Execution Time (regisXpress3)');
xlim([max(0, globalLowerLimit), globalUpperLimit]);
legend(arrayfun(@(x) sprintf('%d x %d x %d', x, x, numImgs), imgSize, 'UniformOutput', false));
