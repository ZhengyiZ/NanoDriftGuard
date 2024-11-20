% This file is part of NanoDriftGuard.
%
% NanoDriftGuard is licensed under the MIT License.
% See the LICENSE file for more information.

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
% Date: Nov 15, 2024

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


function result = lvini2struct(filename)
%LVINI2STRUCT parses an INI file in LabVIEW format and returns as a struct
%
% This function parses an INI file in LabVIEW format and returns its
% contents as a MATLAB struct. It handles sections and variables, and
% processes special cases for numerical, string, path, and boolean values.
%
% USAGE:
%   result = lvini2struct(filename)
%
% INPUTS:
%   filename - A string specifying the path to the INI file
%
% OUTPUTS:
%   result - A struct containing the parsed contents of the INI file
%
% EXAMPLE:
%   iniFile = 'D:\NDG\config.ini';
%   cfg = lvini2struct(iniFile);
%
% NOTES:
%   - This function assumes the INI file is formatted correctly
%
% Author: Zhengyi Zhan
% Date: Nov 15, 2024

% Initialize the result struct and variable for current section name
result = struct();
section = '';

% Open the INI file for reading
f = fopen(filename, 'r');
if f == -1
    error('Failed to open file: %s', filename);  % Handle file open error
end

% Read the file until the end
while ~feof(f)

    % Read and trim each line
    s = strtrim(fgetl(f));

    % Skip empty lines
    if isempty(s)
        continue;
    end

    % Ignore comment lines starting with ';' or '#'
    if startsWith(s, {';', '#'})
        continue;
    end

    % Handle section names enclosed in square brackets '[ ]'
    if startsWith(s, '[') && endsWith(s, ']')
        section = matlab.lang.makeValidName(lower(s(2:end-1)));
        result.(section) = struct();
    else
        % Parse key-value pair
        [key, value] = parsePair(s);

        if ~isempty(section)
            result.(section).(key) = value;
        else
            % If no section found, treat as a top-level key-value pair
            result.(key) = value;
        end
    end

end

% Close the file
fclose(f);

end


function [key, value] = parsePair(s)
%PARSEPAIR - Parse a key-value pair from a string
%
% This helper function parses a key-value pair from a string and returns
% the key and value as separate outputs.
%
% INPUTS:
%   s - A char array containing the key-value pair in the format 'key = value'
%
% OUTPUTS:
%   key   - A char array containing the key.
%   value - A char array containing the value.

% Split the string at the first '=' character
[key, value] = strtok(s, '=');

% Convert the key to a valid MATLAB field name
key = matlab.lang.makeValidName(lower(key));

% Clean value (trim and remove leading '=')
value = strtrim(value);
if strcmpi(value(1), '=')
    value(1) = [];
end
value = strtrim(value);

% Process the value according to its type (string, path, boolean, or numeric)
if startsWith(value, '"') && endsWith(value, '"')
    % If value is a string, remove the surrounding quotes
    value = strip(value, '"');

    % If the value is a path, convert it to Windows format
    if startsWith(value, '/')
        value = [value(2) ':' value(3:end)];
        value = strrep(value, '/', '\');
    end

elseif any(strcmpi(value, {'TRUE', 'FALSE'}))
    % If value is a boolean, convert it to logical
    value = strcmpi(value, 'TRUE');

else
    % If value is numeric, try to convert it
    tmp = str2double(value);

    % If the conversion is successful, use the numeric value
    if ~isnan(tmp)
        value = tmp;
    end

end

end
