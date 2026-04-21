function [score] = RelaxedOutOfBoundsScore(lb, ub, Matrix)
    % Norm-based out-of-bounds penalty score
    % Penalizes (value - bound)^2 for each out-of-bound entry

    below_idx = Matrix < lb;
    above_idx = Matrix > ub;

    % Penalties: squared distance from violated bounds
    penalty_below = (Matrix(below_idx) - lb).^2;
    penalty_above = (Matrix(above_idx) - ub).^2;

    % Total norm-2 penalty
    total_penalty = sum(penalty_below) + sum(penalty_above);

    % Normalize by number of elements and bound range (squared)
    [T, N] = size(Matrix);
    bound_range = ub - lb;
    
    % Maximum possible violation per item is (bound_range)^2
    % This gives a percentage-like interpretation
    max_penalty = T * N * (bound_range^2);

    score = 100 * total_penalty / max_penalty;
end
