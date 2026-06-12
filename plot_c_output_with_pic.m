function results = plot_c_output_with_pic(makeVisible)
%PLOT_C_OUTPUT_WITH_PIC 运行 C 程序，并用原来的 pic.m 绘制 C 语言输出数据。
%   兼容 MATLAB R2020b。
%
%   用法：
%       plot_c_output_with_pic
%       plot_c_output_with_pic(false)   % 后台出图，不弹出窗口
%
%   输出：
%       c_output\condition1_from_c.csv/xlsx/txt
%       c_output\condition2_from_c.csv/xlsx/txt
%       c_pic_figures\*.png 和 *.fig
%
%   注意：
%       这里不修改 pic.m，而是在运行 pic.m 前准备它需要的
%       condition1 和 condition2 两个矩阵。

if nargin < 1 || isempty(makeVisible)
    makeVisible = true;
end

rootDir = fileparts(mfilename('fullpath'));
exeFile = fullfile(rootDir, 'Project1', 'Release', 'Bayes_model.exe');
picFile = fullfile(rootDir, 'pic.m');
outDir = fullfile(rootDir, 'c_output');
figDir = fullfile(rootDir, 'c_pic_figures');

if ~exist(exeFile, 'file')
    error('未找到 C 程序：%s。请先用 Visual Studio 2015 编译 Release|x86。', exeFile);
end
if ~exist(picFile, 'file')
    error('未找到原绘图脚本 pic.m：%s。', picFile);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

oldVisible = get(0, 'DefaultFigureVisible');
cleanupObj = onCleanup(@() set(0, 'DefaultFigureVisible', oldVisible));
if makeVisible
    set(0, 'DefaultFigureVisible', 'on');
else
    set(0, 'DefaultFigureVisible', 'off');
end

% 分别运行两个场景。C 程序输出的第一行是表头，后续是数值矩阵。
[condition1, names1, raw1] = runCScenario(exeFile, 1);
[condition2, names2, raw2] = runCScenario(exeFile, 2);

writeCOutput(outDir, 'condition1_from_c', condition1, names1, raw1);
writeCOutput(outDir, 'condition2_from_c', condition2, names2, raw2);

% 原 pic.m 是脚本，会直接读取当前工作区中的 condition1/condition2。
close all force;
run(picFile);
savePicFigures(figDir);

results.condition1 = condition1;
results.condition2 = condition2;
results.names = names1;
results.outputDir = outDir;
results.figureDir = figDir;

fprintf('C 语言场景一数据：%s\n', fullfile(outDir, 'condition1_from_c.csv'));
fprintf('C 语言场景二数据：%s\n', fullfile(outDir, 'condition2_from_c.csv'));
fprintf('pic.m 图像输出目录：%s\n', figDir);

if ~makeVisible
    close all force;
end
end

function [data, names, rawText] = runCScenario(exeFile, scene)
% 调用 C 可执行文件并解析控制台输出。
cmd = sprintf('"%s" %d', exeFile, scene);
[status, rawText] = system(cmd);
if status ~= 0
    error('C 程序运行失败，场景=%d。\n命令：%s\n输出：\n%s', scene, cmd, rawText);
end

lines = regexp(strtrim(rawText), '\r\n|\n|\r', 'split');
if numel(lines) < 2
    error('C 程序输出行数不足，无法解析。场景=%d', scene);
end

names = strsplit(strtrim(lines{1}));
numericText = strjoin(lines(2:end), ' ');
values = sscanf(numericText, '%f');
numCols = numel(names);

if mod(numel(values), numCols) ~= 0
    error('C 输出列数不匹配。场景=%d，列数=%d，数值个数=%d。', scene, numCols, numel(values));
end

data = reshape(values, numCols, []).';

if scene == 1 && size(data, 1) ~= 20
    error('场景一应为 20 行，实际为 %d 行。', size(data, 1));
elseif scene == 2 && size(data, 1) ~= 24
    error('场景二应为 24 行，实际为 %d 行。', size(data, 1));
end

validateProbabilityData(data, names, scene);
end

function validateProbabilityData(data, names, scene)
% 检查概率/隶属度范围，避免 C 端输出异常数据后仍继续画图。
probData = data(:, 2:end);
tol = 1.0e-8;
if any(probData(:) < -tol) || any(probData(:) > 1 + tol)
    error('场景 %d 存在超出 [0,1] 的概率/隶属度。', scene);
end

requiredCols = {'RD_near', 'RD_mid', 'RD_far', 'RS_slow', 'RS_mid', 'RS_fast', ...
    'DC_good', 'DC_bad', 'ST_high', 'ST_low', 'DT_high', 'DT_low', ...
    'AI_high', 'AI_low', 'TE_high', 'TE_mid', 'TE_low'};
for k = 1:numel(requiredCols)
    if ~ismember(requiredCols{k}, names)
        error('场景 %d 缺少列：%s。', scene, requiredCols{k});
    end
end
end

function writeCOutput(outDir, baseName, data, names, rawText)
% 同时保存原始控制台文本、带表头 CSV 和 Excel，便于人工查看。
rawFile = fullfile(outDir, [baseName '.txt']);
fid = fopen(rawFile, 'w');
if fid < 0
    error('无法写入文件：%s', rawFile);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s', rawText);
clear cleanupObj;

validNames = matlab.lang.makeValidName(names);
T = array2table(data, 'VariableNames', validNames);
writetable(T, fullfile(outDir, [baseName '.csv']));

% Excel 写入偶尔受本机 Office/权限影响；失败时 CSV 仍然可直接查看。
try
    writetable(T, fullfile(outDir, [baseName '.xlsx']));
catch ME
    warning('Excel 文件写入失败：%s。CSV 文件已正常生成。', ME.message);
end
end

function savePicFigures(figDir)
% 保存 pic.m 生成的 14 张图。
figureNames = { ...
    '01_场景一相对距离', ...
    '02_场景一相对速度', ...
    '03_场景一探测条件', ...
    '04_场景一静态威胁', ...
    '05_场景一动态威胁', ...
    '06_场景一告警信息', ...
    '07_场景一威胁程度', ...
    '08_场景二相对距离', ...
    '09_场景二相对速度', ...
    '10_场景二探测条件', ...
    '11_场景二静态威胁', ...
    '12_场景二动态威胁', ...
    '13_场景二告警信息', ...
    '14_场景二威胁程度'};

for k = 1:numel(figureNames)
    if ishghandle(k, 'figure')
        fig = figure(k);
        savefig(fig, fullfile(figDir, [figureNames{k} '.fig']));
        print(fig, fullfile(figDir, [figureNames{k} '.png']), '-dpng', '-r200');
    end
end
end
