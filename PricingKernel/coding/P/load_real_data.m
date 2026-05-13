% % filename: load_real_data.m
% % Created on Wendy Huang
% 
% function prices = load_real_data(data)
% 
% % coinPrice = readtable("coinPrice.csv");
% % if ismember('CRIX', data.Properties.VariableNames)
% %     data = removevars(data, 'CRIX');  % Remove 'CRIX' column
% % else
% %     data = data;  % If 'CRIX' does not exist, keep data unchanged
% % end
% % data2 = data1(1:1624, 2);
% % data = data2;
% 
% for i = 1:width(data)
%     if iscellstr(data{:, i}) || isstring(data{:, i})  % 檢查是否為字串
%         data{:, i} = strrep(data{:, i}, ',', '.');  % 替換逗號為小數點
%     end
% end
% 
% % Get the price table
% prices = [];
% for i = 1:width(data)
%     % 檢查每列是否能轉換為數值型資料
%     colData = data{:, i};
%     if iscellstr(colData) || isstring(colData)  % 如果是字串
%         % 將字串轉換為數字
%         colData = str2double(colData);
%     end
% 
%     % 檢查轉換後是否為數字
%     if isnumeric(colData) && all(~isnan(colData))  % 確保轉換成功且無 NaN
%         % 添加數字列到 numericData
%         prices = [prices colData];  % 水平合併數字列
%     end
% end


function prices = load_real_data(data)
    % Extract date column (assuming it's the first column)
    date_column = data{:, 1};  % Get first column
    if iscellstr(date_column) || isstring(date_column)  % Check if it's a string
        disp(date_column)
        date_column = datetime(string(date_column), 'InputFormat', 'yyyy/MM/dd HH:mm');  % Convert to datetime
    end

    % Process numerical columns (excluding the first column, which is the date)
    numericData = [];
    for i = 2:width(data)
        colData = data{:, i};

        if iscellstr(colData) || isstring(colData)  % If it's a string
            colData = strrep(colData, ',', '.');  % Replace commas with periods
            colData = str2double(colData);  % Convert to numeric
        end

        if isnumeric(colData) && all(~isnan(colData))  % Ensure conversion worked
            numericData = [numericData colData];  % Append column data
        end
    end

    % Store prices as a timetable with the date as an index
    disp(date_column)
    prices = timetable(date_column, numericData);
end