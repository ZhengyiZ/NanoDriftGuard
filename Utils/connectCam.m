function vid = connectCam(camera, maxRetry)

arguments
    camera struct {mustBeNonempty}
    maxRetry (1,1) {mustBeInteger, mustBePositive} = 3
end

%CONNECTCAM - Connect to a specified gentl camera with retry mechanism
%
% This function attempts to connect to a specified camera using the 
% Image Acquisition Toolbox. It retries the connection a specified number 
% of times if not succeed, in case camera is not released yet.
%
% INPUTS:
%   camera   - A struct containing camera configuration parameters:
%              - model: A string specifying the camera model.
%              - roi: A 4-element vector specifying the region of interest 
%                     [x, y, width, height].
%              - avgframe: An integer specifying the number of frames to 
%                          average per trigger.
%   maxRetry - (Optional) An integer specifying the maximum number of 
%              retry attempts if the camera is not found or if there is an 
%              error during connection. Default is 3.
%
% OUTPUTS:
%   vid - A video input object representing the connected camera.
%
% EXAMPLE:
%   cameraConfig.model = 'MER-630';
%   cameraConfig.roi = [0, 0, 512, 512];
%   cameraConfig.avgframe = 10;
%   vid = connectCam(cameraConfig, 5);
%
% See also IMAQHWINFO, VIDEOINPUT, TRIGGERCONFIG.
%
% Author: Zhengyi Zhan
% Date: Nov 17, 2024

found = false;
lastError = [];

% In case the camera is not released by other programs
for i = 1:maxRetry
    try
        % Get information about available 'gentl' devices
        info = imaqhwinfo('gentl');
        if isempty(info.DeviceInfo)
            error('No devices found');
        end

        % Extract device names and find the index of the specified camera
        names = string({info.DeviceInfo.DeviceName});
        idx = find(contains(names, camera.model, 'IgnoreCase', true), 1);   % Only find the first one

        if isempty(idx)
            error('Specified camera not found');
        else
            % Create a video input object for the specified camera
            vid = videoinput('gentl', idx, 'Mono8', ...
                'ROIPosition', camera.roi, ...
                'FramesPerTrigger', camera.avgframe);

            % Configure the video input object for manual triggering
            triggerconfig(vid, 'manual');
            vid.TriggerRepeat = Inf;

            % Start streaming
            start(vid);

            found = true;
            break
        end

    catch exception
        % Store the last error
        lastError = exception;
        % If not found, pause 50 ms between retry attempts
        pause(0.05);
        continue
    end
end

% If the camera was not found after the specified number of attempts, 
% throw an error
if ~found
    if isempty(lastError)
        error('Camera %s not found after %d attempts.', camera.model, ...
            maxRetry);
    else
        error(['Failed to initialize camera %s after %d attempts. ' ...
            'Last error: %s'], camera.model, maxRetry, lastError.message);
    end
end

end
