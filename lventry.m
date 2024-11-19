function lventry(configFilename)
%LVENTRY - Main entry function for LabVIEW
%
% This script initializes the PID manager, connects to the camera, initializes
% local files, captures reference stacks for Z estimation, and enters a loop
% to continuously drift compensation based on real-time image registration.
% Also, it is an example of how to use the project's functions.
% 
% INPUT:
%   configFilename - Path to the configuration file
%                    See NDG_Config.ini for an example
%
% SEE ALSO:
%  readConfig, PidManager, connectCam, fileManage, getImg, getReference, regisXpress3
% 
% Author: Zhengyi Zhan
% Date: Nov 20, 2024

% Read configuration from the specified file (labview can pass in a string)
[align, stage, cam, file, pid, other] = readConfig(configFilename);

% Extract common variables from struct to avoid overheads
roi = cam.roi;
avgFrame = cam.avgframe;
updFrame = cam.updframe;
abortFile = file.abortfile;

% Initialize the PID manager (Stage manager is initialized inside)
pm = PidManager(stage, pid);

% Try to initialize camera
% If not successful, release the PID manager and quit
try
    vid = connectCam(cam);
catch exception
    clear pm;
    rethrow(exception);
end

% Initialize local files
fileManage('init', file);

% Get reference stacks for Z estimatation
absPos = other.zstack/1e3 + pm.initTarget(3);
dispFlag = true;
p = getReference(pm, absPos, vid, avgFrame, roi, align, dispFlag);

% Initialize drift records
drifts = zeros(3, updFrame, 'single');

try
    while ~isfile(abortFile)    % If abort file exists, quit the loop
        
        tic;
        % Minimum unit
        for i = 1:updFrame
            % Get the newest frame(s) from camera
            frame = getImg(vid, avgFrame, roi);

            % Calculate the 3D drift values
            delta = regisXpress3(gpuArray(frame), p(1), false); % Send the slope only

            % Move the stage based on the PID controller
            target = pm.moveDelta(delta);

            % Add records
            drifts(:, i) = delta * 1e3;

            % Wait for stage to settle
            % pm.generalWait(5e-3);
            pause(5e-3);

        end

        % Query stage positions
        pos = pm.qPOS;

        % Update status and save images
        fileManage('update', frame, updFrame/toc, drifts, target, pos);
    end
catch exception
    % When encountered errors like target out of limits, move the stage back
    pm.MOV(pm.initTarget);
    
    % Clean up
    fileManage('abort');
    stop(vid);
    delete(vid);
    clear pm vid;

    rethrow(exception);
end

% If abort is requested, clean up
fileManage('abort');
stop(vid);
delete(vid);
clear pm vid;

end
