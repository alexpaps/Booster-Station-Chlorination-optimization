%% Initialization
try
    d.unload;
catch
end
fclose('all');
clear all; clear class; clc; close all;clear all;
load_paths;  % EPANET-MATLAB toolkit


tic

%% Network input
inpFile = 'CY-DBP_v1.inp';
%inpFile = 'new_Zone_1_Final.inp';

d = epanet(inpFile);


%% Simulation settings (78 hours at 5-min steps)
hours = 72;
SimTime      = hours * 3600;
stepHyd      = 300;%1800
stepQual     = 300;
stepReport   = 300;%1800

% 
% % Set desired times in correct order
d.setTimeSimulationDuration(SimTime);
d.setTimeHydraulicStep(stepHyd);
d.setTimeQualityStep(stepQual);
d.setTimePatternStep(stepReport);
d.setTimeReportingStep(stepReport);

d.setTimeSimulationDuration(SimTime);
d.setTimeHydraulicStep(stepHyd);
d.setTimeQualityStep(stepQual);
d.setTimePatternStep(stepReport);
d.setTimeReportingStep(stepReport);


% check
if ~all([d.getTimeSimulationDuration == SimTime,...
d.getTimeHydraulicStep == stepHyd,...
d.getTimeQualityStep == stepQual,...
d.getTimePatternStep == stepReport,...
d.getTimeReportingStep == stepReport])
error('Wrong simulation settings!')
end

Ts = SimTime / stepQual;        % total quality steps

% Node and reaction setup
NJnodes   = d.getNodeJunctionCount;
NJindices = double(d.getNodeJunctionIndex);

d.setQualityType('Chlorine','mg/L','');
bulkGlobal = -1.5;      %-3.5
bulkCoeff = repmat(bulkGlobal, 1, d.LinkCount);
d.setLinkBulkReactionCoeff(bulkCoeff);
%d.setNodeInitialQuality(zeros(1, d.NodeCount));


wallReactionCoeff = d.getLinkWallReactionCoeff;
wallReactCoef = -0.5;   %-1.5
wallReactionCoeff(:) = wallReactCoef;
d.setLinkWallReactionCoeff(wallReactionCoeff);

d.setLinkBulkReactionCoeff(bulkCoeff);
d.setLinkWallReactionCoeff(wallReactionCoeff);
% Booster stations and sensors
BaseDemands    = d.getNodeBaseDemands{1};
NodeNames      = d.getNodeNameID;
BoosterNodeIDs = {'dist458', 'dist1268', 'dist1443' };%{'dist458', 'dist989', 'dist1126', 'dist1268', 'dist1936' };%{'149', '236', '358', '391', '524'};
BoosterIndices = d.getNodeIndex(BoosterNodeIDs);
numBoosters = numel(BoosterNodeIDs);

% SensorIndices  = find(BaseDemands>0);
% SensorNodeIDs  = NodeNames(SensorIndices);
% numSensorNodes = length(SensorNodeIDs);
% 


% Sensors = DMA nodes only
SensorIndices = find(contains(NodeNames,'dist'));
SensorNodeIDs  = NodeNames(SensorIndices);
numSensorNodes = numel(SensorIndices);

% Simulation Variables
patternNum = 10000;

% Optimization variables
Ub      = 0.5;%0.6
Lb      = 0.1;%0.3
ref_val = 0.3;        % Do no use it (ref_val = 0)

% Penalty weights
lambda = 1e5;   % bounds penalty
gamma  = 1e6;%1e3;   % variation penalty on x(k)-x(k-1)   % 1e26
mu = 10; % penalty on the sum of total injected chlorine


% save file with 
tmpInpFile  = ['sim_',inpFile];
d.saveInputFile(tmpInpFile)
d.unload();
d=epanet(tmpInpFile);
% 
% % Now reset again — it should stick this time
% d.setTimeHydraulicStep(stepHyd);
% d.setTimeQualityStep(stepQual);

tmpInpFile  = ['sim_',inpFile];
d.saveInputFile(tmpInpFile)
d.unload();
d=epanet(tmpInpFile);


d.setLinkBulkReactionCoeff(bulkCoeff);
d.setLinkWallReactionCoeff(wallReactionCoeff);

% check
if ~all([d.getTimeSimulationDuration == SimTime,...
d.getTimeHydraulicStep == stepHyd,...
d.getTimeQualityStep == stepQual,...
d.getTimePatternStep == stepReport,...
d.getTimeReportingStep == stepReport])
error('Wrong simulation settings!')
end

%% H file

[~, baseName, ~] = fileparts(inpFile);

% Booster info
boosterTag = strjoin(BoosterNodeIDs, '_');

% Reaction coefficients (you already set these globally)
bulkStr = strrep(num2str(bulkGlobal, '%.1f'), '.', 'p');   % e.g., -3.5 -> -3p5
wallStr = strrep(num2str(wallReactCoef, '%.1f'), '.', 'p');         % hardcoded for now


% Build Hfile name
Hfile = sprintf('H_%s_%dh_%dc_%dr_%ds_Bulk_%s_Wall_%s_Boosters_%s.mat', ...
    baseName, hours, stepHyd,stepQual,stepReport, bulkStr, wallStr, boosterTag);
disp(Hfile)
%% Part 1: Load or generate impulse-response matrix H
if isfile(Hfile)
    resp = input(sprintf('%s exists. Load it? Y/N [Y]: ', Hfile),'s');
    if isempty(resp) || upper(resp)=='Y'
        load(Hfile,'H');
        fprintf('Loaded H from %s\n', Hfile);
    else
        generateH = true;
    end
else
    generateH = true;
end

% 
% if exist('generateH','var') && generateH
%     fprintf('Generating impulse-response matrix H (%d×%d×%d)...\n', Ts, numSensorNodes, numBoosters);
%     Htemp = cell(Ts, numBoosters);  % use temp variable for parfor assignment 
% 
%     inpFile = ['sim_',baseName];
%     baseInp = which([inpFile, '.inp']);
%     if isempty(baseInp)
%         error('Network input file "%s.inp" not found in MATLAB path.', inpFile);
%     end
% 
%     parfor b = 1:numBoosters
%         % --- Each worker gets its own model copy ---
%         d = epanet(baseInp);
%         idxB = BoosterIndices(b);
%         localH = cell(Ts, 1);
% 
%         for t = 1:Ts
%             patternID = sprintf('p_%d', t);
%             patVec = zeros(1, Ts);
%             patVec(t) = patternNum;
% 
%        
% 
%             % Configure model
%             d.addPattern(patternID, patVec);
%             d.setNodeInitialQuality(zeros(1, d.NodeCount));
%             d.setNodeSourceType(idxB, 'MASS');
%             d.setNodeSourceQuality(idxB, 1.0);
%             d.setNodeSourcePatternIndex(idxB, d.getPatternIndex(patternID));
% 
%             % Run simulation and collect data
%             qualAll = d.getComputedQualityTimeSeries.NodeQuality(2:end, SensorIndices);
%             localH{t} = qualAll;
% 
%             % Reset for next t
%             d.setNodeSourceQuality(idxB, 0);
%             d.deletePattern(patternID);
%         end
% 
%         d.unload();  % cleanup
%         % Save results into temp matrix
%         for t = 1:Ts
%             Htemp{t, b} = localH{t};
%         end
%     end
% 
%     H = Htemp;  % assign final matrix
%     %save(Hfile, 'H');
%     save(Hfile, 'H', '-v7.3');
% 
%     fprintf('Saved H to %s\n', Hfile);
% end
if exist('generateH','var') && generateH
    fprintf('Generating impulse-response matrix H (%d×%d×%d)...\n', Ts, numSensorNodes, numBoosters);

    Htemp = cell(Ts, numBoosters);   % final storage

    inpFile = ['sim_', baseName];
    baseInp = which([inpFile, '.inp']);
    if isempty(baseInp)
        error('Network input file "%s.inp" not found in MATLAB path.', inpFile);
    end

    parfor b = 1:numBoosters
        % --- One EPANET model per worker ---
        dloc = epanet(baseInp);
        idxB = BoosterIndices(b);

        % Reset once per booster (NOT per impulse)
        dloc.setNodeInitialQuality(zeros(1, dloc.NodeCount));

        % Create ONE reusable impulse pattern
        patternID = 'impulse';
        patIdx = dloc.addPattern(patternID, zeros(1, Ts));

        % Local numeric storage (faster than cell juggling)
        localH = zeros(Ts, numSensorNodes, Ts);

        % Configure booster once
        dloc.setNodeSourceType(idxB, 'MASS');
        dloc.setNodeSourceQuality(idxB, 1.0);
        dloc.setNodeSourcePatternIndex(idxB, patIdx);

        for t = 1:Ts
            % Overwrite pattern values (no add/delete)
            patVec = zeros(1, Ts);
            patVec(t) = patternNum;
            dloc.setPattern(patIdx, patVec);

            % Run quality simulation
            Q = dloc.getComputedQualityTimeSeries.NodeQuality;
            localH(:,:,t) = Q(2:end, SensorIndices);
        end

        % Cleanup
        dloc.deletePattern(patternID);
        dloc.unload();

        % Store results in cell structure (original format)
        for t = 1:Ts
            Htemp{t,b} = localH(:,:,t);
        end
    end

    H = Htemp;
    save(Hfile, 'H', '-v7.3');
    fprintf('Saved H to %s\n', Hfile);
end



%% Define selected booster nodes
SelectedBoosterIDs = {'dist458', 'dist1268', 'dist1443' }; %{'391','236','524'};

% Get their indices in the original BoosterNodeIDs
[~, selectedIndices] = ismember(SelectedBoosterIDs, BoosterNodeIDs);

% Check for any missing nodes
if any(selectedIndices == 0)
    error('One or more selected boosters not found in BoosterNodeIDs.');
end

% Subset H
H = H(:, selectedIndices);  % Same time steps (rows), only selected boosters (columns)
BoosterIndices = d.getNodeIndex(SelectedBoosterIDs);
numBoosters = numel(SelectedBoosterIDs);


%% Part 2: Optimization with soft bounds & variation penalty
params.outputflag = 0;


% Dimensions
TotalX  = Ts * numBoosters;          % decision variables
Total = Ts * numSensorNodes;
num_slack = 2 * Total;      % slack for both lower and upper bounds

% Build D so vec(Y) = D*x
D = zeros(Total, TotalX);
for b = 1:numBoosters
    for t = 1:Ts
        col = (b-1)*Ts + t;
        D(:, col) = reshape(H{t,b}, [], 1);
    end
end

% Bounds & reference
Ub_vec  = Ub * ones(Total, 1);
Lb_vec  = Lb * ones(Total, 1);
ref     = ref_val * ones(Total,1);

% Slack indices
idx_slack_lb = TotalX + (1:(Total));
idx_slack_ub = TotalX + (Total + 1 : 2*Total);

% Gurobi model setup
model.vtype = repmat('C', TotalX + num_slack, 1);
model.lb    = zeros(TotalX + num_slack, 1);
model.ub    = [ ones(TotalX, 1) * 1e4; inf(num_slack, 1) ];

% Constraints with slack:
% Upper bound soft: D*x ≤ Ub + s_ub
A1 = [ D, sparse(Total, Total), speye(Total) ];
rhs1 = Ub_vec;
sense1 = repmat('<', Total, 1);

% Lower bound soft: -D*x - s_lb ≤ -Lb
A2 = [-D, -speye(Total), sparse(Total, Total)];
rhs2 = -Lb_vec;
sense2 = repmat('<', Total, 1);

% Combine constraints
model.A     = sparse([A1; A2]);
model.rhs   = [rhs1; rhs2];
model.sense = [sense1; sense2];

% Quadratic objective: ||D*x - ref||^2 + λ·(sum s_lb + sum s_ub) + γ·Σ(x_t - x_{t-1})^2 
Qxx = D' * D;
Qxx = Qxx + mu * speye(TotalX);

% Add variation penalty to Qxx
for b = 1:numBoosters
    for t = 2:Ts
        idx      = (b-1)*Ts + t;
        prev_idx = idx - 1;
        Qxx(idx,idx)            = Qxx(idx,idx)           + gamma;
        Qxx(prev_idx,prev_idx)  = Qxx(prev_idx,prev_idx) + gamma;
        Qxx(idx,prev_idx)       = Qxx(idx,prev_idx)      - gamma;
        Qxx(prev_idx,idx)       = Qxx(prev_idx,idx)      - gamma;
    end
end

% Combine Q matrix
Z = sparse(TotalX, num_slack);
model.Q = sparse([ Qxx,  Z;
                   Z',  sparse(num_slack, num_slack) ]);

% Linear term of objective
c_base  = [-2 * D' * ref;           zeros(num_slack, 1)];
c_slack = [zeros(TotalX,1);     lambda*ones(num_slack, 1)];

% replace your obj with the extra sum(x) term
% c_sum = [ mu * ones(TotalX,1);
%           zeros(num_slack,1) ];
% model.obj = c_base + c_slack + c_sum;

model.obj = c_base + c_slack;
model.modelsense = 'min';

% Solve
params.outputflag = 1;
result = gurobi(model, params);
if ~isfield(result,'x')
    error('Solver failed: %s', result.status);
end

% Unpack solution
full_x = result.x;
x_opt  = full_x(1 : TotalX);
s_lb   = full_x(idx_slack_lb);
s_ub   = full_x(idx_slack_ub);

% u_opt  = reshape(x_opt, Ts, numBoosters);
% 
% u_opt = round(ones(Ts,1)*mean(u_opt)*1000)/1000;
% x_opt = u_opt;

Y_vec  = D * x_opt;
Y      = reshape(Y_vec, Ts, numSensorNodes);
disp(size(Y))

u_opt  = reshape(x_opt, Ts, numBoosters);

  
% %% Current Settings Part
% d.solveCompleteHydraulics;
% d.solveCompleteQuality;
% 
% % 3) Extract quality time series at sensor nodes
% tsData       = d.getComputedQualityTimeSeries;
% qualOverTime = tsData.NodeQuality(2:end, SensorIndices);   % Ts×#sensors
% Y = tsData.NodeQuality(2:end,SensorIndices);
% x_opt = 1000*ones(numBoosters*Ts,1);

%% Initialize new variables

% Time step indices for 24 to 48 hours
startStep = 24*3600/stepQual;%24
endStep   = 48*3600/stepQual;%48
rcData = Y(startStep:endStep,:);
avgRC = mean(rcData,1);
time_h = (0:Ts-1) * (stepQual/3600);

% Corresponding time vector (in hours)
time_h_sub = time_h(startStep:endStep);

DemandMatrix = d.getComputedAnalysisTimeSeries.Demand(2:end, SensorIndices);
%DemandMatrix = repelem(DemandMatrix,6,1);
%% Calculate the Sum of Chlorine (mg)
% Count only the inside 24 Hours (24 - 48) 
chlorine_sum = 0;

for b = 1:numBoosters
    idx = (b-1)*Ts + (startStep:endStep);  % περιορισμός σε startRow:endRow
    chlorine_sum = chlorine_sum + sum(x_opt(idx)*patternNum); % mg / min
    % time_step 
end
chlorine_sum = chlorine_sum * stepQual / 60;
%chlorine_sum = sum(x_opt) * patternNum;

fprintf('Chlorine Concentration Used : %d ', chlorine_sum);disp(' ')

%% Out of bounds metric only the inside 48 Hours (24 - 72)  (Do it for Optimal and Constant)

percOutOfBounds = PercentageOutOfBounds(Lb, Ub, rcData);

fprintf('Percentage out of bounds : %d ', percOutOfBounds);disp(' ')
fprintf('Percentage out of bounds : %d ', PercentageOutOfBounds(Lb-0.1, Ub+0.1, rcData));disp(' ')

volumeOutOfBounds = VolumeOutOfBounds(Lb, Ub, rcData , DemandMatrix(startStep:endStep,:), stepHyd/3600);
fprintf('Percentage of Volume out of bounds : %d ', volumeOutOfBounds);disp(' ')

RelaxedVolumeOutOfBounds = VolumeOutOfBounds(Lb-0.1, Ub+0.1, rcData , DemandMatrix(startStep:endStep,:), stepHyd/3600);
fprintf('Relaxed Percentage of Volume out of bounds : %d ', RelaxedVolumeOutOfBounds);disp(' ')

relaxedPercOutOfBounds = RelaxedOutOfBoundsScore(Lb, Ub, rcData);
fprintf('Relaxed Percentage out of bounds : %d ', relaxedPercOutOfBounds);disp(' ')

%% Plot results

% Injection per Booster Station
figure; hold on;
cols = lines(numBoosters);

for b = 1:numBoosters
    % Compute indices safely
    idx = (b-1)*Ts + (startStep:endStep);

    % Make sure idx is within bounds of x_opt
    idx = idx(idx <= length(x_opt));

    % Extract booster schedule
    boosterSchedule = x_opt(idx) * patternNum;



    % ===============================
    % Write PAT file for this booster
    % ===============================
    boosterID = BoosterNodeIDs{b};
    patFile   = sprintf('%s.pat', boosterID);

    fid = fopen(patFile, 'w');
    if fid == -1
        error('Cannot open file %s for writing.', patFile);
    end

    fprintf(fid, '; Pattern for booster %s\n', boosterID);
    fprintf(fid, '%.6f\n', boosterSchedule);   % one value per line

    fclose(fid);

    

    % Plot only if dimensions match
    if length(time_h_sub) == length(boosterSchedule)
        plot(time_h_sub, boosterSchedule, ...
             'LineWidth', 2, 'Color', cols(b,:));
    else
        warning('Length mismatch for booster %d: time_h_sub=%d, data=%d', ...
                 b, length(time_h_sub), length(boosterSchedule));
    end
end

xlabel('Time (h)');
ylabel('Dosage (mg)');

% Let MATLAB auto-adjust axes first
axis tight
% ylim([0 6000]);
% If you really want a fixed ylim, check your data range first:
% ylim([5000 6000]);   % <-- uncomment if appropriate

title('Optimal Booster Injection Schedule (subset)');
legend(string(SelectedBoosterIDs), 'Location', 'best');
grid on;


% % Injection per Booster Station
% figure; hold on;
% cols = lines(numBoosters);
% for b = 1:numBoosters
%     idx = (b-1)*Ts + (startStep:endStep);  % περιορισμός σε startRow:endRow
%     plot(time_h_sub, x_opt(idx)*patternNum, 'LineWidth',2, 'Color',cols(b,:));
% end
% xlabel('Time (h)'); ylabel('Dosage (mg)');
% %xlim([24 48]);
% 
% axis tight
% ylim([5000 6000]);
% title('Optimal Booster Injection Schedule (subset)');
% legend(SelectedBoosterIDs, 'Location','best'); grid on;


% Sensor Node Chlorine Residual
figure; hold on;
for i = 1:numel(SensorIndices)
    plot(time_h_sub, rcData(:,i), 'DisplayName', SensorNodeIDs{i});
end
xlabel('Time (h)'); ylabel('Residual Cl_2 (mg/L)');
%xlim([24 48]);

axis tight
% ylim([0 0.6]);

title('Residual Chlorine at Sensor Nodes (subset)');
legend('Location','northeastoutside','Orientation','vertical'); grid on;


% Average residuals bar chart
figure;
bar(categorical(SensorNodeIDs), avgRC);
xlabel('Sensor Node'); ylabel('Avg Residual Cl_2 (mg/L)');
title('Average Residual Chlorine over 24 h');
grid on; box on;

elapsedTime = toc;
fprintf('Elapsed time: %.3f seconds\n', elapsedTime);
%% End of m-file