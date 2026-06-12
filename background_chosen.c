#include "my_functions.h"

int background_chosen(int num_background, BayesResult *result)
{
    /* 统一入口：1 为抵近绕飞场景，2 为碰撞场景。 */
    if (result == 0) {
        return 0;
    }

    if (num_background == 1) {
        condition_1(result);
        return 1;
    }

    if (num_background == 2) {
        condition_2(result);
        return 1;
    }

    return 0;
}
