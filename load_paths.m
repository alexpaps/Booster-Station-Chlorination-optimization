function load_paths()
%Load neccesary paths

%------------- BEGIN CODE --------------
addpath(genpath(pwd));

addpath('C:\Users\apapad06\Desktop\gurobi1201\win64\matlab');
setenv('PATH', [getenv('PATH') ';C:\Users\apapad06\Desktop\gurobi1201\win64\bin']);
addpath('C:\Users\apapad06\Desktop\gurobi1201\win64\matlab');
setenv('PATH', [getenv('PATH') ';C:\Users\apapad06\Desktop\gurobi1201\win64\bin']);


if strcmp(computer('arch'),'win64')
    rmpath(fileparts(which('gurobi.mexw32')))
else
    rmpath(fileparts(which('gurobi.mexw64')))
end
run 'gurobi_setup.m'
disp('Toolkits Loaded.');    
%------------- END OF CODE --------------


%C:\Users\alexp\OneDrive\Desktop\Optimal Booster Stelios\gurobi_matlab\64-bit

