#include "my_functions.h"

double mu_3(double x, double c, double d)
{
    double mid;
    double t;

    mid = (c + d) * 0.5;

    /* S 型隶属度：用于“远距离”和“快速度”。 */
    if (x < c) {
        return 0.0;
    }
    if (x < mid) {
        t = (x - c) / (d - c);
        return 2.0 * t * t;
    }
    if (x < d) {
        t = (x - d) / (d - c);
        return 1.0 - 2.0 * t * t;
    }
    return 1.0;
}
