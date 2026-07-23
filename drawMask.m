function masks = drawMask(im, labels, opts)
% DRAWMASK  Minimal interactive polygon-ROI drawing + caching, one mask per label.
%
% For each name in LABELS: if a cached mask already exists under opts.cacheDir, load it
% (no figure, no interaction). Otherwise show IM and let the user draw a polygon (MATLAB's
% roipoly -- click vertices, double-click or Enter to close), then cache the resulting
% mask AND its polygon vertices so the next call reuses it. With opts.force, a redraw is
% pre-seeded from the cached polygon (a touch-up, not starting over).
%
% IM     -- 2D image to draw on (e.g. abs(mean(data,3)))
% LABELS -- cellstr (or single char) of mask names, e.g. {'OD','ID'}
% OPTS   -- opts.cacheDir (default: fullfile(pwd,'drawMaskCache')) -- git-tracked cache
%             dir; a hand-drawn mask is irreplaceable human effort, not regenerable, so
%             its .mat files are the one exception to this project's blanket *.mat
%             gitignore rule (mirrors vfMRItools/drawVessel.m's own drawVesselCache).
%           opts.id    (default: '') -- optional prefix disambiguating multiple images
%             sharing the same cache dir (e.g. a second phantom/dataset later)
%           opts.force (default: false) -- redraw even if cached (seeded from the cached
%             polygon)
%
% Returns MASKS, a struct with one logical field per label.
%
% No-arg call (opts = drawMask) returns default opts, per Bass's self-populating-opts
% convention (.bass/pkm/patterns/self-populating-default-opts.md).

if nargin==0
    opts = struct();
    opts.cacheDir = fullfile(pwd,'drawMaskCache');
    opts.id       = '';
    opts.force    = false;
    fprintf('drawMask opts (defaults):\n');
    fprintf('  cacheDir : char, default ''%s'' -- git-tracked cache dir\n', opts.cacheDir);
    fprintf('  id       : char, default '''' -- optional cache-filename prefix\n');
    fprintf('  force    : true/false, default false -- redraw even if cached (seeded)\n');
    masks = opts;
    return
end

if ~exist('opts','var') || isempty(opts); opts = struct(); end
if ~isfield(opts,'cacheDir') || isempty(opts.cacheDir); opts.cacheDir = fullfile(pwd,'drawMaskCache'); end
if ~isfield(opts,'id');                                 opts.id      = '';                             end
if ~isfield(opts,'force') || isempty(opts.force);       opts.force   = false;                          end

if ischar(labels) || isstring(labels); labels = {char(labels)}; end
if ~exist(opts.cacheDir,'dir'); mkdir(opts.cacheDir); end

masks = struct();
for k = 1:numel(labels)
    label = labels{k};
    if ~isempty(opts.id)
        cacheFile = fullfile(opts.cacheDir, [matlab.lang.makeValidName(opts.id) '_' matlab.lang.makeValidName(label) '.mat']);
    else
        cacheFile = fullfile(opts.cacheDir, [matlab.lang.makeValidName(label) '.mat']);
    end

    xi = []; yi = [];
    if isfile(cacheFile) && ~opts.force
        s = load(cacheFile,'mask');
        masks.(label) = s.mask;
        fprintf('drawMask: loaded cached mask ''%s'' <- %s\n', label, cacheFile);
        continue
    elseif isfile(cacheFile) && opts.force
        s = load(cacheFile,'xi','yi');   % seed the redraw from the existing polygon
        xi = s.xi; yi = s.yi;
    end

    fprintf('drawMask: draw ''%s'' -- click vertices, double-click (or Enter) to close\n', label);
    if isempty(xi)
        [mask, xi, yi] = roipoly(im);
    else
        [mask, xi, yi] = roipoly(im, xi, yi);
    end
    close(gcf);

    save(cacheFile,'mask','xi','yi');
    fprintf('drawMask: saved mask ''%s'' -> %s\n', label, cacheFile);
    masks.(label) = mask;
end
