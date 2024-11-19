function img = getImg(vid, avgframe, roi)
%GETIMG - Capture images based on specified number of frames
%
% This function captures images from a video input object, optionally
% averaging multiple frames. The captured image is then normalized and
% reshaped according to the specified image size
%
% INPUTS:
%   vid      - Video input object
%   avgframe - Number of frames to average. If avgframe is 1, a single frame
%              is captured. If avgframe > 1, multiple frames are averaged
%   roi      - A 4-element vector specifying the region of interest 
%              [x, y, width, height].
%
% OUTPUTS:
%   img - The captured image, normalized to the range [0, 1].
%
% EXAMPLE:
%   cameraConfig.model = 'MER-630';
%   cameraConfig.roi = [0, 0, 512, 512];
%   cameraConfig.avgframe = 10;
%   vid = connectCam(cameraConfig);
%   img = getImg(vid, cameraConfig.avgframe, cameraConfig.roi);
%
% NOTES:
%   - This function does not implement any error handling to achieve 
%     maximum speed.
% 
% See also CONNECTCAM.
% 
% Author: Zhengyi Zhan
% Date: Nov 17, 2024

% Trigger the video input object to start acquisition
trigger(vid);

% Wait until the specified number of frames are available
while vid.FramesAvailable ~= avgframe
end

% Capture and process images
if avgframe == 1
    % Capture a single frame
    % Avoid error handling to achieve maximum speed
    img = single( ...
        getdata(imaqgate('privateGetField', vid, 'uddobject')) ) / 255;
else
    % Capture multiple frames, average them, and reshape according to ROI
    img = reshape( ...
        mean( single( getdata( ...
        imaqgate('privateGetField', vid, 'uddobject') ) / 255), 4), ...
        roi(4), roi(3));
end

end
