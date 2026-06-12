#include "my_functions.h"

static void clear_result(BayesResult *result)
{
    int i;
    int j;

    result->rows = 0;
    for (i = 0; i < BAYES_MAX_ROWS; ++i) {
        for (j = 0; j < BAYES_COLS; ++j) {
            result->data[i][j] = 0.0;
        }
    }
}

void condition_1(BayesResult *result)
{
    /* 场景一：抵近绕飞，共 20 个时间步。 */
    static const double L[20] = {
        120.0, 120.0, 91.0, 80.0, 68.0, 55.0, 45.0, 20.0, 10.0, 10.0,
        10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 30.0, 40.0, 55.0
    };
    static const double V[20] = {
        10.0, 10.0, 8.88, 8.63, 8.5, 8.3, 7.85, 7.2, 6.1, 5.0,
        5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 6.37, 7.06, 7.5
    };
    const double La = 10.0;
    const double Lb = 55.0;
    const double Lc = 55.0;
    const double Ld = 100.0;
    const double Va = 5.0;
    const double Vb = 10.0;
    const double Vc = 10.0;
    const double Vd = 15.0;
    int i;
    double rd_near;
    double rd_mid;
    double rd_far;
    double rs_slow;
    double rs_mid;
    double rs_fast;
    double dc_good;
    double st_high;
    double dt_high;
    double ai_high;

    clear_result(result);
    result->rows = 20;

    for (i = 0; i < result->rows; ++i) {
        /*
         * 先将连续距离、速度通过隶属度函数离散化为三状态概率。
         * L/V 序列按论文图 6 和图 7 反向校准，使曲线形状与原文尽量一致。
         */
        rd_near = mu_1(L[i], La, Lb);
        rd_far = mu_3(L[i], Lc, Ld);
        rd_mid = mu_2(L[i], La, Ld, rd_near, rd_far);

        rs_slow = mu_1(V[i], Va, Vb);
        rs_fast = mu_3(V[i], Vc, Vd);
        rs_mid = mu_2(V[i], Va, Vd, rs_slow, rs_fast);

        /* 探测条件：一般光照下由相对距离决定；12-15 步模拟阴影/光照较差。 */
        dc_good = 0.85 * rd_far + 0.9 * rd_mid + 0.95 * rd_near;
        if (i >= 12 && i <= 15) {
            dc_good = 0.5 * rd_far + 0.55 * rd_mid + 0.6 * rd_near;
        }

        /* 静态威胁：本文复现中目标类型固定为军用卫星。 */
        st_high = dc_good * 0.4 + (1.0 - dc_good) * 0.6;

        /* 动态威胁：默认轨道保持，后续按时间步切换到抵近/绕飞/飞离。 */
        dt_high =
            rs_fast * (rd_far * 0.5 + rd_mid * 0.55 + rd_near * 0.65) +
            rs_mid * (rd_far * 0.3 + rd_mid * 0.5 + rd_near * 0.6) +
            rs_slow * (rd_far * 0.15 + rd_mid * 0.4 + rd_near * 0.55);

        if (i >= 2 && i <= 8) {
            dt_high =
                rs_fast * (rd_far * 0.8 + rd_mid * 0.85 + rd_near * 0.9) +
                rs_mid * (rd_far * 0.75 + rd_mid * 0.8 + rd_near * 0.88) +
                rs_slow * (rd_far * 0.65 + rd_mid * 0.78 + rd_near * 0.85);
        }
        if (i >= 9 && i <= 16) {
            dt_high =
                rs_fast * (rd_far * 0.7 + rd_mid * 0.75 + rd_near * 0.88) +
                rs_mid * (rd_far * 0.65 + rd_mid * 0.7 + rd_near * 0.85) +
                rs_slow * (rd_far * 0.55 + rd_mid * 0.68 + rd_near * 0.8);
        }
        if (i >= 17 && i <= 19) {
            dt_high =
                rs_fast * (rd_far * 0.25 + rd_mid * 0.35 + rd_near * 0.4) +
                rs_mid * (rd_far * 0.15 + rd_mid * 0.25 + rd_near * 0.4) +
                rs_slow * (rd_far * 0.12 + rd_mid * 0.25 + rd_near * 0.3);
        }

        /* 告警信息：10-15 步设为形态异常，其余时间为形态正常。 */
        ai_high = 0.1;
        if (i >= 10 && i <= 15) {
            ai_high = 0.7;
        }

        result->data[i][COL_STEP] = (double)i;
        result->data[i][COL_RD_NEAR] = rd_near;
        result->data[i][COL_RD_MID] = rd_mid;
        result->data[i][COL_RD_FAR] = rd_far;
        result->data[i][COL_RS_SLOW] = rs_slow;
        result->data[i][COL_RS_MID] = rs_mid;
        result->data[i][COL_RS_FAST] = rs_fast;
        result->data[i][COL_DC_GOOD] = dc_good;
        result->data[i][COL_DC_BAD] = 1.0 - dc_good;
        result->data[i][COL_ST_HIGH] = st_high;
        result->data[i][COL_ST_LOW] = 1.0 - st_high;
        result->data[i][COL_DT_HIGH] = dt_high;
        result->data[i][COL_DT_LOW] = 1.0 - dt_high;
        result->data[i][COL_AI_HIGH] = ai_high;
        result->data[i][COL_AI_LOW] = 1.0 - ai_high;

        /* 综合威胁估计：由告警信息、动态威胁、静态威胁按表 9 融合。 */
        result->data[i][COL_TE_HIGH] =
            ai_high * (dt_high * (st_high * 0.98 + (1.0 - st_high) * 0.8) +
            (1.0 - dt_high) * (st_high * 0.85 + (1.0 - st_high) * 0.7)) +
            (1.0 - ai_high) * (dt_high * (st_high * 0.75 + (1.0 - st_high) * 0.65) +
            (1.0 - dt_high) * (st_high * 0.4 + (1.0 - st_high) * 0.02));

        result->data[i][COL_TE_MID] =
            ai_high * (dt_high * (st_high * 0.02 + (1.0 - st_high) * 0.1) +
            (1.0 - dt_high) * (st_high * 0.1 + (1.0 - st_high) * 0.2)) +
            (1.0 - ai_high) * (dt_high * (st_high * 0.15 + (1.0 - st_high) * 0.2) +
            (1.0 - dt_high) * (st_high * 0.4 + (1.0 - st_high) * 0.15));

        result->data[i][COL_TE_LOW] =
            ai_high * (dt_high * (st_high * 0.0 + (1.0 - st_high) * 0.1) +
            (1.0 - dt_high) * (st_high * 0.05 + (1.0 - st_high) * 0.1)) +
            (1.0 - ai_high) * (dt_high * (st_high * 0.1 + (1.0 - st_high) * 0.15) +
            (1.0 - dt_high) * (st_high * 0.2 + (1.0 - st_high) * 0.83));
    }
}
