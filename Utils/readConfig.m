function [align, stage, cam, file, pid, other] = readConfig(filename)
%READCONFIG Reads configuration parameters from an LabVIEW format INI file
%
% This function reads the specified LabVIEW format INI file, extracts 
% relevant parameters, and returns them as structured outputs.
%
% USAGE:
%   [align, stage, cam, file, pid, other] = readconfig('config.ini');
%
% INPUTS:
%   filename - A string specifying the path to the INI file
%
% OUTPUTS:
%   align - Struct containing alignment parameters
%   stage - Struct containing stage parameters
%   cam   - Struct containing camera parameters
%   file  - Struct containing file paths and debug flag
%   pid   - Struct containing PID parameters for X, Y, and Z axes
%   other - Struct containing other parameters, such as Z-stack settings
%
% NOTES:
%   - This function assumes the INI file is formatted correctly.
%   - See 'NDG_Config.ini' for an example.
% 
% See also lvini2struct
%
% Author: Zhengyi Zhan
% Date: Nov 20, 2024

% Parse the INI file into a struct
cfg = lvini2struct(filename);

% Extract alignment parameters
align = cfg.align;

% Extract stage parameters
stage = cfg.stage;

% Extract camera parameters and insert ROI
cam = cfg.camera;
cam.roi = [cfg.roi.offsetx cfg.roi.offsety cfg.roi.width cfg.roi.height];

% Extract file paths and set debug flag according to updframe
file = cfg.file;
file.debug = (cfg.camera.updframe <= 1+1e-5);

% Extract PID parameters for X, Y, and Z axes
pid.kp = [cfg.x_axis.kp; cfg.y_axis.kp; cfg.z_axis.kp];
pid.ki = [cfg.x_axis.ki; cfg.y_axis.ki; cfg.z_axis.ki];
pid.kd = [cfg.x_axis.kd; cfg.y_axis.kd; cfg.z_axis.kd];

% Extract Z-stack settings
other.zstack = cfg.z_stack.start : cfg.z_stack.step : cfg.z_stack.finish;

end
