function [count] = PercentageOutOfBounds(lb, ub, Matrix)
% 
% 

%NodeQuality  = d.getComputedQualityTimeSeries;

% startRow = 24 * 3600 / tq;
% endRow   = Ts - 6 * 3600 / tq;
%whole_time = 24 * 3600 / tq;

% Extract the submatrix
%subMatrix = Y2(:, :);

% Count values < min_value or > max_value
count = sum((Matrix(:) < lb) | (Matrix(:) > ub));

[Ts, NumberOfSensorNodes] = size(Matrix);

count = 100 * count / (NumberOfSensorNodes * Ts);
