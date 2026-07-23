function [data, dataVenc, dataRun, dataMeas, dataNoFlow, dataNoFlowVenc, dataNoFlowMeas, PEspacing, FEspacing] = loadPhantom03(dataPath)
% Load the 20251010_multiVENCphantom03 inflow phantom, cropped to include a bit of
% static agar around the tube. Copied+adapted from multiVencISMRM2026/loadPhantom03.m
% (same phantom, same raw .mat layout) so this project doesn't depend on that one.
%
% dataPath -- folder containing a 'raw' subfolder with the coil-combined *_fft_*.mat
%             runs (e.g. .../dbPhantom/20251010_multiVENCphantom03)
%
% Returns per-voxel complex data (data/dataNoFlow) plus per-frame venc/run/meas
% index arrays (same size along the 3rd/measurement dimension), and the FE/PE
% in-plane pixel spacing (mm).
%
% dataNoFlowVenc is tracked and sorted independently of data/dataVenc (added -- the
% original multiVencISMRM2026 version computed a dataNoFlowVenc{iRun} per-run but never
% concatenated/returned it, then reordered dataNoFlow using `b`, the sort permutation
% derived from dataVenc's own order. That's only valid if every run's still-phase count
% exactly matches its infuse-phase count, which holds for this dataset -- verified: both
% end up length 78 -- but isn't guaranteed by construction, so dataNoFlow now gets its
% own tracked+sorted venc instead of silently borrowing data's permutation).

FEspacing = 0.5;      % mm per pixel in FE direction
PEspacing = 0.8929;   % mm per pixel in PE direction

coilMethod = 'bartMap-';
timeOffset = [3 6 0 2 5];
fileName = ['_fft_coilComb-' strrep(coilMethod, '-', '') '_FEcrop150-176_PEcrop83-100'];
runList = dir(fullfile(dataPath,'raw',['*' fileName '.mat'])); runList([runList.isdir]) = [];
runList(contains({runList.name},'_longTR')) = [];

infuse   = 3;
withdraw = 3;
still    = 3;
cycleLength = infuse + withdraw + still;
stillIdx  = cell(size(runList));
infuseIdx = cell(size(runList));

for iRun = 1:length(runList)
    load(fullfile(runList(iRun).folder,runList(iRun).name));

    % Time points with flow
    infuseIdx2 = ((  timeOffset(iRun) + 2                      ):cycleLength:(size(img,11)+cycleLength));
    infuseIdx{iRun} = sort([infuseIdx2(:)])';
    if infuseIdx{iRun}(1)>cycleLength
        infuseIdx{iRun} = infuseIdx{iRun} - cycleLength;
    end
    infuseIdx{iRun}(infuseIdx{iRun}>size(img,11)) = [];
    data{iRun}     = img(  :,:,:,:,:,:,:,:,:,:,infuseIdx{iRun},:,:,:,:,:);
    dataVenc{iRun} = repmat(venc                                                                       ,[1 1 1 1 1 1 1            1 1 1 length(infuseIdx{iRun}) 1 1 1 1]);
    dataRun{iRun}  = repmat(iRun                                                                       ,[1 1 1 1 1 1 size(venc,7) 1 1 1 length(infuseIdx{iRun}) 1 1 1 1]);
    dataMeas{iRun} = repmat(permute(1:length(infuseIdx{iRun}),[1 3 4 5 6 7 8 9 10 11 2 12 13 14 15 16]),[1 1 1 1 1 1 size(venc,7) 1 1 1 1                       1 1 1 1]);

    % Time points with no flow
    stillIdx2  = ((  timeOffset(iRun) + 2 + infuse + withdraw  ):cycleLength:(size(img,11)+cycleLength));
    stillIdx{iRun}  = sort([stillIdx2(:)])';
    if stillIdx{iRun}(1)>cycleLength
        stillIdx{iRun} = stillIdx{iRun} - cycleLength;
    end
    stillIdx{iRun}(stillIdx{iRun}>size(img,11)) = [];
    dataNoFlow{iRun}     = img(  :,:,:,:,:,:,:,:,:,:,stillIdx{iRun},:,:,:,:,:);
    dataNoFlowVenc{iRun} = repmat(venc                                                                       ,[1 1 1 1 1 1 1            1 1 1 length(stillIdx{iRun}) 1 1 1 1]);
    dataNoFlowMeas{iRun} = repmat(permute(1:length(stillIdx{iRun}),[1 3 4 5 6 7 8 9 10 11 2 12 13 14 15 16]),[1 1 1 1 1 1 size(venc,7) 1 1 1 1                      1 1 1 1]);

    % ECC using no-flow data points (row-wise: less noisy, leverages the directional
    % nature of the background phase error, vs. voxel-wise or ROI-wise)
    data{iRun}       = data{iRun}      ./exp(1j.*angle(mean(dataNoFlow{iRun},[2 11])));
    dataNoFlow{iRun} = dataNoFlow{iRun}./exp(1j.*angle(mean(dataNoFlow{iRun},[2 11])));
end

% Compile across runs and sort by venc and run
data       = cat(11,data{:}    );
dataVenc   = cat(11,dataVenc{:});
dataRun    = cat(11,dataRun{:} );
dataMeas   = cat(11,dataMeas{:} );
dataNoFlow     = cat(11,dataNoFlow{:}    );
dataNoFlowVenc = cat(11,dataNoFlowVenc{:});
dataNoFlowMeas = cat(11,dataNoFlowMeas{:}    );

data       = data(:,:,:);
dataVenc   = dataVenc(:,:,:);
dataRun    = dataRun(:,:,:);
dataNoFlow     = dataNoFlow(:,:,:);
dataNoFlowVenc = dataNoFlowVenc(:,:,:);
dataNoFlowMeas = dataNoFlowMeas(:,:,:);

[~,b] = sort(dataVenc,'descend');
data       = data(:,:,b);
dataVenc   = dataVenc(:,:,b);
dataRun    = dataRun(:,:,b);
dataMeas   = dataMeas(:,:,b);

% dataNoFlow sorted by its OWN venc order -- see header note; not the same permutation as data's `b`.
[~,bNoFlow] = sort(dataNoFlowVenc,'descend');
dataNoFlow     = dataNoFlow(:,:,bNoFlow);
dataNoFlowVenc = dataNoFlowVenc(:,:,bNoFlow);
dataNoFlowMeas = dataNoFlowMeas(:,:,bNoFlow);
