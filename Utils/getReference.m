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
% See also getImg, connectCam, StageManager64, regisXpress3
%
% Author: Zhengyi Zhan
% Date: Nov 18, 2024

if nargin < 7
    dispFig = false;
end

% Number of positions
nz = length(absPos);

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
    
end

% Move stage back to initial position
sta.MOV_z(sta.initTarget(3));

% Transfer image stack to GPU
gimgs = gpuArray(imgStack);

% Select reference images for registration
gref = gimgs(:, :, [floor(nz/2)+1 nz 1]);

% Initialize registration results
zeta = ones([nz, 3], 'single');

% Register each images in the stack and store the zeta values
for i = 1:nz
    [~, zeta(i,:)] = regisXpress3(gimgs(:, :, i), 1, i == 1, align, gref);
end

% Linear fit to the registration results
p = polyfit(absPos, (zeta(:,2)-zeta(:,3))./zeta(:,1), 1);

% Compute Z offset, and append to the polynomial coefficients
p(3) = (-p(2)/p(1)) - sta.initTarget(3);

% Display figures if requested
if dispFig
    figure(1);
    subplot 121, imagesc(imgStack(:,:,floor(nz/2)+1)); colormap('hot'); axis image;
    subplot 122, plot(absPos, (zeta(:,2)-zeta(:,3))./zeta(:,1), absPos, p(1).*absPos+p(2));
    title(sprintf('Z Offset: %.4f', p(3)));
end

end
