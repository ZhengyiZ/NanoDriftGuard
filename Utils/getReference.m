% This file is part of NanoDriftGuard.
%
% NanoDriftGuard is licensed under the MIT License.
% See the LICENSE file for more information.

function [p, imgStack] = getReference(sta, absPos, vid, avgframe, roi, ...
    align, dispFig)
%GETREFERENCE - Capture reference image stacks and compute parameters for 
%               Z estimation
%
% This function captures a stack of reference images at specified positions,
% registers the images, and computes parameters for Z estimation
%
% INPUTS:
%   sta      - Stage manager object
%   vid      - Video input object
%   absPos   - Array of absolute positions (unit: um)
%   avgframe - Number of frames to average for each trigger
%   roi      - Region of interest [x, y, width, height]
%   align    - Alignment parameters for image registration and cooridnates transformation
%              - usfac: Upsampling factor (integer). Images will be 
%                       registered to within 1/usfac of a pixel
%              - ample: Number of pixels per micrometer
%              - angle: Angle between the stage coordinate axes and 
%                       the camera coordinate axes
%   dispFig  - Boolean flag to display figures (optional, default is false)
%
% OUTPUTS:
%   p - Polynomial coefficients for Z estimation and offset
%
% EXAMPLE:
%   stage.dllpath = 'C:\ProgramData\PI\GCSTransaltor';
%   stage.sdkpath = 'C:\Program Files (x86)\Physik Instrumente (PI)\Software Suite\MATLAB_Driver';
%   stage.sn = 'YourSN';
%   sta = StageManager64(stage);
%
%   align.usfac = 100;
%   align.ample = 40;
%   align.angle = 0;
% 
%   cam.model = 'MER-630';
%   cam.roi = [0, 0, 512, 512];
%   cam.avgframe = 10;
%   vid = connectCam(cam);
%   align.usfac = 100;
%   dispFig = true;
%   p = getReference(sta, vid, absPos, cam.avgframe, cam.roi, align, dispFig);
%
% NOTE:
%   If the linear fit is not close to the raw data, try adjusting the pause
%   duration between stage movements according to the stage's settling time
% 
% See also getImg, connectCam, StageManager64, regisXpress3
%
% Author: Xiaofan Sun, Zhengyi Zhan
% Date: Nov 18, 2024

if nargin < 7
    dispFig = false;
end

% Number of positions
nz = length(absPos);

fprintf('Start establishling Z-Reference stack...\n');

% Preallocate memory for image stack
imgStack = zeros(roi(4), roi(3), nz, 'single');

for i = 1:nz
    
    % Move stage to the specified position
    sta.MOV_z(absPos(i));
    
    % Pause until the stage is in position
    if i == 1
        pause(0.05);
    else
        pause(0.025);
    end
    
    % Capture images from the camera
    imgStack(:,:,i) = getImg(vid, avgframe, roi);

    fprintf('Stage Position: %.3f\n', absPos(i));
    
end

% Move stage back to the initial position
sta.MOV_z(sta.initTarget(3));

% Transfer image stack to GPU
gimgs = gpuArray(imgStack);

% Select reference images for registration
mid_idx = floor(nz/2)+1;
gref = gimgs(:, :, [mid_idx nz 1]);

% Initialize registration results
zeta = ones([nz, 3], 'single');

% Register each images in the stack and store the zeta values
p = ones(3, 1, 'single');
for i = 1:nz
    [~, zeta(i,:)] = regisXpress3(gimgs(:, :, i), p, i == 1, align, gref);
end

% Linear fit to the registration results
etaRaw = (zeta(:,2) - zeta(:,3)) ./ zeta(:,1);
p = polyfit(absPos, etaRaw, 1);

% Note: After modifying this, 'regisXpress3' (line 241-246) also needs to be modified accordingly
% Compute Z offset (actual)
p(3) = (-p(2)/p(1)) - sta.initTarget(3);

% Compute Z offset (fitted)
% p(3) = (zeta(mid_idx, 2) - zeta(mid_idx, 3)) / zeta(mid_idx, 1);

fprintf('Z-Reference stack obtained.\n');

% Display figure if requested
if dispFig
    figure(1);
    subplot 121, imagesc(imgStack(:, :, mid_idx)); colormap('hot'); axis image;
    subplot 122, plot(absPos, etaRaw, absPos, p(1) * absPos + p(2));
    title(sprintf('Z Offset: %.4f', p(3)));
end

end
