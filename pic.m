figure(1)
plot(condition1(:,1),condition1(:,2),'-o','LineWidth',1)
hold on
grid on
plot(condition1(:,1),condition1(:,3),'-s','LineWidth',1)
plot(condition1(:,1),condition1(:,4),'-^','LineWidth',1)
axis([0,19,0,1])
legend('相对距离近','相对距离中','相对距离远');
xlabel('时间步')
ylabel('隶属度')

figure(2)
plot(condition1(:,1),condition1(:,5),'-o','LineWidth',1)
hold on
grid on
plot(condition1(:,1),condition1(:,6),'-s','LineWidth',1)
plot(condition1(:,1),condition1(:,7),'-^','LineWidth',1)
axis([0,19,0,1])
legend('相对速度慢','相对速度中','相对速度快');
xlabel('时间步')
ylabel('隶属度')

figure(3)
plot(condition1(:,1),condition1(:,8),'-o','LineWidth',1)
hold on
grid on
plot(condition1(:,1),condition1(:,9),'-s','LineWidth',1)
axis([0,19,0,1])
legend('探测条件好','探测条件差');
xlabel('时间步')
ylabel('隶属度')

figure(4)
plot(condition1(:,1),condition1(:,10),'-o','LineWidth',1)
hold on
grid on
plot(condition1(:,1),condition1(:,11),'-s','LineWidth',1)
axis([0,19,0,1])
legend('静态威胁高','静态威胁低');
xlabel('时间步')
ylabel('隶属度')

figure(5)
plot(condition1(:,1),condition1(:,12),'-o','LineWidth',1)
hold on
grid on
plot(condition1(:,1),condition1(:,13),'-s','LineWidth',1)
axis([0,19,0,1])
legend('动态威胁高','动态威胁低');
xlabel('时间步')
ylabel('隶属度')

figure(6)
plot(condition1(:,1),condition1(:,14),'-o','LineWidth',1)
hold on
grid on
plot(condition1(:,1),condition1(:,15),'-s','LineWidth',1)
axis([0,19,0,1])
legend('告警信息高','告警信息低');
xlabel('时间步')
ylabel('隶属度')

figure(7)
plot(condition1(:,1),condition1(:,16),'-o','LineWidth',1)
hold on
grid on
plot(condition1(:,1),condition1(:,17),'-s','LineWidth',1)
plot(condition1(:,1),condition1(:,18),'-^','LineWidth',1)
axis([0,19,0,1])
legend('威胁程度高','威胁程度中','威胁程度低');
xlabel('时间步')
ylabel('隶属度')

figure(8)
plot(condition2(:,1),condition2(:,2),'-o','LineWidth',1)
hold on
grid on
plot(condition2(:,1),condition2(:,3),'-s','LineWidth',1)
plot(condition2(:,1),condition2(:,4),'-^','LineWidth',1)
axis([0,23,0,1])
legend('相对距离近','相对距离中','相对距离远');
xlabel('时间步')
ylabel('隶属度')

figure(9)
plot(condition2(:,1),condition2(:,5),'-o','LineWidth',1)
hold on
grid on
plot(condition2(:,1),condition2(:,6),'-s','LineWidth',1)
plot(condition2(:,1),condition2(:,7),'-^','LineWidth',1)
axis([0,23,0,1])
legend('相对速度慢','相对速度中','相对速度快');
xlabel('时间步')
ylabel('隶属度')

figure(10)
plot(condition2(:,1),condition2(:,8),'-o','LineWidth',1)
hold on
grid on
plot(condition2(:,1),condition2(:,9),'-s','LineWidth',1)
axis([0,23,0,1])
legend('探测条件好','探测条件差');
xlabel('时间步')
ylabel('隶属度')

figure(11)
plot(condition2(:,1),condition2(:,10),'-o','LineWidth',1)
hold on
grid on
plot(condition2(:,1),condition2(:,11),'-s','LineWidth',1)
axis([0,23,0,1])
legend('静态威胁高','静态威胁低');
xlabel('时间步')
ylabel('隶属度')

figure(12)
plot(condition2(:,1),condition2(:,12),'-o','LineWidth',1)
hold on
grid on
plot(condition2(:,1),condition2(:,13),'-s','LineWidth',1)
axis([0,23,0,1])
legend('动态威胁高','动态威胁低');
xlabel('时间步')
ylabel('隶属度')

figure(13)
plot(condition2(:,1),condition2(:,14),'-o','LineWidth',1)
hold on
grid on
plot(condition2(:,1),condition2(:,15),'-s','LineWidth',1)
axis([0,23,0,1])
legend('告警信息高','告警信息低');
xlabel('时间步')
ylabel('隶属度')

figure(14)
plot(condition2(:,1),condition2(:,16),'-o','LineWidth',1)
hold on
grid on
plot(condition2(:,1),condition2(:,17),'-s','LineWidth',1)
plot(condition2(:,1),condition2(:,18),'-^','LineWidth',1)
axis([0,23,0,1])
legend('威胁程度高','威胁程度中','威胁程度低');
xlabel('时间步')
ylabel('隶属度')