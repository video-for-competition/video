size = 6;

fd1 = fopen('../sim/behav/data/data1.txt', 'r');    %指向data文件的指针
fd2 = fopen('../sim/behav/data/data2.txt', 'r');
fd3 = fopen('../sim/behav/data/data3.txt', 'r');
fd4 = fopen('../sim/behav/data/data4.txt', 'r');

fw1 = fopen('../sim/behav/data/weight1.txt', 'r');  %指向weight文件的指针
fw2 = fopen('../sim/behav/data/weight2.txt', 'r');
fw3 = fopen('../sim/behav/data/weight3.txt', 'r');
fw4 = fopen('../sim/behav/data/weight4.txt', 'r');

fr = fopen('../sim/behav/data/result.txt', 'r');    %指向result文件的指针

data1 = fscanf(fd1, "%d%*[,;]", [size, 3*size]);    %读取数组
data2 = fscanf(fd2, "%d%*[,;]", [size, 3*size]);
data3 = fscanf(fd3, "%d%*[,;]", [size, 3*size]);
data4 = fscanf(fd4, "%d%*[,;]", [size, 3*size]);

data1 = data1.';                                    %将数组转置，方得到预期的顺序
data2 = data2.';
data3 = data3.';
data4 = data4.';

data11 = data1(1:size, :);
data12 = data1((size+1):(2*size), :);
data13 = data1((2*size+1):(3*size), :);
data21 = data2(1:size, :);
data22 = data2((size+1):(2*size), :);
data23 = data2((2*size+1):(3*size), :);
data31 = data3(1:size, :);
data32 = data3((size+1):(2*size), :);
data33 = data3((2*size+1):(3*size), :);
data41 = data4(1:size, :);
data42 = data4((size+1):(2*size), :);
data43 = data4((2*size+1):(3*size), :);

weight1 = fscanf(fw1, "%d%*[,;]", [3, 9]);
weight2 = fscanf(fw2, "%d%*[,;]", [3, 9]);
weight3 = fscanf(fw3, "%d%*[,;]", [3, 9]);
weight4 = fscanf(fw4, "%d%*[,;]", [3, 9]);

weight1 = weight1.';
weight2 = weight2.';
weight3 = weight3.';
weight4 = weight4.';

weight11 = weight1(1:3, :);
weight12 = weight1(4:6, :);
weight13 = weight1(7:9, :);
weight21 = weight2(1:3, :);
weight22 = weight2(4:6, :);
weight23 = weight2(7:9, :);
weight31 = weight3(1:3, :);
weight32 = weight3(4:6, :);
weight33 = weight3(7:9, :);
weight41 = weight4(1:3, :);
weight42 = weight4(4:6, :);
weight43 = weight4(7:9, :);


result_out = fscanf(fr, "%d%*[,;]", [size, size]);
result_out = result_out.';

fclose('all');

%开始卷积运算
conv_result1 = conv2(data11, rot90(weight11, 2), 'same') + conv2(data21, rot90(weight21, 2), 'same') ...
                + conv2(data31, rot90(weight31, 2), 'same') + conv2(data41, rot90(weight41, 2), 'same');
conv_result2 = conv2(data12, rot90(weight12, 2), 'same') + conv2(data22, rot90(weight22, 2), 'same') ...
                + conv2(data32, rot90(weight32, 2), 'same') + conv2(data42, rot90(weight42, 2), 'same');
conv_result3 = conv2(data13, rot90(weight13, 2), 'same') + conv2(data23, rot90(weight23, 2), 'same') ...
                + conv2(data33, rot90(weight33, 2), 'same') + conv2(data43, rot90(weight43, 2), 'same');
result_expected = conv_result1 + conv_result2 + conv_result3;
outcome = result_expected == result_out;

%打印结果
disp('result expected:');
disp(result_expected);
disp('result out:');
disp(result_out);
disp('outcome:');
disp(outcome);
%disp('data:');
%disp([data1, nan(size,1), data2, nan(size,1), data3, nan(size,1), data4]);
%disp('accum_in:');
%disp(accum_in);
%disp('conv_result:');
%disp(conv_result);
%disp('weight:');
%disp([weight1, nan(3, 1), weight2, nan(3, 1), weight3, nan(3, 1), weight4]);
