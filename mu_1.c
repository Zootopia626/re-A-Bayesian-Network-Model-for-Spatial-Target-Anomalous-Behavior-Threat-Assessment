#include "my_functions.h"

double mu_1(double x, double a, double b)
{
    double mid;
    double t;

    mid = (a + b) * 0.5;

    /* Z 型隶属度：用于“近距离”和“慢速度”。 */
    if (x < a) {
        return 1.0;
    }
    if (x < mid) {
        t = (x - a) / (b - a);
        return 1.0 - 2.0 * t * t;
    }
    if (x < b) {
        t = (x - b) / (b - a);
        return 2.0 * t * t;
    }
    return 0.0;
}
