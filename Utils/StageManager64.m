% This file is part of NanoDriftGuard.
%
% NanoDriftGuard is licensed under the MIT License.
% See the LICENSE file for more information.
% 
% Original work COPYRIGHT (c) PHYSIKINSTRUMENTE (PI) GMBH U. CO. KG
% support-software@pi.ws

classdef StageManager64 < handle
    %STAGEMANAGER64 - Stage Manager using PI GCS2 DLL (64 bit)
    %
    % This class provides an interface to control a stage in active
    % stabilization system using the PI GCS2 DLL (64-bit). 
    % It includes methods for connecting to the stage, querying positions, 
    % querying and setting targets, and releasing resources. 
    % This class is based on the MATLAB Class Library provided by 
    % PHYSIKINSTRUMENTE (PI) and has been modified to include only the 
    % minimal control required for the active stabilization system.
    %
    % INPUTS:
    %   stage - A struct containing stage configuration parameters:
    %           - sdkpath: Path to the stage controller SDK
    %           - dllpath: Path to the stage controller DLL
    %           - sn: Serial number of the stage controller
    %
    % EXAMPLE:
    %   stageConfig.dllpath = 'C:\ProgramData\PI\GCSTransaltor';
    %   stageConfig.sdkpath = 'C:\Program Files (x86)\Physik Instrumente (PI)\Software Suite\MATLAB_Driver';
    %   stageConfig.sn = 'YourSN';
    %   stageManager = StageManager64(stageConfig);
    %   
    %   target = rand(3, 1);            % Example target position
    %   stageManager.MOV(target);       % Move to the target position
    %   stageManager.generalWait(1e-2); % Wait until the stage stops moving
    %   pos = stageManager.qPOS();      % Query the current positions
    %   
    %   clear stageManager;             % Clear the object to trigger the delete method
    %
    % NOTES:
    %   - This class assumes the PI Software Suite is correctly installed.
    %   - For best performance, some error handling has been simplified.
    %
    % See also loadlibrary, calllib, libisloaded, unloadlibrary
    %
    % Author: Zhengyi Zhan
    % Date: Nov 19, 2024

    properties (Access = public)
        numberAxes      % Number of axes of the stage
        initTarget      % Initial targets of the stage axes
    end

    properties (Access = protected)
        id = -1         % Identifier for the stage connection
        allAxes = []    % All axes identifier (char array)
        xAxis = []      % X axis idertifer (char array)
        yAxis = []      % Y axis idertifer (char array)
        zAxis = []      % Z axis idertifer (char array)
    end

    methods
        function obj = StageManager64(stage)
            % Constructor, initialze the stage

            % Load library if it is not loaded
            if ~libisloaded('PI')
                % Add the SDK path to MATLAB search path, for the prototype file
                if isfolder(stage.sdkpath)
                    addpath(stage.sdkpath)
                end
                loadlibrary(fullfile(stage.dllpath, 'PI_GCS2_DLL_x64.dll'), ...
                    @PI_GCS2_DLL_prototype_x64, 'alias', 'PI');
            end

            % Try to connect to the stage
            try
                obj = obj.connect(stage.sn);
            catch exception
                obj.release();
                rethrow(exception);
            end

        end


        function delete(obj)
            % Destructor, release the connection to the stage
            
            obj.release();
        end

        
        function obj = connect(obj, sn)
            % Try connecting to the stage using the serial number

            % Attempt to connect to the stage controller via USB using the serial number
            obj.id = calllib('PI', 'PI_ConnectUSB', sn);

            % Check if the connection was successful
            if obj.id < 0
                error('Interface could not be opened or no controller is responding.');
            else
                % Initialize a character buffer to store the response from the controller
                charBuffer = blanks(513);

                % Query all available axes from the controller
                [~, charBuffer] = calllib('PI', 'PI_qSAI_ALL', obj.id, charBuffer, 512);

                % Extract the axes names from the response
                axesCell = regexp(charBuffer, '[\w-]+', 'match');

                % Store the number of axes
                obj.numberAxes = length(axesCell);

                % Assign the axes names to the corresponding properties
                [obj.xAxis, obj.yAxis, obj.zAxis] = deal(axesCell{1:3});

                % Concatenate all axes names into a char array
                obj.allAxes = strjoin(axesCell, ' ');

                % Check if any axes were returned
                if isempty(obj.allAxes)
                    error('Controller is not returnning axes.');
                end

                % Query the initial positions
                obj.initTarget = obj.qMOV();
            end
        end
        
        
        function connected = isconnected(obj)
            % Check if the stage is connected

            connected = calllib('PI', 'PI_IsConnected', obj.id);
        end
        
        
        function obj = release(obj)
            % Close the stage connection

            calllib('PI', 'PI_CloseConnection', obj.id);
            obj.id = -1;
        end

        
        function target = qMOV(obj)
            % Query the current targets for all axes

            target = zeros(obj.numberAxes, 1);
            pVals = lib.pointer('doublePtr', target);
            [~, ~, target] = calllib('PI', 'PI_qMOV', obj.id, obj.allAxes, pVals);
        end
        
        
        function MOV(obj, target)
            % Move to the specified targets for all axes

            ptr = lib.pointer('doublePtr', target);
            if calllib('PI', 'PI_MOV', obj.id, obj.allAxes, ptr) == 0
                error('Out of limit');
            end
        end

        
        function MOV_z(obj, target)
            % Move the Z-axis only

            ptr = lib.pointer('doublePtr', target);
            if calllib('PI', 'PI_MOV', obj.id, obj.zAxis, ptr) == 0
                error('Out of limit');
            end
        end
        
        
        function pos = qPOS(obj)
            % Query the current positions of all axes

            pos = zeros(obj.numberAxes, 1);
            pVals = lib.pointer('doublePtr', pos);
            [~, ~, pos] = calllib('PI', 'PI_qPOS', obj.id, obj.allAxes, pVals);
        end

        
        function pos = qPOS_z(obj)
            % Query the current position of the Z-axis only

            pos = zeros(1, 1);
            pVals = lib.pointer('doublePtr', pos);
            [~, ~, pos] = calllib('PI', 'PI_qPOS', obj.id, obj.zAxis, pVals);
        end

        function result = isMoving(obj)
            % Check if the stage is still moving

            if obj.id < 0
                error('Stage is not connected.');
            end
            vals = zeros(obj.numberAxes, 1, 'int32');
            pVals = lib.pointer('int32Ptr', vals);
            [~, ~, vals] = calllib('PI', 'PI_IsMoving', obj.id, obj.allAxes, pVals);
            result = any(vals);
        end


        function result = isMoving_z(obj)
            % Check if the Z-axis is moving

            if obj.id < 0
                error('Stage is not connected.');
            end
            vals = zeros(1, 1, 'int32');
            pVals = lib.pointer('int32Ptr', vals);
            [~, ~, vals] = calllib('PI', 'PI_IsMoving', obj.id, obj.zAxis, pVals);
            result = any(vals);
        end

        
        function generalWait(obj, pollCycle, addWait)
            % Wait until the stage stops moving
            % 
            % INPUTS:
            %   pollCycle - Polling cycle duration in seconds, default is 1e-2
            %   addWait   - Additional wait time in seconds, default is 0
            %
            % NOTES:
            %   - This method will block execution until the stage stops moving

            % If additional wait time is specified, pause for that duration
            if nargin == 3
                pause(addWait);
            elseif nargin < 2
                pollCycle = 1e-2;
            end

            % Poll the movement status of the stage at the specified interval
            while obj.isMoving
                pause(pollCycle);
            end
        end

    end

end
