function [coor, zeta] = regisXpress3(gimg, k, firstcall, align, gref)
%REGISXPRESS3 - Highly efficient 3D subpixel image registration
%
% This function performs highly efficient 3D subpixel image registration 
% using cross-correlation. It is optimized for repeated calls using the
% same reference images and includes several enhancements over the original 
% dftregistration function by Manuel Guizar et al. Note that persistent 
% local variables is used to reduce the overhead of repeated calls. 
% It outperforms the class version.
% 
% USAGE:
%   First call:       [~, zeta] = regisXpress3(gimg, k, true, align, gref)
%   Subsequent calls: [coor, ~] = regisXpress3(gimg, k, false)
%
% INPUTS:
%   gimg      - The input image to be registered (2D GPU array)
%   k         - Slope for z-axis estimation
%   firstcall - Boolean flag, set true for the first call to the function
%   align     - (required if firstcall is true) Struct containing alignment
%               parameters:
%                - usfac: Upsampling factor (integer). Images will be 
%                         registered to within 1/usfac of a pixel
%                - ample: Number of pixels per micrometer
%                - angle: Angle between the stage coordinate axes and 
%                         the camera coordinate axis
%   gref      - (required if firstcall is true) Reference image stack 
%               3D GPU array
%
% OUTPUTS:
%   coor      - Coordinates (unit: um)
%   zeta      - Zeta values for the linear fit of z-estimation
% 
% EXAMPLES:
%   First call:
%     align.usfac = 100;
%     align.ample = 40;
%     align.angle = 0;
%     nz = 21; % Number of images in the stack
%     pos = linspace(-0.1, 0.1, nz);             % Example positions (unit: um)
%     imgStack = rand(512, 512, nz, 'single');   % Example image stack
%     gimgs = gpuArray(imgStack);                % Transfer image stack to GPU
%     gref = gimgs(:, :, [floor(nz/2)+1 nz 1]);  % Select reference images for registration
%     % Register each images in the stack and store the zeta values
%     for i = 1:nz
%         [~, zeta(i,:)] = regisXpress3(gimgs(:,:,i), 1, i==1, align, gref);
%     end
%     % Linear fit to the registration results
%     p = polyfit(pos, (zeta(:,2)-zeta(:,3))./zeta(:,1), 1);
%
%   Subsequent calls:
%     imgNew = rand(512, 512, 'single'); % Example new image
%     [coor, ~] = regisXpress3(gpuArray(imgNew), p(1), false);    % Use the slope for z-axis estimation
%
% Summary of modifications:
% 1. Extended reference from single image to image stack for Z-axis estimation
% 2. Optimized with persistent local variables to reduce repeated overhead
% 3. GPU-accelerated FFT and matrix multiplication
% 4. Optimize FTpad using array reassignment on GPU directly
% 5. Added coordinates transformation based on calibration
%
% NOTES:
%   To maximize performance, this function doesn't implement error checking
%   Please ensure that inputs are provided as specified in the example.
% 
% Zhengyi Zhan - Nov 20, 2024
% 
% Co-authored modifications copyright (c) 2024, Zhengyi Zhan, Xiaofan Sun
% Zhejiang University. All rights reserved.
% 
% Original work copyright (c) 2016, Manuel Guizar Sicairos, James R. Fienup
% University of Rochester. All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
% 
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
%     * Neither the name of the University of Rochester nor the names
%       of its contributors may be used to endorse or promote products derived
%       from this software without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.

% Persistent variables to retain values between function calls
persistent scfac
persistent usfac
persistent R

persistent nr
persistent nc
persistent nri
persistent nci

persistent ftRefs
persistent rf00

persistent ftpadM
persistent ftpadSubIdx
persistent ftpadCenter
persistent ftpadNr
persistent ftpadNc
persistent ftpadNrs
persistent ftpadProd

persistent dftn
persistent dftShift
persistent dftKernr
persistent dftKernc
persistent dftNor
persistent dftNoc
persistent dftNr
persistent dftNc
persistent dftProd

if firstcall
    % Initialize cooridnates transform related variables
    usfac = single(align.usfac);                % Upsampling factor
    scfac = single( 1 / align.ample / usfac );  % Scaling factor
    R = single([cos(align.angle), sin(align.angle); ...
        -sin(align.angle), cos(align.angle)]);   % Rotation matrix

    % Get the size of the input image
    [nrd, ncd] = size(gimg);
    nr = single(nrd);       % Number of rows    (single)
    nc = single(ncd);       % Number of columns (single)
    nri = int32(nrd);       % Number of rows    (int32)
    nci = int32(ncd);       % Number of columns (int32)

    % Initialize FFT of the reference image stack
    ftRefs = fft2(gref);
    rf00 = reshape(gather(sum(abs(ftRefs).^2, [1 2])), 1, 3);

    % Initialize variables for padding the Fourier transform
    ftpadM = zeros([2*nr, 2*nc, 3], 'like', ftRefs);   % Preallocation for padding matrix
    imgCenter = int32(floor([nr nc] / 2));
    ftpadSubIdx = int32([2*nr 2*nc]) - imgCenter;      % Submatrix indices for padding
    ftpadCenter = imgCenter + int32(mod([nr nc], 2));  % Center indices for padding, add 1 if odd
    ftpadNr = int32(2*nr);                             % Padding size for rows (int32)
    ftpadNc = int32(2*nc);                             % Padding size for columns
    ftpadNrs = 2*nr;                                   % Padding size for rows (single)
    ftpadProd = 4*nr*nc;                               % Padding size product, for reshape

    % Initialize variables for DFT upsampling
    dftn = single( ceil(usfac*1.5) );
    dftShift = fix( dftn/2 );
    dftKernr = gpuArray( (-1i*2*pi/(nr*usfac)) * ...
        (ifftshift(0:nr-1) - floor(nr/2)) );    % DFT kernel for rows
    dftKernc = gpuArray( (-1i*2*pi/(nc*usfac)) * ...
        (ifftshift(0:nc-1).' - floor(nc/2)) );  % DFT kernel for columns
    dftNor = gpuArray( repmat((0:dftn-1).', 1, 1, 3) );
    dftNoc = gpuArray( repmat((0:dftn-1), 1, 1, 3) );
    dftNr = ifftshift( -fix(nr) : ceil(nr)-1 ); % DFT row indices
    dftNc = ifftshift( -fix(nc) : ceil(nc)-1 ); % DFT column indices
    dftProd = dftn ^ 2;                         % DFT size product, for ind2sub
end

% Perform FFT of the input image
ft = fft2(gimg);
rg00g = sum(abs(ft).^2, 'all');
c = ft .* conj(ftRefs);

%%%%%%%%%%%% FTPAD %%%%%%%%%%%%
% Padding the Fourier domain matrix directly on GPU using array assignment
ftpadM(1:ftpadCenter(1), 1:ftpadCenter(2), :) = ...
    c(1:ftpadCenter(1), 1:ftpadCenter(2), :);           % left top
ftpadM(1:ftpadCenter(1), ftpadSubIdx(2)+1:ftpadNc, :) = ...
    c(1:ftpadCenter(1), ftpadCenter(2)+1:nci, :);       % right top
ftpadM(ftpadSubIdx(1)+1:ftpadNr, 1:ftpadCenter(2), :) = ...
    c(ftpadCenter(1)+1:nri, 1:ftpadCenter(2), :);       % left btm
ftpadM(ftpadSubIdx(1)+1:ftpadNr, ftpadSubIdx(2)+1:ftpadNc, :) = ...
    c(ftpadCenter(1)+1:nri, ftpadCenter(2)+1:nci, :);   % right btm

% Inverse Fourier transform and scaling
ccFT = abs(ifft2(ftpadM * 4)); % scalefac

% Find the indexes of maximum
[~, idxftg] = max(reshape(ccFT, ftpadProd, 3), [], 1);

% Gather the max index from GPU
idxft = single(gather(idxftg));

% Convert to the index of rows and columns in CPU
rowIdxFT = rem(idxft-1, ftpadNrs) + 1;
colIdxFT = (idxft - rowIdxFT) / ftpadNrs + 1;

% Compute shifts
rowShiftFT = round(dftNr(rowIdxFT) / 2 * usfac);
colShiftFT = round(dftNc(colIdxFT) / 2 * usfac);

% Compute offsets
roff = reshape(dftShift - rowShiftFT, 1, 1, 3);
coff = reshape(dftShift - colShiftFT, 1, 1, 3);

%%%%%%%%%%%% DFT %%%%%%%%%%%%
% Compute DFT kernels
kernr = exp( pagemtimes(dftNor - roff, dftKernr) );
kernc = exp( pagemtimes(dftKernc, dftNoc - coff) );

% Compute cross-correlation using DFT
ccDFT = abs(pagemtimes(kernr, pagemtimes(ftRefs .* conj(ft), kernc)));

% Find the maximum value and its index in DFT space
[dftMaxg, idxdftg] = max(ccDFT, [], [1 2], "linear");

% Gather results from GPU
[dftMax, idxdft, rg00] = gather(dftMaxg, idxdftg, rg00g);

% Convert to the index of rows and cols (3D Version)
vi = rem(single(idxdft)-1, dftProd) + 1;
rowIdxDFT = rem(vi-1, dftn) + 1;
colIdxDFT = (vi - rowIdxDFT) / dftn + 1;

% Compute zeta values
zeta = sqrt( reshape(dftMax, 1, 3) .^2 ./ (rg00 .* rf00) );
% zeta = sqrt( abs(reshape(dftMax, 1, 3) .^2 ./ (rg00 .* rf00)) );

% Transform to the actual coordinates
xyCoor = R * ([rowShiftFT(1); colShiftFT(1)] + ...
    [rowIdxDFT(1) - dftShift - 1; ...
    colIdxDFT(1) - dftShift - 1]) * scfac;

% Append the estimated z-coordinate
coor = [xyCoor; (zeta(2) - zeta(3)) / (zeta(1) * k)];

end
