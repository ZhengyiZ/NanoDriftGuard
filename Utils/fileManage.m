function fileManage(opa, data, FPS, drifts, target, pos)
%FILEMANAGE - Manage file operations for active stabilization system
%
% This function manages various file operations for active stabilization
% system, including initialization, updating status, saving images, and 
% appeding drift history. It uses persistent variables to maintain state 
% across multiple calls.
%
% USAGE:
%   fileManage('init', dataStruct)
%   fileManage('update', img, FPS, drifts, target, pos)
%   fileManage('abort')
%
% INPUTS:
%   opa    - A string specifying the operation to perform. Possible values:
%            'init'   - Initialize the file manager
%            'update' - Update the status and drift histroy
%            'abort'  - Clean up when stabilization aborts
%   data   - For 'init': A struct containing various configurations:
%            - runningfile: Path to the file indicating the running status
%            - abortfile: Path to the file indicating the abort command
%            - statusfile: Path to the status file (.txt)
%            - historypath: Directory path for saving history file (.csv)
%            - autosavepath: Base path for saving images
%            - debug: Boolean flag for debug mode
%            - live: Boolean flag for saving images
%            For 'update': A 2D matrix (single) for the image data
%   FPS    - Correction frequency / frames per second (required for 'update')
%   drifts - Record for drifts calculated (required for 'update')
%   target - Target position of the stage (required for 'update')
%   pos    - Current position of the stage (required for 'update')
% 
% EXAMPLE:
%   % First call to initialize the file manager
%   file.runningfile  = 'D:\NDG\running.txt';
%   file.abortfile    = 'D:\NDG\abort.txt';
%   file.statusfile   = 'D:\NDG\status.txt';
%   file.historypath  = 'D:\NDG\history\';
%   file.autosavepath = 'D:\NDG\Autosave\';
%   file.debug = false;
%   file.live = true;
%   fileManage('init', file);
%
%   % Subsequent calls to update status and save images
%   img    = rand(512, 512, 'single'); % Example image data
%   FPS    = 50;
%   drifts = rand(3, 20, 'single');    % Example drift records
%   target = rand(3, 1);               % Example targets
%   pos    = rand(3, 1);               % Example current positions
%   fileManage('update', img, FPS, drifts, target, pos);
%
%   % Last call to clean up
%   fileManage('abort');
%
% Author: Zhengyi Zhan
% Date: Nov 19, 2024

persistent runningFile
persistent abortFile
persistent statusHandle
persistent historyHandle
persistent autosavePath
persistent firstcall
persistent live
persistent debugMode
persistent picCount
persistent writebmpHandle

if strcmp(opa, 'init')
    % Set persistent variables from the input struct
    runningFile = data.runningfile;
    abortFile = data.abortfile;
    debugMode = data.debug;
    live = data.live;

    % Set persistent variables from struct
    firstcall = true;
    picCount = 0;
    
    % Get the BMP write function handle
    fmt_s = imformats('bmp');
    writebmpHandle = fmt_s.write;

    % Clear and open the status file for writing
    statusHandle = fopen(data.statusfile, 'w+');

    % Generate the current date string
    dateStr = char(datetime('now'), 'yyyyMMdd');

    % Initialize a counter for file naming
    count = 1;

    % Generate history file path and check if file exists
    historyTmp = fullfile(data.historypath, [dateStr '_' ...
        num2str(count, '%03d') '.csv']);
    while isfile(historyTmp)
        count = count + 1;
        historyTmp = fullfile(data.historypath, [dateStr '_' ...
            num2str(count, '%03d') '.csv']);
    end
    historyFile = historyTmp;

    % Generate the autosave path corresponding to history filename
    autosavePath = fullfile(data.autosavepath, [dateStr '_' ...
        num2str(count, '%03d') '\']);

    % Create the autosave directory
    if ~mkdir(autosavePath)
        warning('Failed to create autosave directory: %s', data.autosavePath);
    end

    % Open the history file for appending and write the header
    historyHandle = fopen(historyFile, 'a');
    if debugMode
        fprintf(historyHandle, ['TimeStamp,Driftx,Drifty,Driftz,' ...
            'FPS(Hz),PicName,Target_x,Target_y,Target_z,QPOSx,QPOSy,QPOSz\r\n']);
    else
        fprintf(historyHandle, ['TimeStamp,STDx,STDy,STDz,FPS(Hz),' ...
            'PicName,Target_x,Target_y,Target_z,QPOSx,QPOSy,QPOSz\r\n']);
    end

elseif strcmp(opa, 'update')
    if firstcall
        % Create a running file to indicate the system is active
        fclose(fopen(runningFile, 'w'));
        firstcall = false;
    end
    
    % Save images if live mode is enabled
    if live
        picName = [sprintf('%06d', picCount) '.bmp'];
        feval(writebmpHandle, uint8(data*255), [], [autosavePath picName]);
        picCount = picCount + 1;
    else
        picName = 'nopic.bmp';
    end
    
    % Generate the status string
    if debugMode
        str = sprintf(['%s,%.4f,%.4f,%.4f,%.2f,%s,' ...
            '%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\r\n'], ...
            char(datetime('now'), 'HH:mm:ss.SSS'), ...
            drifts(1), drifts(2), drifts(3), FPS, picName, ...
            target(1), target(2), target(3), ...
            pos(1), pos(2), pos(3));
    else
        stdVal = std(drifts, 0, 2);
        str = sprintf(['%s,%.4f,%.4f,%.4f,%.2f,%s,' ...
            '%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\r\n'], ...
            char(datetime('now'), 'HH:mm:ss.SSS'), ...
            stdVal(1), stdVal(2), stdVal(3), FPS, picName, ...
            target(1), target(2), target(3), ...
            pos(1), pos(2), pos(3));
    end

    % Overwrite the status file with the new status string
    frewind(statusHandle);
    fprintf(statusHandle, str);

    % Append the new status string to the history file
    fprintf(historyHandle, str);

elseif strcmp(opa, 'abort')
    % Close file handles
    fclose(historyHandle);
    fclose(statusHandle);

    % Delete the running and abort files if they exist
    if isfile(runningFile)
        delete(runningFile);
    end

    if isfile(abortFile)
        delete(abortFile);
    end

    % Reset persistent variables
    statusHandle = [];
    historyHandle = [];
    runningFile = '';
    abortFile = '';
    autosavePath = '';
    firstcall = false;
    live = true;
    debugMode = false;
    picCount = 0;

else
    % Additional operations would be implemented here
    return
end

end
