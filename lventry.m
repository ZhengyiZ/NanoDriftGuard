% This file is part of NanoDriftGuard.
%
% NanoDriftGuard is licensed under the MIT License.
% See the LICENSE file for more information.

function lventry(configFilename)
%LVENTRY - Main entry function for LabVIEW
%
% This script initializes the PID manager, connects the camera, initializes
% local files, captures reference stacks for Z estimation, and then enters 
% a loop to continuously compensate drift based on real-time registration.
% It also serves as an example of how to use the functions.
% 
% INPUT:
%   configFilename - Path to the configuration file
%                    See 'NDG_Config.ini' for an example
%
% NOTE:
%   If function is stopped accidentally, try the following code to release 
%   resources:
%       imaqreset;                                  % reset camera
%       calllib('PI', 'PI_CloseConnection', id);    % 'id' is usally 0
%
% SEE ALSO:
%  readConfig, PidManager, connectCam, fileManage, getImg, getReference, regisXpress3
% 
% Author: Zhengyi Zhan, Xiaofan Sun
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

% Display a message to inform the user how to abort the control loop
fprintf('To abort the control loop, please create %s\n', abortFile);

try
    while ~isfile(abortFile)    % If abort file exists, quit the loop
        tic;
        for i = 1:updFrame      % Use 'updFrame' as a minimum unit to calculate standard derivations
            frame = getImg(vid, avgFrame, roi);     % Get the newest frame(s) from camera
            delta = regisXpress3(gpuArray(frame), p, false);    % Calculate the 3D drift values
            target = pm.moveDelta(delta);   % Move the stage based on the PID controller
            drifts(:, i) = delta * 1e3;     % Add drifts value to record
            pm.generalWait(5e-3);           % Wait for stage to settle
            % pause(5e-3);
        end
        pos = pm.qPOS;                      % Query stage positions
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
fprintf('Abort file detected. Resources have been successfully released.\n');

end
