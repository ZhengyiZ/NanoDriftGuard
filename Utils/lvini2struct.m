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
