# Smart Water Network Optimization & Chlorine Control using EPANET + Gurobi

## Overview
This repository contains simulation and optimization frameworks for smart water distribution networks using EPANET-MATLAB Toolkit. The project focuses on chlorine transport modeling, impulse-response system identification, and optimal booster station control using mixed-integer and quadratic optimization.

The system is designed to:
- Simulate water quality dynamics (chlorine decay and transport)
- Build impulse-response matrices for network sensitivity
- Optimize booster injection strategies
- Maintain chlorine concentration within safe operational bounds
- Minimize injection cost and violation risk

Main Codes: 
- CY_DBP_v1_booste_scheduling.m
- CY_DBP_v1_booster_placement_code.m

---

## Project Structure


---

## Key Components

### 1. Hydraulic & Quality Simulation (EPANET)
The EPANET-MATLAB toolkit is used to simulate:
- Chlorine decay in pipes
- Bulk and wall reaction effects
- Time-varying demand conditions
- Multi-node sensor monitoring

---

### 2. Impulse-Response Matrix Construction
A system identification approach is used where each booster injection node is excited individually:

- Output: Matrix **H**
- Dimensions: (time steps × sensors × boosters)
- Captures chlorine propagation dynamics across the network

This matrix acts as a linear surrogate model of the system.

---

### 3. Optimization Model (Gurobi)
The control problem is formulated as a constrained quadratic optimization:

- Decision variables: booster injection schedules
- Objective:
  - Minimize deviation from target chlorine levels
  - Penalize excessive injection cost
  - Penalize temporal variation (smooth control)
- Constraints:
  - Chlorine bounds (soft constraints with slack variables)
  - Physical feasibility of injection rates

---

### 4. Pareto Analysis (Multi-Booster Selection)
A secondary model evaluates:
- Trade-off between injection cost
- Water quality tracking error

This generates a Pareto front to identify optimal operating configurations.

---


Optional datasets:
- Club / league ranking data (if used in extended modeling)
- Sensor node metadata

---

## Outputs

- Optimal booster injection schedules
- Chlorine concentration time series at sensor nodes
- Impulse-response matrix H
- Pareto-optimal control configurations
- Performance metrics:
  - Out-of-bounds percentage
  - Chlorine dosage cost
  - Volume violation metrics

---

## Requirements

- MATLAB R2021+
- EPANET-MATLAB Toolkit
- Gurobi Optimizer
- Parallel Computing Toolbox (recommended)

---

## Key Features

- Hybrid physics + optimization modeling
- Data-driven surrogate modeling via impulse responses
- Large-scale constrained optimization
- Multi-objective decision analysis
- Real-world water network applicability

---

## Notes

- The system assumes linear superposition of chlorine propagation via impulse-response approximation.
- Numerical stability depends on EPANET timestep configuration.
- Solver performance improves significantly with sparse network structure exploitation.

---

## Author

Alexandros Papadopoulos  
Research focus: Applied Mathematics, Optimization, Water Systems Modeling
## Inputs

Required EPANET input file:
