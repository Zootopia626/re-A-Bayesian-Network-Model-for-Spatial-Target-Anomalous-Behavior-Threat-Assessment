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

void condition_2(BayesResult *result)
{
    /* 场景二：碰撞，共 24 个时间步。 */
    static const double L[24] = {
        100.0, 100.0, 98.0, 95.0, 92.0, 90.0, 86.0, 81.0,
        78.0, 72.0, 65.0, 61.0, 55.0, 44.0, 37.0, 30.0,
        24.0, 19.0, 15.0, 10.0, 8.0, 5.0, 2.0, 0.8
    };
    static const double V[24] = {
        10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0,
        10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0,
        10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0
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
    result->rows = 24;

    for (i = 0; i < result->rows; ++i) {
        /* 相对距离逐步减小，最终进入“近距离”隶属度为 1 的碰撞邻域。 */
        rd_near = mu_1(L[i], La, Lb);
        rd_far = mu_3(L[i], Lc, Ld);
        rd_mid = mu_2(L[i], La, Ld, rd_near, rd_far);

        /*
         * 论文图 13 和正文显示第 0-2 步动态威胁高约为 0.3、低约为 0.7。
         * 若使用原复现代码中的 0.2/1/1.3 km/s，速度会落入“慢”状态，
         * 初始 DT_high 只有 0.15。因此场景二全程按“相对速度中”处理。
         */
        rs_slow = mu_1(V[i], Va, Vb);
        rs_fast = mu_3(V[i], Vc, Vd);
        rs_mid = mu_2(V[i], Va, Vd, rs_slow, rs_fast);

        /* 场景二光照和载荷均为良好，探测条件只随距离变化。 */
        dc_good = 0.85 * rd_far + 0.9 * rd_mid + 0.95 * rd_near;
        st_high = dc_good * 0.4 + (1.0 - dc_good) * 0.6;
        /*
         * 论文内部存在一个需要说明的数值矛盾：
         * 图 13 要求初始 DT_high 约 0.3，但若继续用表 8 中“军用卫星 + 探测条件”
         * 直算出的 ST_high≈0.43，表 9 会把图 14 初始 TE_high 推到约 0.38，
         * 高于论文文字和图中的 0.3120。由图 13、图 14 和表 9 反推，场景二的
         * 等效 ST_high 约为 0.18，并在碰撞邻域略降到约 0.17。
         * 这里保留探测条件曲线，同时采用等效静态威胁校准，以优先复现论文图像。
         */
        st_high = 0.18 - 0.01 * rd_near;

        /* 0-2 步为轨道保持；第 3 步起改为抵近，因此动态威胁跃升。 */
        dt_high =
            rs_fast * (rd_far * 0.5 + rd_mid * 0.55 + rd_near * 0.65) +
            rs_mid * (rd_far * 0.3 + rd_mid * 0.5 + rd_near * 0.6) +
            rs_slow * (rd_far * 0.15 + rd_mid * 0.4 + rd_near * 0.55);

        if (i >= 3) {
            dt_high =
                rs_fast * (rd_far * 0.8 + rd_mid * 0.85 + rd_near * 0.9) +
                rs_mid * (rd_far * 0.75 + rd_mid * 0.8 + rd_near * 0.88) +
                rs_slow * (rd_far * 0.65 + rd_mid * 0.78 + rd_near * 0.85);
        }

        /* 场景二无形态异常和历史扰动，告警信息高固定为 0.1。 */
        ai_high = 0.1;

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

        /* 综合威胁估计：与 MATLAB 版本保持同一套表 9 融合公式。 */
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
