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

%%%%%%%%%%%%%%%%%%%%
%% Load phantom data
%%%%%%%%%%%%%%%%%%%%%
% Phantom-only for now -- see loadPhantom03.m (copied+adapted from
% multiVencISMRM2026/loadPhantom03.m, same 20251010_multiVENCphantom03 dataset).
phantomName = '20251010_multiVENCphantom03';
[data, dataVenc, dataRun, dataMeas, dataNoFlow, dataNoFlowVenc, dataNoFlowMeas, PEspacing, FEspacing] = ...
    loadPhantom03(fullfile(dataDir, phantomName));
%% %%%%%%%%%%%%%%%%%

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

%% %%%%%%%%%%%%%%%%%%

    saveCache(1)
else
    loadCache(1)
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Lumen/tissue signal vs venc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lumen = inside ID (the flowing channel); tissue = outside OD (surrounding static agar).
% Background phase (ECC) is already corrected inside loadPhantom03.m for both data and
% dataNoFlow (row-wise, from dataNoFlow's own mean phase) -- nothing to redo here.
lumenMask  = masks.lumen;
tissueMask = masks.tissue;

figure; hT = tiledlayout(1,3); hT.TileSpacing = 'compact'; hT.Padding = 'compact'; ax = {};
imAvg = abs(mean(data,3));
imAvgLumen  = imAvg; imAvgLumen( ~masks.lumen ) = 0;
imAvgTissue = imAvg; imAvgTissue(~masks.tissue) = 0;
ax{end+1} = nexttile(hT); imagesc(imAvg); axis image; colormap gray; colorbar
ax{end+1} = nexttile(hT); imagesc(imAvgLumen); axis image; colormap gray; colorbar
ax{end+1} = nexttile(hT); imagesc(imAvgTissue); axis image; colormap gray; colorbar
set([ax{:}],'CLim',ax{1}.CLim)

vencList = unique(dataVenc(:));
sigLumenData    = cell(size(vencList));
sigTissueData   = cell(size(vencList));
sigLumenNoFlow  = cell(size(vencList));
sigTissueNoFlow = cell(size(vencList));

for v = 1:numel(vencList)
    d = mean(data(:,:, dataVenc==vencList(v)), 3);
    sigLumenData{v}  = d(repmat(lumenMask, 1,1,size(d,3)));
    sigTissueData{v} = d(repmat(tissueMask,1,1,size(d,3)));

    dNoFlow = mean(dataNoFlow(:,:, dataNoFlowVenc==vencList(v)), 3);
    sigLumenNoFlow{v}  = dNoFlow(repmat(lumenMask, 1,1,size(dNoFlow,3)));
    sigTissueNoFlow{v} = dNoFlow(repmat(tissueMask,1,1,size(dNoFlow,3)));
end
sigLumenData    = cat(2,sigLumenData{:});
sigTissueData   = cat(2,sigTissueData{:});
sigLumenNoFlow  = cat(2,sigLumenNoFlow{:});
sigTissueNoFlow = cat(2,sigTissueNoFlow{:});

whos sigLumenData sigTissueData sigLumenNoFlow sigTissueNoFlow


sigLumenData1    = abs(mean(sigLumenData,1));
sigTissueData1   = abs(mean(sigTissueData,1));
sigLumenNoFlow1  = abs(mean(sigLumenNoFlow,1));
sigTissueNoFlow1 = abs(mean(sigTissueNoFlow,1));



% categorical x-axis: venc values aren't evenly spaced (and one is Inf), so a plain
% numeric axis would badly compress/exclude points -- one evenly-spaced tick per venc.
vencCat = categorical(compose('%g',vencList), compose('%g',vencList), 'Ordinal', true);

figFld = fullfile(workDir,'figures'); if ~exist(figFld,'dir'); mkdir(figFld); end

figure; hT = tiledlayout(1,3); hT.TileSpacing = 'compact'; hT.Padding = 'compact'; ax = {};
ax{end+1} = nexttile(hT); plot(vencCat, sigLumenData1, '.-', vencCat, sigTissueData1, '.-');
ax{end+1} = nexttile(hT); plot(vencCat, sigLumenNoFlow1, '.-', vencCat, sigTissueNoFlow1, '.-');
yLim = get([ax{:}],'YLim'); yLim = [yLim{:}]; yLim = [min(yLim), max(yLim)]; set([ax{:}],'YLim',yLim);
xlabel([ax{:}],'venc'); ylabel([ax{:}],'|mean complex signal|'); legend('lumen','tissue'); title('data'); grid([ax{:}],'on')
title(ax{1},'data'); title(ax{2},'dataNoFlow');



whos sigLumenData sigTissueData sigLumenNoFlow sigTissueNoFlow

sigLumenNoFlow2    = abs(sigLumenNoFlow )./abs(sigLumenNoFlow( :,vencList==inf));
sigTissueNoFlow2   = abs(sigTissueNoFlow)./abs(sigTissueNoFlow(:,vencList==inf));
nLumen  = size(sigLumenNoFlow2 ,1);
nTissue = size(sigTissueNoFlow2,1);
% 95% CI half-width (t-based, not the SEM itself) -- CI = tinv(0.975,n-1) * SEM
sigLumenNoFlow2_av = mean(sigLumenNoFlow2   ,1)';
sigLumenNoFlow2_er = std( sigLumenNoFlow2,[],1)'./sqrt(nLumen) .* tinv(0.975,nLumen-1);
sigTissueNoFlow2_av = mean(sigTissueNoFlow2   ,1)';
sigTissueNoFlow2_er = std( sigTissueNoFlow2,[],1)'./sqrt(nTissue) .* tinv(0.975,nTissue-1);
ax{end+1} = nexttile(hT);
errorbar(vencCat, sigLumenNoFlow2_av, sigLumenNoFlow2_er); hold on
errorbar(vencCat, sigTissueNoFlow2_av, sigTissueNoFlow2_er);
grid(ax{end},'on')
xlabel(ax{end},'venc');
ylabel(ax{end},'cross-voxel mean of |complex signal|/|complex signal at venc=inf|');
legend(ax{end},'lumen','tissue');
title(ax{end},'dataNoFlow');



print(gcf, fullfile(figFld,'lumenTissueVsVenctaNoFlow.png'), '-dpng');







