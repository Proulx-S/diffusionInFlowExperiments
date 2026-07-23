clearvars
close all
restoredefaultpath



%%%%%%%%%%%%%%%%%%%%%
%% Set up environment
%%%%%%%%%%%%%%%%%%%%%
os   = char(java.lang.System.getProperty('os.name'));
host = char(java.net.InetAddress.getLocalHost.getHostName);

workDir    = fileparts(mfilename('fullpath'));
if strcmp(host,'takoyaki')
    toolDir = '/scratch/bass/tools';
else
    toolDir = fullfile(workDir,'..','..','tools');   % fallback for other/unrecognized hosts
end
devToolDir = fullfile(workDir,'devTools');   % getClone.m target -- detached local-dev tool copies land here (see develop-tool-locally skill)
dataDir    = '/local/users/Proulx-S/dbPhantom';

% Branch pinned for this project. gitClone enforces it on every tool repo.
branch = '';

% Bootstrap: clone util (default branch) if absent so gitClone.m is on the path.
tool = 'util'; toolURL = 'https://github.com/Proulx-S/util.git';
tDir = toolDir;
if ~exist(fullfile(tDir, tool), 'dir'); system(['git clone ' toolURL ' ' fullfile(tDir, tool)]); end
addpath(genpath(fullfile(tDir,tool)))

%%% matlab on git (branch-pinned via gitClone)
tool = 'util'; repoURL = 'https://github.com/Proulx-S/util'; subTool = '';
tDir = toolDir;
gitClone(repoURL, fullfile(tDir, tool), subTool, branch);
%% %%%%%%%%%%%%%%%%%%


forceThis = 0;
if checkCache(1) || forceThis

%%%%%%%%%%%%%%%%%%%%%
%% Load phantom data
%%%%%%%%%%%%%%%%%%%%%
% Phantom-only for now -- see loadPhantom03.m (copied+adapted from
% multiVencISMRM2026/loadPhantom03.m, same 20251010_multiVENCphantom03 dataset).
phantomName = '20251010_multiVENCphantom03';
[data, dataVenc, dataRun, dataMeas, dataNoFlow, dataNoFlowMeas, PEspacing, FEspacing] = ...
    loadPhantom03(fullfile(dataDir, phantomName));
%% %%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%
%% Draw phantom masks
%%%%%%%%%%%%%%%%%%%%%
% OD/ID = outer/inner tube diameter boundary -- same naming as multiVencISMRM2026/
% doIt_inflow.m's own ID=6.35mm/OD=11.11mm constants for this same phantom. Cached to
% drawMaskCache/ (git-tracked, see .gitignore) -- drawn once, reused on every later run.
imMag = abs(mean(data,3));
masks = drawMask(imMag, {'OD','ID'});
%% %%%%%%%%%%%%%%%%%%%

    saveCache(1)
else
    loadCache(1)
end





figure
imagesc(abs(mean(data,3))); axis image; colormap gray; colorbar
