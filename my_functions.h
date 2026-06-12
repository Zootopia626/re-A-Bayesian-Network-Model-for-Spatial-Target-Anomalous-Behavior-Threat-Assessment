#ifndef MY_FUNCTIONS_H
#define MY_FUNCTIONS_H

#define BAYES_COLS 18
#define BAYES_MAX_ROWS 24

/* 输出矩阵列号。列顺序同时用于 C 控制台输出、MATLAB CSV 和绘图。 */
enum BayesColumn {
    COL_STEP = 0,
    COL_RD_NEAR,
    COL_RD_MID,
    COL_RD_FAR,
    COL_RS_SLOW,
    COL_RS_MID,
    COL_RS_FAST,
    COL_DC_GOOD,
    COL_DC_BAD,
    COL_ST_HIGH,
    COL_ST_LOW,
    COL_DT_HIGH,
    COL_DT_LOW,
    COL_AI_HIGH,
    COL_AI_LOW,
    COL_TE_HIGH,
    COL_TE_MID,
    COL_TE_LOW
};

/* 固定大小结果结构体，兼容 VS2015，避免 double** 与二维数组类型不匹配。 */
typedef struct BayesResult {
    int rows;
    double data[BAYES_MAX_ROWS][BAYES_COLS];
} BayesResult;

int background_chosen(int num_background, BayesResult *result);
void condition_1(BayesResult *result);
void condition_2(BayesResult *result);

double mu_1(double x, double a, double b);
double mu_2(double x, double a, double d, double mu1, double mu3);
double mu_3(double x, double c, double d);

#endif
