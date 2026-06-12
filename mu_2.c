#include "my_functions.h"

double mu_2(double x, double a, double d, double mu1, double mu3)
{
    /* 中间状态由 1 减去两端隶属度得到，保证三状态和为 1。 */
    if (x < a) {
        return 0.0;
    }
    if (x < d) {
        return 1.0 - mu1 - mu3;
    }
    return 0.0;
}
