function afqcleantracts()
% function afqcleantracts()
% 
% cleans the fiber tracts with AFQ_removeFiberOutliers
%
% DEFAULT maxDist = 4;
% DEFAULT maxLen = 4;
% DEFAULT 100
% DEFAULT maxIter = 5;
%
% Brain Life Team

if ~isdeployed
    switch getenv('ENV')
    case 'IUHPC'
        disp('loading paths (HPC)')
        addpath(genpath('/N/u/hayashis/BigRed2/git/jsonlab'))
        addpath(genpath('/N/u/hayashis/BigRed2/git/afq-master'))
        addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'))
    case 'VM'
        disp('loading paths (VM)')
        addpath(genpath('/usr/local/jsonlab'))
        addpath(genpath('/usr/local/afq-master'))
        addpath(genpath('/usr/local/vistasoft'))
    end
end

config = loadjson('config.json');
disp('config dump')
disp(config)
load(config.afq_fg);

count    = true;
maxLen   = config.maxlen;
numNodes = config.numnodes;
M        = config.M;
maxDist  = config.maxdist;
maxIter  = config.maxiter;

num_tracts = length(fg_classified);
for ii = 1 : num_tracts
    fg_classified_clean(ii) = AFQ_removeFiberOutliers(fg_classified(ii), maxDist, maxLen, numNodes, M, count, maxIter);
end

save('output.mat', 'fg_classified_clean', 'classification');

%%%
%% product.json generation
%%

tract_info = cell(num_tracts, 2);
fibercounts = zeros(1, num_tracts);
num_left_tracts = 0;
num_right_tracts = 0;

for i = 1 : num_tracts
    name = fg_classified(i).name;
    
    if startsWith(name, 'Right ') || endsWith(name, ' R')
        num_right_tracts = num_right_tracts + 1;
    else
        num_left_tracts = num_left_tracts + 1;
    end
end

left_labels = cell(1, num_left_tracts);
right_labels = cell(1, num_right_tracts);

left_cleaned = zeros([1, num_left_tracts]);
right_cleaned = zeros([1, num_right_tracts]);

left_tract_idx = 1;
right_tract_idx = 1;

% sort cleaned tracts by left/right,
% and count how many within each
% tract were cleaned
for i = 1 : num_tracts
    name = fg_classified(i).name;
    num_fibers = length(fg_classified(i).fibers);
    num_fibers_cleaned = length(fg_classified_clean(i).fibers);
    amount_cleaned = num_fibers - num_fibers_cleaned;
    
    basename = name;
    
    if startsWith(basename, 'Right ')
        basename = extractAfter(basename, 6);
    end
    if endsWith(basename, ' R')
        basename = extractBefore(basename, length(basename) - 1);
    end
    
    if startsWith(basename, 'Left ')
        basename = extractAfter(basename, 5);
    end
    if endsWith(basename, ' L')
        basename = extractBefore(basename, length(basename) - 1);
    end
    
    if startsWith(name, 'Right ') || endsWith(name, ' R')
        right_labels{right_tract_idx} = basename;
        right_cleaned(right_tract_idx) = amount_cleaned;
        right_tract_idx = right_tract_idx + 1;
    else
        left_labels{left_tract_idx} = basename;
        left_cleaned(left_tract_idx) = amount_cleaned;
        left_tract_idx = left_tract_idx + 1;
    end
end

bar1 = struct;
bar2 = struct;

bar1.x = left_labels;
bar1.y = left_cleaned;
bar1.type = 'bar';
bar1.name = 'Left';
bar1.marker = struct;
bar1.marker.color = 'rgb(49,130,189)';

bar2.x = right_labels;
bar2.y = right_cleaned;
bar2.type = 'bar';
bar2.name = 'Right';
bar2.marker = struct;
bar2.marker.color = 'rgb(204, 204, 204)';

bardata = {bar1, bar2};
barlayout = struct;
barlayout.title = 'Number of Fibers Cleaned';
barlayout.xaxis = struct;
barlayout.xaxis.tickfont = struct;
barlayout.xaxis.tickfont.size = 8;

barlayout.barmode = 'group';
barplot = struct;
barplot.data = bardata;
barplot.layout = barlayout;

product = {barplot};
savejson('brainlife', product, 'product.json');

%% done generating

%%% 
%% Plotting and visualization code below.
%%
%% Prepare additional parameters for visualization of the results on BL:tract-view

fg_classified = fg_classified_clean;
tracts = fg2Array(fg_classified);
mkdir('tracts');

cm = parula(length(tracts));
for it = 1:length(tracts)
   tract.name   = tracts(it).name;
   tract.color  = cm(it,:);

   %pick randomly up to 1000 fibers (pick all if there are less than 1000)
   fiber_count = min(1000, numel(tracts(it).fibers));
   tract.coords = tracts(it).fibers(randperm(fiber_count));

   all_tracts(it).name = tracts(it).name;
   all_tracts(it).color = cm(it,:);
   savejson('', tract, fullfile('tracts',sprintf('%i.json',it)));
   all_tracts(it).filename = sprintf('%i.json',it);
   clear tract
end

savejson('', all_tracts, fullfile('tracts/tracts.json'));
% saving text file with number of fibers per tracts
tract_info = cell(length(fg_classified), 2);

for i = 1:length(fg_classified)
    tract_info{i,1} = fg_classified(i).name;
    tract_info{i,2} = length(fg_classified(i).fibers);
end

T = cell2table(tract_info);
T.Properties.VariableNames = {'Tracts', 'FiberCount'};

writetable(T,'output_fibercounts.txt')

end


