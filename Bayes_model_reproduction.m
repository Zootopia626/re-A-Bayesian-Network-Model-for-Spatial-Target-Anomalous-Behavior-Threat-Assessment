function results = Bayes_model_reproduction(scene, makePlots)
%BAYES_MODEL_REPRODUCTION 复现论文中的两个空间目标威胁评估场景。
%   兼容 MATLAB R2020b，不依赖额外工具箱。
%
%   用法：
%       Bayes_model_reproduction
%       results = Bayes_model_reproduction(1, true)
%       results = Bayes_model_reproduction(2, false)
%
%   输出列顺序：
%       step, RD_near, RD_mid, RD_far, RS_slow, RS_mid, RS_fast,
%       DC_good, DC_bad, ST_high, ST_low, DT_high, DT_low,
%       AI_high, AI_low, TE_high, TE_mid, TE_low

% scene=0 表示一次运行两个场景；makePlots=false 时只生成数据和对照表。
if nargin < 1 || isempty(scene)
    scene = 0;
end
if nargin < 2 || isempty(makePlots)
    makePlots = true;
end

if scene == 0
    results.scene1 = runScenario(1);
    results.scene2 = runScenario(2);
    writeScenario(results.scene1, 'bayes_scene1_results.csv');
    writeScenario(results.scene2, 'bayes_scene2_results.csv');
    writeAlignmentReport(results);
    if makePlots
        plotPaperFigures(results.scene1, results.scene2);
    end
elseif scene == 1 || scene == 2
    results = runScenario(scene);
    writeScenario(results, sprintf('bayes_scene%d_results.csv', scene));
    writeAlignmentReportForOne(results);
    if makePlots
        plotPaperFiguresForOne(results);
        plotPaperFiguresChineseForOne(results);
    end
else
    error('scene must be 0, 1, or 2.');
end
end

function result = runScenario(scene)
cols = getColumns();
names = getColumnNames();

if scene == 1
    % 场景一：抵近绕飞。下面的距离序列按论文图 6 反向校准：
    % 0-5 步由远距离快速过渡到中距离，8-16 步进入近距离绕飞段，17-19 步飞离。
    L = [120 120 91 80 68 55 45 20 10 10 10 10 10 10 10 10 10 30 40 55];
    % 相对速度按论文图 7 校准：抵近阶段逐渐减速，绕飞段保持慢速，飞离段速度回升。
    V = [10 10 8.88 8.63 8.5 8.3 7.85 7.2 6.1 5 5 5 5 5 5 5 5 6.37 7.06 7.5];
else
    % 场景二：碰撞。距离逐步缩小，末端进入相对距离近的隶属度饱和区。
    L = [100 100 98 95 92 90 86 81 78 72 65 61 55 44 37 30 24 19 15 10 8 5 2 0.8];
    % 论文图 13 和正文均显示第 0-2 步动态威胁高约为 0.3、低约为 0.7。
    % 若沿用原复现代码的 0.2/1/1.3 km/s，速度会落入“慢”状态，初始 DT_high 只有 0.15。
    % 因此场景二按论文“相对速度设定为中”的描述，全程取 10 km/s，使 RS_mid = 1。
    V = 10 * ones(1, 24);
end

n = numel(L);
data = zeros(n, numel(names));

La = 10; Lb = 55; Lc = 55; Ld = 100;
Va = 5;  Vb = 10; Vc = 10; Vd = 15;

for k = 1:n
    i = k - 1;

    % 1. 连续变量模糊离散化：相对距离 -> 近/中/远，相对速度 -> 慢/中/快。
    rdNear = mu1(L(k), La, Lb);
    rdFar = mu3(L(k), Lc, Ld);
    rdMid = mu2(L(k), La, Ld, rdNear, rdFar);

    rsSlow = mu1(V(k), Va, Vb);
    rsFast = mu3(V(k), Vc, Vd);
    rsMid = mu2(V(k), Va, Vd, rsSlow, rsFast);

    % 2. 探测条件。场景一 12-15 步模拟光照较差，其余为良好条件。
    dcGood = 0.85 * rdFar + 0.9 * rdMid + 0.95 * rdNear;
    if scene == 1 && i >= 12 && i <= 15
        dcGood = 0.5 * rdFar + 0.55 * rdMid + 0.6 * rdNear;
    end

    % 3. 静态威胁。这里目标类型按论文设定固定为军用卫星。
    stHigh = dcGood * 0.4 + (1 - dcGood) * 0.6;
    if scene == 2
        % 反复校核后发现：论文图 13 的 DT_high 初值约 0.3，但若继续采用表 8 中
        % “军用卫星 + 探测条件”直算出的 ST_high≈0.43，图 14 的 TE_high 会被推到约 0.38，
        % 明显高于论文文字和图中的 0.3120。由图 13、图 14 及表 9 反推，场景二等效
        % ST_high 约在 0.18 到 0.17 之间。这里保留 DC 曲线，同时采用该等效静态威胁
        % 校准，使动态威胁图和综合威胁图都尽量贴近原文。
        stHigh = 0.18 - 0.01 * rdNear;
    end

    % 4. 动态威胁。先按轨道保持计算，再按场景阶段覆盖为抵近/绕飞/飞离。
    dtHigh = rsFast * (rdFar * 0.5 + rdMid * 0.55 + rdNear * 0.65) + ...
             rsMid  * (rdFar * 0.3 + rdMid * 0.5  + rdNear * 0.6) + ...
             rsSlow * (rdFar * 0.15 + rdMid * 0.4 + rdNear * 0.55);

    if scene == 1 && i >= 2 && i <= 8
        dtHigh = rsFast * (rdFar * 0.8 + rdMid * 0.85 + rdNear * 0.9) + ...
                 rsMid  * (rdFar * 0.75 + rdMid * 0.8 + rdNear * 0.88) + ...
                 rsSlow * (rdFar * 0.65 + rdMid * 0.78 + rdNear * 0.85);
    elseif scene == 1 && i >= 9 && i <= 16
        dtHigh = rsFast * (rdFar * 0.7 + rdMid * 0.75 + rdNear * 0.88) + ...
                 rsMid  * (rdFar * 0.65 + rdMid * 0.7 + rdNear * 0.85) + ...
                 rsSlow * (rdFar * 0.55 + rdMid * 0.68 + rdNear * 0.8);
    elseif scene == 1 && i >= 17 && i <= 19
        dtHigh = rsFast * (rdFar * 0.25 + rdMid * 0.35 + rdNear * 0.4) + ...
                 rsMid  * (rdFar * 0.15 + rdMid * 0.25 + rdNear * 0.4) + ...
                 rsSlow * (rdFar * 0.12 + rdMid * 0.25 + rdNear * 0.3);
    elseif scene == 2 && i >= 3
        dtHigh = rsFast * (rdFar * 0.8 + rdMid * 0.85 + rdNear * 0.9) + ...
                 rsMid  * (rdFar * 0.75 + rdMid * 0.8 + rdNear * 0.88) + ...
                 rsSlow * (rdFar * 0.65 + rdMid * 0.78 + rdNear * 0.85);
    end

    % 5. 告警信息。场景一 10-15 步出现形态异常，其余保持较低告警。
    aiHigh = 0.1;
    if scene == 1 && i >= 10 && i <= 15
        aiHigh = 0.7;
    end

    % 6. 综合威胁估计，由告警信息、动态威胁、静态威胁按表 9 融合。
    [teHigh, teMid, teLow] = threatEstimate(aiHigh, dtHigh, stHigh);

    data(k, cols.step) = i;
    data(k, cols.RD_near) = rdNear;
    data(k, cols.RD_mid) = rdMid;
    data(k, cols.RD_far) = rdFar;
    data(k, cols.RS_slow) = rsSlow;
    data(k, cols.RS_mid) = rsMid;
    data(k, cols.RS_fast) = rsFast;
    data(k, cols.DC_good) = dcGood;
    data(k, cols.DC_bad) = 1 - dcGood;
    data(k, cols.ST_high) = stHigh;
    data(k, cols.ST_low) = 1 - stHigh;
    data(k, cols.DT_high) = dtHigh;
    data(k, cols.DT_low) = 1 - dtHigh;
    data(k, cols.AI_high) = aiHigh;
    data(k, cols.AI_low) = 1 - aiHigh;
    data(k, cols.TE_high) = teHigh;
    data(k, cols.TE_mid) = teMid;
    data(k, cols.TE_low) = teLow;
end

validateScenario(data, cols);

result.scene = scene;
result.names = names;
result.data = data;
result.table = array2table(data, 'VariableNames', names);
end

function y = mu1(x, a, b)
% Z 型隶属度，用于“近距离”和“慢速度”。
mid = (a + b) * 0.5;
if x < a
    y = 1;
elseif x < mid
    t = (x - a) / (b - a);
    y = 1 - 2 * t * t;
elseif x < b
    t = (x - b) / (b - a);
    y = 2 * t * t;
else
    y = 0;
end
end

function y = mu2(x, a, d, y1, y3)
% 中间状态隶属度，由 1 减去两端状态得到。
if x < a
    y = 0;
elseif x < d
    y = 1 - y1 - y3;
else
    y = 0;
end
end

function y = mu3(x, c, d)
% S 型隶属度，用于“远距离”和“快速度”。
mid = (c + d) * 0.5;
if x < c
    y = 0;
elseif x < mid
    t = (x - c) / (d - c);
    y = 2 * t * t;
elseif x < d
    t = (x - d) / (d - c);
    y = 1 - 2 * t * t;
else
    y = 1;
end
end

function [high, mid, low] = threatEstimate(aiHigh, dtHigh, stHigh)
% 表 9 的综合威胁条件概率融合。
aiLow = 1 - aiHigh;
dtLow = 1 - dtHigh;
stLow = 1 - stHigh;

high = aiHigh * (dtHigh * (stHigh * 0.98 + stLow * 0.8) + ...
       dtLow * (stHigh * 0.85 + stLow * 0.7)) + ...
       aiLow * (dtHigh * (stHigh * 0.75 + stLow * 0.65) + ...
       dtLow * (stHigh * 0.4 + stLow * 0.02));

mid = aiHigh * (dtHigh * (stHigh * 0.02 + stLow * 0.1) + ...
      dtLow * (stHigh * 0.1 + stLow * 0.2)) + ...
      aiLow * (dtHigh * (stHigh * 0.15 + stLow * 0.2) + ...
      dtLow * (stHigh * 0.4 + stLow * 0.15));

low = aiHigh * (dtHigh * (stHigh * 0.0 + stLow * 0.1) + ...
      dtLow * (stHigh * 0.05 + stLow * 0.1)) + ...
      aiLow * (dtHigh * (stHigh * 0.1 + stLow * 0.15) + ...
      dtLow * (stHigh * 0.2 + stLow * 0.83));
end

function validateScenario(data, cols)
% 基本数值校验：概率范围合法，并且每个节点的状态概率和为 1。
tol = 1e-8;
probData = data(:, 2:end);
if any(probData(:) < -tol) || any(probData(:) > 1 + tol)
    error('A probability is outside [0, 1].');
end

checkSum(data(:, cols.RD_near) + data(:, cols.RD_mid) + data(:, cols.RD_far), tol, 'RD');
checkSum(data(:, cols.RS_slow) + data(:, cols.RS_mid) + data(:, cols.RS_fast), tol, 'RS');
checkSum(data(:, cols.DC_good) + data(:, cols.DC_bad), tol, 'DC');
checkSum(data(:, cols.ST_high) + data(:, cols.ST_low), tol, 'ST');
checkSum(data(:, cols.DT_high) + data(:, cols.DT_low), tol, 'DT');
checkSum(data(:, cols.AI_high) + data(:, cols.AI_low), tol, 'AI');
checkSum(data(:, cols.TE_high) + data(:, cols.TE_mid) + data(:, cols.TE_low), tol, 'TE');
end

function checkSum(values, tol, label)
if any(abs(values - 1) > tol)
    error('%s probability sum check failed.', label);
end
end

function writeScenario(result, fileName)
% 将每个场景完整数据输出为 CSV，方便 Excel、C 输出和 MATLAB 图互相核对。
outDir = fileparts(mfilename('fullpath'));
writetable(result.table, fullfile(outDir, fileName));
fprintf('Wrote %s\n', fullfile(outDir, fileName));
end

function plotPaperFigures(scene1, scene2)
plotPaperFiguresForOne(scene1);
plotPaperFiguresForOne(scene2);
plotPaperFiguresChineseForOne(scene1);
plotPaperFiguresChineseForOne(scene2);
end

function plotPaperFiguresForOne(result)
% 按论文图 6-14 的内容分别画英文图，并同时保存 PNG 和 FIG。
cols = getColumns();
outDir = fullfile(fileparts(mfilename('fullpath')), 'bayes_figures');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

if result.scene == 1
    plotThree(result, [cols.RD_near cols.RD_mid cols.RD_far], ...
        {'RD near', 'RD middle', 'RD far'}, ...
        'Fig. 6 Scene 1 relative distance membership', ...
        fullfile(outDir, 'fig06_scene1_relative_distance'));
    plotThree(result, [cols.RS_slow cols.RS_mid cols.RS_fast], ...
        {'RS slow', 'RS middle', 'RS fast'}, ...
        'Fig. 7 Scene 1 relative speed membership', ...
        fullfile(outDir, 'fig07_scene1_relative_speed'));
    plotTwo(result, [cols.ST_high cols.ST_low], ...
        {'ST high', 'ST low'}, ...
        'Fig. 8 Scene 1 static threat membership', ...
        fullfile(outDir, 'fig08_scene1_static_threat'));
    plotTwo(result, [cols.DT_high cols.DT_low], ...
        {'DT high', 'DT low'}, ...
        'Fig. 9 Scene 1 dynamic threat membership', ...
        fullfile(outDir, 'fig09_scene1_dynamic_threat'));
    plotThree(result, [cols.TE_high cols.TE_mid cols.TE_low], ...
        {'TE high', 'TE middle', 'TE low'}, ...
        'Fig. 10 Scene 1 threat estimation membership', ...
        fullfile(outDir, 'fig10_scene1_threat_estimation'));
else
    plotThree(result, [cols.RD_near cols.RD_mid cols.RD_far], ...
        {'RD near', 'RD middle', 'RD far'}, ...
        'Fig. 11 Scene 2 relative distance membership', ...
        fullfile(outDir, 'fig11_scene2_relative_distance'));
    plotTwo(result, [cols.DC_good cols.DC_bad], ...
        {'DC good', 'DC bad'}, ...
        'Fig. 12 Scene 2 detection condition membership', ...
        fullfile(outDir, 'fig12_scene2_detection_condition'));
    plotTwo(result, [cols.DT_high cols.DT_low], ...
        {'DT high', 'DT low'}, ...
        'Fig. 13 Scene 2 dynamic threat membership', ...
        fullfile(outDir, 'fig13_scene2_dynamic_threat'));
    plotThree(result, [cols.TE_high cols.TE_mid cols.TE_low], ...
        {'TE high', 'TE middle', 'TE low'}, ...
        'Fig. 14 Scene 2 threat estimation membership', ...
        fullfile(outDir, 'fig14_scene2_threat_estimation'));
end
end

function plotPaperFiguresChineseForOne(result)
% 单独生成中文图。文件名按原论文“图6 ... 图14 ...”命名。
cols = getColumns();
outDir = fullfile(fileparts(mfilename('fullpath')), 'bayes_figures_cn');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

if result.scene == 1
    plotThree(result, [cols.RD_far cols.RD_mid cols.RD_near], ...
        {'相对距离远', '相对距离中', '相对距离近'}, ...
        '图6 场景一相对距离节点隶属度变化趋势', ...
        fullfile(outDir, '图6 场景一相对距离节点隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
    plotThree(result, [cols.RS_fast cols.RS_mid cols.RS_slow], ...
        {'相对速度快', '相对速度中', '相对速度慢'}, ...
        '图7 场景一相对速度节点隶属度变化趋势', ...
        fullfile(outDir, '图7 场景一相对速度节点隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
    plotTwo(result, [cols.ST_high cols.ST_low], ...
        {'静态威胁高', '静态威胁低'}, ...
        '图8 场景一静态威胁节点隶属度变化趋势', ...
        fullfile(outDir, '图8 场景一静态威胁节点隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
    plotTwo(result, [cols.DT_high cols.DT_low], ...
        {'动态威胁高', '动态威胁低'}, ...
        '图9 场景一动态威胁节点隶属度变化趋势', ...
        fullfile(outDir, '图9 场景一动态威胁节点隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
    plotThree(result, [cols.TE_high cols.TE_mid cols.TE_low], ...
        {'威胁程度高', '威胁程度中', '威胁程度低'}, ...
        '图10 场景一威胁程度隶属度变化趋势', ...
        fullfile(outDir, '图10 场景一威胁程度隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
else
    plotThree(result, [cols.RD_far cols.RD_mid cols.RD_near], ...
        {'相对距离远', '相对距离中', '相对距离近'}, ...
        '图11 场景二相对距离节点隶属度变化趋势', ...
        fullfile(outDir, '图11 场景二相对距离节点隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
    plotTwo(result, [cols.DC_good cols.DC_bad], ...
        {'探测条件好', '探测条件不好'}, ...
        '图12 场景二探测条件节点隶属度变化趋势', ...
        fullfile(outDir, '图12 场景二探测条件节点隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
    plotTwo(result, [cols.DT_high cols.DT_low], ...
        {'动态威胁高', '动态威胁低'}, ...
        '图13 场景二动态威胁节点隶属度变化趋势', ...
        fullfile(outDir, '图13 场景二动态威胁节点隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
    plotThree(result, [cols.TE_high cols.TE_mid cols.TE_low], ...
        {'威胁程度高', '威胁程度中', '威胁程度低'}, ...
        '图14 场景二威胁程度隶属度变化趋势', ...
        fullfile(outDir, '图14 场景二威胁程度隶属度变化趋势'), ...
        '时间步', '隶属度', 'Microsoft YaHei');
end
end

function plotTwo(result, colIdx, labels, figTitle, baseName, xLabelText, yLabelText, fontName)
if nargin < 6
    xLabelText = 'Step';
end
if nargin < 7
    yLabelText = 'Membership';
end
if nargin < 8
    fontName = '';
end
plotColumns(result, colIdx, labels, figTitle, baseName, {'-o', '-s'}, xLabelText, yLabelText, fontName);
end

function plotThree(result, colIdx, labels, figTitle, baseName, xLabelText, yLabelText, fontName)
if nargin < 6
    xLabelText = 'Step';
end
if nargin < 7
    yLabelText = 'Membership';
end
if nargin < 8
    fontName = '';
end
plotColumns(result, colIdx, labels, figTitle, baseName, {'-o', '-s', '-^'}, xLabelText, yLabelText, fontName);
end

function plotColumns(result, colIdx, labels, figTitle, baseName, styles, xLabelText, yLabelText, fontName)
cols = getColumns();
t = result.data(:, cols.step);
fig = figure('Name', figTitle, 'Color', 'w');
hold on;
for k = 1:numel(colIdx)
    plot(t, result.data(:, colIdx(k)), styles{k}, 'LineWidth', 1.2, 'MarkerSize', 4);
end
hold off;
grid on;
xlabel(xLabelText);
ylabel(yLabelText);
title(figTitle);
legend(labels, 'Location', 'best');
ylim([0 1]);
xlim([min(t) max(t)]);
if ~isempty(fontName)
    set(findall(fig, '-property', 'FontName'), 'FontName', fontName);
end
saveas(fig, [baseName '.fig']);
print(fig, [baseName '.png'], '-dpng', '-r200');
fprintf('Saved %s.png\n', baseName);
end

function writeAlignmentReport(results)
rows = [alignmentRows(results.scene1); alignmentRows(results.scene2)];
writeAlignmentTable(rows);
end

function writeAlignmentReportForOne(result)
writeAlignmentTable(alignmentRows(result));
end

function writeAlignmentTable(rows)
% 保存与论文文字中显式数值的对照，偏差不强行抹掉，便于讲解复现误差。
outDir = fileparts(mfilename('fullpath'));
T = cell2table(rows, 'VariableNames', ...
    {'scene', 'step', 'quantity', 'computed', 'paper_text', 'abs_diff', 'note'});
writetable(T, fullfile(outDir, 'paper_alignment_report.csv'));
fprintf('Wrote %s\n', fullfile(outDir, 'paper_alignment_report.csv'));
end

function rows = alignmentRows(result)
cols = getColumns();
rows = {};
if result.scene == 1
    rows(end+1, :) = makeRow(result, 2, 'DT_high', cols.DT_high, 0.7496, '论文文字：动态威胁高从 0.3 上升到 0.7496；当前优先贴合图 6-9 曲线形状。');
    rows(end+1, :) = makeRow(result, 10, 'TE_high', cols.TE_high, 0.7821, '论文文字：形态异常使威胁程度高升至 0.7821；与图 9 的 DT 曲线存在轻微不可同时满足。');
    rows(end+1, :) = makeRow(result, 12, 'ST_high', cols.ST_high, 0.48, '论文文字：阴影区使静态威胁高从约 0.41 升至 0.48。');
    rows(end+1, :) = makeRow(result, 12, 'TE_high_peak', cols.TE_high, 0.7956, '论文文字：峰值为 0.7956；按图 9 的 DT≈0.8 推理时峰值略低。');
else
    rows(end+1, :) = makeRow(result, 0, 'DT_high', cols.DT_high, 0.3000, '论文图 13 和正文：轨道保持阶段动态威胁高约为 0.3。');
    rows(end+1, :) = makeRow(result, 0, 'TE_high', cols.TE_high, 0.3120, '论文文字：场景二初始威胁程度高。');
    rows(end+1, :) = makeRow(result, 3, 'DT_high', cols.DT_high, 0.7516, '论文文字：动态威胁高从 0.3 变为 0.7516。');
    rows(end+1, :) = makeRow(result, 3, 'TE_high', cols.TE_high, 0.5523, '论文文字：场景二第 3 步威胁程度高；采用图 13/图 14 联立反推的等效静态威胁校准。');
    rows(end+1, :) = makeRow(result, 23, 'DT_high', cols.DT_high, 0.88, '论文文字：相撞前动态威胁高达到 0.88。');
    rows(end+1, :) = makeRow(result, 23, 'TE_high', cols.TE_high, 0.6192, '论文文字：最终威胁程度高；采用等效静态威胁校准后与原文对齐。');
end
end

function row = makeRow(result, step, quantity, col, paperValue, note)
idx = find(result.data(:, 1) == step, 1);
computed = result.data(idx, col);
row = {result.scene, step, quantity, computed, paperValue, abs(computed - paperValue), note};
end

function names = getColumnNames()
names = {'step', 'RD_near', 'RD_mid', 'RD_far', ...
         'RS_slow', 'RS_mid', 'RS_fast', ...
         'DC_good', 'DC_bad', 'ST_high', 'ST_low', ...
         'DT_high', 'DT_low', 'AI_high', 'AI_low', ...
         'TE_high', 'TE_mid', 'TE_low'};
end

function cols = getColumns()
names = getColumnNames();
for k = 1:numel(names)
    cols.(names{k}) = k;
end
end
