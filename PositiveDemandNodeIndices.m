function [positive_indices] = PositiveDemandNodeIndices(arr)
% Positive Demand Nodes Indices
% arr μπορεί να είναι cell ή numeric array

if iscell(arr)
    arr = cell2mat(arr);  % μετατροπή σε αριθμητικό πίνακα
end

positive_indices = find(arr > 0);


