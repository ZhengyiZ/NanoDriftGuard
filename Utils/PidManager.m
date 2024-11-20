classdef PidManager < StageManager64
    %PIDMANAGER - Incremental PID Controller for Stage Management
    %
    % This class extends the StageManager64 class to implement an 
    % incremental PID controller for managing the stage. 
    % It updates the stage target based on the input delta values.
    %
    % INPUTS:
    %   stage - A struct containing stage configuration parameters:
    %           - sdkpath: Path to the stage controller SDK
    %           - dllpath: Path to the stage controller DLL
    %           - sn: Serial number of the stage controller
    %   pid   - A struct containing PID parameters:
    %           - kp: Proportional gain (3x1 single)
    %           - ki: Integral gain (3x1 single)
    %           - kd: Derivative gain (3x1 single)
    %
    % EXAMPLE:
    %   stageConfig.dllpath = 'C:\ProgramData\PI\GCSTransaltor';
    %   stageConfig.sdkpath = 'C:\Program Files (x86)\Physik Instrumente (PI)\Software Suite\MATLAB_Driver';
    %   stageConfig.sn = 'YourSN';
    %
    %   pidConfig.kp = [0.8; 0.8; 0.5];
    %   pidConfig.ki = [0; 0; 0];
    %   pidConfig.kd = [0; 0; 0.2];
    %
    %   pidManager = PidManager(stageConfig, pidConfig);
    %   delta = [0.1; 0.2; 0.3];    % Example delta values
    %   pidManager.moveDelta(delta);
    %
    % See also StageManager64
    %
    % Author: Zhengyi Zhan
    % Date: Nov 19, 2024
    
    properties (Access = public)
        Kp  % Proportional gain
        Ki  % Integral gain
        Kd  % Derivative gain
    end

    properties (Access = protected)
        target   % Target positions of the stage axes
        currErr  % Current error
        lastErr  % The last error
        prevErr  % Error before the last error
    end
    
    methods
        function obj = PidManager(stage, pid)
            % Constructor, initialize the PID Controller

            % Constructor for superclass
            obj@StageManager64(stage);

            % Initialize PID parameters
            obj.Kp = pid.kp;
            obj.Ki = pid.ki;
            obj.Kd = pid.kd;
            
            % Initialize errors
            obj.currErr = zeros(3, 1, 'single');
            obj.lastErr = obj.currErr;
            obj.prevErr = obj.currErr;
            
            % Initialize the target value
            obj.target = obj.initTarget;
        end
        
        
        function target = moveDelta(obj, delta)
            % Move the stage based on the deltas and PID control

            % Update errors
            obj.prevErr = obj.lastErr;
            obj.lastErr = obj.currErr;
            obj.currErr = -delta;

            % Calculate the target based on incremental PID control
            target = obj.target + ...
                obj.Kp .* (obj.currErr - obj.lastErr) + ...
                obj.Ki .* obj.currErr + ...
                obj.Kd .* (obj.currErr - 2*obj.lastErr + obj.prevErr);

            % Move the stage to the new target
            obj.MOV(target);

            % Update the target
            obj.target = target;
        end

    end
end
