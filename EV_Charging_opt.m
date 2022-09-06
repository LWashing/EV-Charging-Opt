clc
clear all
% 
%
%
%
% Setting up Elec Load Profiles (calling caiso excel docs)

%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 5, "Encoding", "UTF-8");

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["Var1", "Var2", "Var3", "avgDemandKwh", "Var5"];
opts.SelectedVariableNames = "avgDemandKwh";
opts.VariableTypes = ["string", "string", "string", "double", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["Var1", "Var2", "Var3", "Var5"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Var1", "Var2", "Var3", "Var5"], "EmptyFieldRule", "auto");

% Import the data
P = readtable("C:\Users\lamar\Desktop\MAE 199\CVX\examples\cvxbook\Ch04_cvx_opt_probs\DemandData-8-23-8-29--2021-eq.csv", opts);
P = table2array(P);

% Clear temporary variables
clear opts

% Data (variables?)
% P = ones(6,1)*100; (example demand/load to test optimization) % demand/load (placeholder for caiso data) <-- make this the same magnitude as EV energy
n = height(P); % number of hours

%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 5, "Encoding", "UTF-8");

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["Var1", "Var2", "Var3", "avg_load_rsrckwh", "Var5"];
opts.SelectedVariableNames = "avg_load_rsrckwh";
opts.VariableTypes = ["string", "string", "string", "double", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["Var1", "Var2", "Var3", "Var5"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Var1", "Var2", "Var3", "Var5"], "EmptyFieldRule", "auto");

% Import the data
ra = readtable("C:\Users\lamar\Desktop\MAE 199\CVX\examples\cvxbook\Ch04_cvx_opt_probs\SysLoadResource-8-23-8-29--2021.csv", opts);
ra = table2array(ra);

%% Clear temporary variables
clear opts
%ra= [80 90 120 150 120 80]';(used for example) % nodal resource allocation (from casio excel sheets)
% try to find household average hourly demand from a source like EIA.gov

Chmax= 100; % power rating/max charge/discharge [kW] <-- this could be a vector that takes into account when EVs are plugged in
%Chmin= 0; 
Smax = 200; % max state of energy [kWh]
Smin = 30; % min state of energy [kWh]
isoc= 100; % initial state of energy [Smin:Smax]
ev = 1; % # of vehicles
eff=.93; % charging/discharging rountrip efficency

% odmd = placeholder for caiso data
% t = iscoc*cr <--- time could be input by user (constraint) or chosen by optimizer
%tdmd = evdmd + odmd
L = diag(ones(n-1,1)); % add row/comums of 0s
L_2 = padarray(L,1,0,'pre');
L_3 = padarray(L_2,[0 1], "post");
M = zeros(n,1); 
M(1) = 1;
D = eff*diag(ones(n,1)); % 7 can be changed to length of n
I = eye(n);

%s=  %state of energy  
%n= chosen time for allocation (length of 4)
%Calling CVX
%%
cvx_begin
    variable x(n,1) %  charge/discharge (independent)
    variable s(n,1) %  State of energy (dependent on x)
    variable load_shed(n,1) % demand that must be curtailed
    
    minimize norm(x,2) + 10*norm(load_shed) % power balance achieved by minimizing resource adequacy - ev demand - other energy demand
        subject to
        x <= Chmax;   %max charge (power)
        x >= -Chmax;   %max discharge (power)
        s <= Smax; %State of energy constraints (uper/lower bound 0-max e rating of batttery)
        s >= Smin; % (lines 30-31 will be matrix eqns)
        % state of charg equailty constraint iscoc+eff*(x*t) (remember 1hr
        % intervals)
        x-ra+P-load_shed == 0; % total resouce allocation (supply) - other e demand
        [I-L_3 -D]*[s;x] == isoc*M; % EV battery state of energy equation
        load_shed >= -ra; %curtailment of generation
        load_shed <= P; % curtailment of load
        s(n) == Smax; % make sure it is charged at the end

cvx_end

%plot
figure;
subplot(2,1,1);
plot(x); M1 = "Charge/Discharge";
ylabel('kwh');
hold on
plot(s); M2 = "State of Energy";
legend([M1,M2])
subplot(2,1,2);
plot(P); M3 = "Demand";
hold on
plot(ra);M4 = "Rsc Allocation";
plot(load_shed); M5 = "Load Shed";
xlabel('Hours');
ylabel('kwh');
legend([M3,M4,M5]);
