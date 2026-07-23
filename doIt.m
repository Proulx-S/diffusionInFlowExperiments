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


forceThis = 1;
if checkCache(1) || forceThis

%%%%%%%%%%%%%%%%%%%%%
%% Load phantom data
%%%%%%%%%%%%%%%%%%%%%
% Phantom-only for now -- see loadPhantom03.m (copied+adapted from
% multiVencISMRM2026/loadPhantom03.m, same 20251010_multiVENCphantom03 dataset).
phantomName = '20251010_multiVENCphantom03';
[data, dataVenc, dataRun, dataMeas, dataNoFlow, dataNoFlowVenc, dataNoFlowMeas, PEspacing, FEspacing] = ...
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
masks.lumen  =  masks.ID;
masks.tissue = ~masks.OD;
masks = rmfield(masks, {'OD','ID'});

%% %%%%%%%%%%%%%%%%%%%

    saveCache(1)
else
    loadCache(1)
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Lumen/tissue signal vs venc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lumen = inside ID (the flowing channel); tissue = outside OD (surrounding static agar).
% Background phase (ECC) is already corrected inside loadPhantom03.m for both data and
% dataNoFlow (row-wise, from dataNoFlow's own mean phase) -- nothing to redo here.
lumenMask  = masks.lumen;
tissueMask = masks.tissue;

vencList = unique(dataVenc(:));
sigLumenData    = nan(size(vencList));
sigTissueData   = nan(size(vencList));
sigLumenNoFlow  = nan(size(vencList));
sigTissueNoFlow = nan(size(vencList));
for v = 1:numel(vencList)
    d = data(:,:, dataVenc==vencList(v));
    sigLumenData(v)  = mean(d(repmat(lumenMask, 1,1,size(d,3))));
    sigTissueData(v) = mean(d(repmat(tissueMask,1,1,size(d,3))));

    dNoFlow = dataNoFlow(:,:, dataNoFlowVenc==vencList(v));
    sigLumenNoFlow(v)  = mean(dNoFlow(repmat(lumenMask, 1,1,size(dNoFlow,3))));
    sigTissueNoFlow(v) = mean(dNoFlow(repmat(tissueMask,1,1,size(dNoFlow,3))));
end

% categorical x-axis: venc values aren't evenly spaced (and one is Inf), so a plain
% numeric axis would badly compress/exclude points -- one evenly-spaced tick per venc.
vencCat = categorical(compose('%g',vencList), compose('%g',vencList), 'Ordinal', true);

figFld = fullfile(workDir,'figures'); if ~exist(figFld,'dir'); mkdir(figFld); end

figure('MenuBar','none','ToolBar','none');
plot(vencCat, abs(sigLumenData), '-o', vencCat, abs(sigTissueData), '-s');
xlabel('venc'); ylabel('|mean complex signal|'); legend('lumen','tissue'); title('data'); grid on
print(gcf, fullfile(figFld,'lumenTissueVsVenc_data.png'), '-dpng');

figure('MenuBar','none','ToolBar','none');
plot(vencCat, abs(sigLumenNoFlow), '-o', vencCat, abs(sigTissueNoFlow), '-s');
xlabel('venc'); ylabel('|mean complex signal|'); legend('lumen','tissue'); title('dataNoFlow'); grid on
print(gcf, fullfile(figFld,'lumenTissueVsVenc_dataNoFlow.png'), '-dpng');
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




figure
imagesc(abs(mean(data,3))); axis image; colormap gray; colorbar
figure
imagesc(masks.lumen); axis image; colormap gray; colorbar
figure
imagesc(masks.tissue); axis image; colormap gray; colorbar
