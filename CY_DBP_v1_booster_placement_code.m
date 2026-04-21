try
    d.unload;
catch
end
fclose('all'); clear class; clc; close all;clear all;
load_paths;  % include EPANET-MATLAB toolkit

tic


%% Network input file
inpname = 'CY-DBP_v1.inp';
%'new_zone2_Quality_with_tank_data_verified.inp';

%'Zone_1_Final.inp';
%inpname = 'new_zone2_Quality_with_tank_no_boosters.inp';
% inpname = 'new_zone2_Quality_with_tank_data_verified.inp';
% inpname = 'new_zone2_Quality_mod.inp';
% inpname = 'CY-DBP_dist_edited_final_nopat.inp';

d = epanet(inpname);
[~, dispname, ~] = fileparts(inpname);
Hfile = ['H_' dispname '.mat'];

%% Part 1: Prompt to Load or Generate H
if exist(Hfile,'file')
    generateH = false;
    prompt = [Hfile ' exists. Load existing H? Y/N [Y]: '];
    resp = input(prompt,'s');
    if isempty(resp) || upper(resp)=='Y'
        load(Hfile,'H');
        fprintf('Loaded existing H matrix from %s\n', Hfile);
    else
        generateH = true;
    end
else
    generateH = true;
end


% Simulation settings
SimDays = 2;
SimTime = SimDays*24*3600;    % total simulation time in seconds
th      = 300;                % 5-min hydraulic step
tq      = 300;                % 5-min quality step
tstep   = 300;                % 5-min reporting step
d.setTimeSimulationDuration(SimTime);
d.setTimeHydraulicStep(th);
d.setTimeQualityStep(tq);
d.setTimeReportingStep(tstep);
d.setTimePatternStep(tstep);

Ts = SimTime / tq;


%% Narrow down the nodes
% Get all node names
NodeNames = d.getNodeNameID;

% Find nodes that belong to the DMA
DMA_Node_Logical = contains(NodeNames,'dist');
DMA_Node_Names   = NodeNames(DMA_Node_Logical);

% Convert node names to node indices
NJnodesInd = zeros(1,length(DMA_Node_Names));
for k = 1:length(DMA_Node_Names)
    NJnodesInd(k) = d.getNodeIndex(DMA_Node_Names{k});
end

NJnodes = length(NJnodesInd);


% 
% % Node counts and indices
% NJnodes     = d.getNodeJunctionCount;
% NJnodesInd  = double(d.getNodeJunctionIndex);

% Setup chlorine simulation
d.setQualityType('Chlorine','mg/L','');
bulk = d.getLinkBulkReactionCoeff;
bulk(:) = -1.5;
d.setLinkBulkReactionCoeff(bulk);
zeroQ = zeros(1, d.NodeCount);
d.setNodeInitialQuality(zeroQ);

wallReactionCoeff = d.getLinkWallReactionCoeff;
wallReactionCoeff(:) = 0;
d.setLinkWallReactionCoeff(wallReactionCoeff);

% Time vector length for quality
m = SimTime/tq + 1;

%% Generate Impulse-Response Matrix H (if requested)
if exist('generateH','var') && generateH
    fprintf('Generating impulse-response matrix H...\n');

    % Preallocate H (NJnodes × NJnodes)
    H = zeros(NJnodes, NJnodes);
    
    % Compute impulse responses
    d.getComputedTimeSeries; % pre-compute hydraulics
    for i = 1:NJnodes
        fprintf('Injection node %d of %d...\n', i, NJnodes);
        PAT = ones(1, m);
        PAT_multiplier = 10000;
%         srcIdx = double(i);
        srcIdx = NJnodesInd(i);   % <-- THIS is the real fix


        d.setNodeSourceType(srcIdx, 'MASS');
        patID = d.addPattern('CL2PAT', PAT);
        d.setNodeSourcePatternIndex(srcIdx, patID);
        d.setNodeSourceQuality(srcIdx, PAT_multiplier);

        Q = d.getComputedQualityTimeSeries.NodeQuality;
        H(i, :) = min(Q(round(Ts/2):end, NJnodesInd));

        d.deletePattern(patID);
        d.setNodeSourceType(srcIdx, 'CONCEN');
        d.setNodeInitialQuality(zeroQ);
    end

    % Save and visualize H
    save(Hfile,'H');
    figure;
    [X,Y] = meshgrid(1:NJnodes, 1:NJnodes);
    surf(X,Y,H);
    xlim([0, NJnodes]); ylim([0, NJnodes]); zlim([0.001,1]);
    view([0,-90]);
    xlabel('Output node'); ylabel('Injection node');
    title(['Impulse Response Matrix H for ' dispname]); colorbar;
end

%% Part 2: Weighted row-selection optimization
%-------------------------------------------------------------------------------
[n, ~] = size(H);

% Setpoint r_set (scalar)
r_set = 0.5;
% 
% % Compute weights W based on base demands
% demands = d.getNodeBaseDemands{1};
% demands(d.getNodeReservoirIndex) = [];
% demands(d.getNodeReservoirIndex) = [];
% % demands(d.getNodeTankIndex) = max(demands);
% 
% W = demands' / max(demands);


% Base demands (all nodes)
demands_all = d.getNodeBaseDemands{1};

% Keep only DMA nodes
demands_DMA = demands_all(NJnodesInd);

% Normalize
W = demands_DMA(:) / max(demands_DMA);


% nodeIDs = d.getNodeJunctionNameID();
allNodeNames = d.getNodeNameID;
nodeIDs = allNodeNames(NJnodesInd);

linkIDs = d.getLinkNameID();

% Build static Gurobi model
Nvar = 3*n;           % [x(1:n); a(1:n); e(1:n)]  % Desision Variables
ncon = 1 + n + 2*n;
%model.obj   =[zeros(2*n,1); W]; % [zeros(n,1); ones(n,1); W]; %
alpha = 10;  % weight for slack
model.obj = [zeros(n,1); ones(n,1); alpha * W];  % demand based weighted error 

model.vtype = [repmat('B',n,1); repmat('C',2*n,1)];
model.lb    = zeros(Nvar,1);
model.ub    = [ones(2*n,1); Inf(n,1)];



% params.ObjNumber = 0;  % optional, for multi-objective solving

% % -------------------------------------------------------------------------
% %  MULTI-OBJECTIVE DEFINITION (lexicographic)
% % -------------------------------------------------------------------------
% Objective 1  – weighted slack  (priority 2)
model.MultiObj(1).Obj      = [zeros(2*n,1); W];
model.MultiObj(1).Priority = 1;       % higher priority
model.MultiObj(1).Weight   = 1;       % can stay 1 (scaling only)
% Objective 2  – total dose      (priority 1)
% model.MultiObj(2).Obj      = [zeros(n,1); ones(n,1); zeros(n,1)];
% model.MultiObj(2).Priority = 2;       % lower priority
% model.MultiObj(2).Weight   = 1;
% % -------------------------------------------------------------------------

% Assemble constraints
Ai = []; Aj = []; Av = [];
sense = repmat('<', ncon, 1);
rhs   = zeros(ncon,1);
row   = 1;

% 1) sum_i x_i = m (update rhs in loop)
Ai = [Ai; repmat(row, n, 1)];
Aj = [Aj; (1:n)'];
Av = [Av; ones(n,1)];
sense(row) = '=';
row = row + 1;

% 2) a_i - x_i <= 0
for i = 1:n
    Ai    = [Ai; repmat(row,2,1)];
    Aj    = [Aj; n+i; i];
    Av    = [Av; 1; -1];
    rhs(row) = 0; sense(row) = '<';
    row = row + 1;
end

% 3) column-error constraints
for j = 1:n
    % a) sum H(:,j).*a - e_j <= r_set
    Ai    = [Ai; repmat(row,n,1); row];
    Aj    = [Aj; (n+1:2*n)'; 2*n+j];
    Av    = [Av; H(:,j); -1];
    rhs(row) = r_set; sense(row) = '<'; row = row + 1;
    % b) -sum H(:,j).*a - e_j <= -r_set
    Ai    = [Ai; repmat(row,n,1); row];
    Aj    = [Aj; (n+1:2*n)'; 2*n+j];
    Av    = [Av; -H(:,j); -1];
    rhs(row) = -r_set; sense(row) = '<'; row = row + 1;
end

% Finalize model
model.A     = sparse(Ai, Aj, Av, ncon, Nvar);
model.rhs   = rhs;
model.sense = sense;



%% Optimize over m = 1 to max_m
max_m = 3;%5;
injection_cost = nan(max_m,1);
weighted_error = nan(max_m,1);
sel_nodes      = cell(max_m,1);
sel_a = cell(max_m,1);

% d.getComputedTimeSeries; % pre-compute hydraulics
NodeQuality  = d.getComputedQualityTimeSeries;

for m = 1:max_m
    mdl = model;
    mdl.rhs(1) = m;
    params.OutputFlag = 0;
    result = gurobi(mdl, params);
    if ~strcmp(result.status,'OPTIMAL')
        error('Gurobi failed for m=%d: %s', m, result.status);
    end

    chlorine_sum = 0;

    x_sol = result.x(1:n) > 0.5;
    a_sol = result.x(n+1:2*n);
    sel_a{m} = a_sol(a_sol > 0);
    e_sol = result.x(2*n+1:end);

    injection_cost(m) = sum(a_sol)*10000;
    
    disp(sel_a{m})
    weighted_error(m) = W' * e_sol;
    sel_nodes{m}      = nodeIDs(x_sol);
    fprintf('Selected nodes for m=%d: %s', m, strjoin(sel_nodes{m}, ', '));disp(' ')
end

%% Plot trade-offs with Pareto front
figure;
% scatter all solutions
scatter(injection_cost, weighted_error, 'o', 'filled'); hold on;
% annotate each point with its m value
for k = 1:max_m
    text(injection_cost(k), weighted_error(k), sprintf('%d', k), ...
         'VerticalAlignment','bottom', 'HorizontalAlignment','right');
end
% Identify Pareto-optimal solutions (non-dominated)
isPareto = true(max_m,1);
for i = 1:max_m
    for j = 1:max_m
        if (injection_cost(j) <= injection_cost(i) && weighted_error(j) <= weighted_error(i) && ...
            (injection_cost(j) < injection_cost(i) || weighted_error(j) < weighted_error(i)))
            isPareto(i) = false;
            break;
        end
    end
end
% plot Pareto front
plot(injection_cost(isPareto), weighted_error(isPareto), '-r', 'LineWidth', 1.5);
plot(injection_cost(isPareto), weighted_error(isPareto), 'sr', 'MarkerFaceColor','r');
xlabel('Injection Cost'); ylabel('Weighted tracking error');
legend('All solutions','Pareto front','Location','best');
title('Trade-offs across configurations with Pareto front'); grid on;

%% Plot each configuration separately for m=1:max_m
for m = 1:max_m
% Display selected node IDs for this configuration
    fprintf('Selected nodes for m=%d: %s', m, strjoin(sel_nodes{m}, ', '));disp(' ')
    d.plot('nodes','yes', ...
           'highlightnode', sel_nodes{m}, ...
           'fontsize',9);
    title(sprintf('m = %d | Cost = %.2f | W^T e = %.2e', ...
          m, injection_cost(m), weighted_error(m)));
end
%%
Results_file = ['Results_' dispname '.mat'];
save(Results_file,'H');

d.unload

elapsedTime = toc;
fprintf('Elapsed time: %.3f seconds\n', elapsedTime);
