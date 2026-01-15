%% ================= Heat Exchanger Network (HEN) Analysis =================
clc; clear; close all;

%% Step 1: Define Streams
% ID, Type (H=Hot, C=Cold), T_in, T_out, Cp
streams = table({'S1';'S2';'S3';'S4'}, ...
                {'H';'H';'C';'C'}, ...
                [180;150;40;60], ...  % T_in (°C)
                [80;60;120;140], ...  % T_out (°C)
                [2.0;1.5;2.5;2.0], ... % Cp (kW/°C)
                'VariableNames', {'ID','Type','T_in','T_out','Cp'});

%% Step 2: Minimum Temperature Difference
DeltaT_min = 10;  % °C

%% Step 3: Shift Temperatures for ΔTmin/2
streams.T_shift_in  = streams.T_in;
streams.T_shift_out = streams.T_out;

for i = 1:height(streams)
    if streams.Type{i}=='H'
        streams.T_shift_in(i)  = streams.T_in(i) - DeltaT_min/2;
        streams.T_shift_out(i) = streams.T_out(i) - DeltaT_min/2;
    else
        streams.T_shift_in(i)  = streams.T_in(i) + DeltaT_min/2;
        streams.T_shift_out(i) = streams.T_out(i) + DeltaT_min/2;
    end
end

%% Step 4: Calculate Heat Loads
streams.Q = streams.Cp .* abs(streams.T_out - streams.T_in);

%% Step 5: Separate Hot & Cold Streams
hot  = streams(strcmp(streams.Type,'H'),:);
cold = streams(strcmp(streams.Type,'C'),:);

%% Step 6: Composite Curves
% Hot Streams
Q_hot_curve = 0; T_hot_curve = hot.T_shift_in(1);
Q_cum = 0;
for i = 1:height(hot)
    dQ = hot.Cp(i) * abs(hot.T_shift_out(i)-hot.T_shift_in(i));
    Q_hot_curve = [Q_hot_curve; Q_cum; Q_cum + dQ];
    T_hot_curve = [T_hot_curve; hot.T_shift_in(i); hot.T_shift_in(i)];
    Q_cum = Q_cum + dQ;
    Q_hot_curve = [Q_hot_curve; Q_cum];
    T_hot_curve = [T_hot_curve; hot.T_shift_out(i)];
end

% Cold Streams
Q_cold_curve = 0; T_cold_curve = cold.T_shift_in(1);
Q_cum = 0;
for i = 1:height(cold)
    dQ = cold.Cp(i) * abs(cold.T_shift_out(i)-cold.T_shift_in(i));
    Q_cold_curve = [Q_cold_curve; Q_cum; Q_cum + dQ];
    T_cold_curve = [T_cold_curve; cold.T_shift_in(i); cold.T_shift_in(i)];
    Q_cum = Q_cum + dQ;
    Q_cold_curve = [Q_cold_curve; Q_cum];
    T_cold_curve = [T_cold_curve; cold.T_shift_out(i)];
end

%% Step 7: Plot Composite Curves
figure;
stairs(Q_hot_curve, T_hot_curve,'-r','LineWidth',2); hold on;
stairs(Q_cold_curve, T_cold_curve,'-b','LineWidth',2);
xlabel('Cumulative Heat (kW)'); ylabel('Temperature (°C)');
title('Hot and Cold Composite Curves (ΔTmin respected)');
grid on; legend('Hot Composite','Cold Composite');

%% Step 8: Pinch Analysis
Q_all = unique([Q_hot_curve; Q_cold_curve]);
DeltaT_all = zeros(length(Q_all),1);

for i = 1:length(Q_all)
    Q_i = Q_all(i);
    idx_hot = find(Q_hot_curve <= Q_i,1,'last');
    T_hot_i = T_hot_curve(idx_hot);
    idx_cold = find(Q_cold_curve >= Q_i,1,'first');
    T_cold_i = T_cold_curve(idx_cold);
    DeltaT_all(i) = T_hot_i - T_cold_i;
end

[minDeltaT, idx] = min(DeltaT_all);
Q_pinch = Q_all(idx);
T_pinch = (T_hot_curve(find(Q_hot_curve<=Q_pinch,1,'last')) + ...
           T_cold_curve(find(Q_cold_curve>=Q_pinch,1,'first')))/2;

fprintf('\nPinch Temperature = %.2f °C\n', T_pinch);
fprintf('Heat at Pinch = %.2f kW\n', Q_pinch);
fprintf('Minimum Temperature Difference = %.2f °C\n', minDeltaT);

%% Step 9: Utilities Required
Q_total_hot  = sum(hot.Q);
Q_total_cold = sum(cold.Q);
Q_recovered  = min(Q_total_hot,Q_total_cold);

Q_hot_utility  = max(0, Q_total_cold - Q_recovered);
Q_cold_utility = max(0, Q_total_hot - Q_recovered);

fprintf('Hot Utility Required = %.2f kW\n', Q_hot_utility);
fprintf('Cold Utility Required = %.2f kW\n', Q_cold_utility);

%% Step 10: Energy Saving
energy_saving = Q_recovered / max(Q_total_hot,Q_total_cold) * 100;
fprintf('Estimated Energy Saving = %.2f %%\n', energy_saving);

%% Step 11: Heat Matches Table
disp(' ');
disp('Hot Stream -> Cold Stream Heat Exchange (ΔTmin respected):');
disp('----------------------------------------------');

for i = 1:height(hot)
    for j = 1:height(cold)
        Q_match = min(hot.Q(i), cold.Q(j));
        fprintf('%s -> %s : %.2f kW\n', hot.ID{i}, cold.ID{j}, Q_match);
    end
end
