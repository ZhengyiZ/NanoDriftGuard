function release = initMATLAB
%INITMATLAB - Initialize MATLAB environment
%
% This function adds the current folder and its subfolders to the MATLAB
% search path and returns the current MATLAB release version.
%
% OUTPUTS:
%   release - A string representing the current MATLAB release version
%
% EXAMPLE:
%   currentRelease = initMATLAB;
%   disp(['Current MATLAB release: ', currentRelease]);
%
% Author: Zhengyi Zhan
% Date: June 12, 2024

    % Add the current folder and its subfolders to the search path
    p = genpath(pwd);
    addpath(p);
    
    % Get the MATLAB version information
    s = ver;

    % Extract and return the release version
    tmp = extractBetween(s(1).Release,'(',')');
    release = tmp{1};
    
end
