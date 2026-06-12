#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "my_functions.h"

static const char *COLUMN_NAMES[BAYES_COLS] = {
    "step", "RD_near", "RD_mid", "RD_far",
    "RS_slow", "RS_mid", "RS_fast",
    "DC_good", "DC_bad", "ST_high", "ST_low",
    "DT_high", "DT_low", "AI_high", "AI_low",
    "TE_high", "TE_mid", "TE_low"
};

static int in_unit_range(double value, double tol)
{
    return value >= -tol && value <= 1.0 + tol;
}

static int close_to_one(double value, double tol)
{
    return fabs(value - 1.0) <= tol;
}

static int validate_result(const BayesResult *result, double tol)
{
    int i;
    int j;
    const double *row;

    if (result == 0 || result->rows <= 0 || result->rows > BAYES_MAX_ROWS) {
        fprintf(stderr, "Invalid result size.\n");
        return 0;
    }

    /* 每一行都是一个时间步，所有概率/隶属度必须落在 [0,1]。 */
    for (i = 0; i < result->rows; ++i) {
        row = result->data[i];
        for (j = 1; j < BAYES_COLS; ++j) {
            if (!in_unit_range(row[j], tol)) {
                fprintf(stderr, "Out-of-range probability: row=%d col=%d value=%.12f\n", i, j, row[j]);
                return 0;
            }
        }

        /* 同一节点的互斥状态概率和应为 1，防止后续画图时悄悄带错数据。 */
        if (!close_to_one(row[COL_RD_NEAR] + row[COL_RD_MID] + row[COL_RD_FAR], tol) ||
            !close_to_one(row[COL_RS_SLOW] + row[COL_RS_MID] + row[COL_RS_FAST], tol) ||
            !close_to_one(row[COL_DC_GOOD] + row[COL_DC_BAD], tol) ||
            !close_to_one(row[COL_ST_HIGH] + row[COL_ST_LOW], tol) ||
            !close_to_one(row[COL_DT_HIGH] + row[COL_DT_LOW], tol) ||
            !close_to_one(row[COL_AI_HIGH] + row[COL_AI_LOW], tol) ||
            !close_to_one(row[COL_TE_HIGH] + row[COL_TE_MID] + row[COL_TE_LOW], tol)) {
            fprintf(stderr, "Probability sum check failed at row=%d\n", i);
            return 0;
        }
    }

    return 1;
}

static void print_header(FILE *stream, const char *separator)
{
    int j;

    /* 表头使用英文变量名，方便 MATLAB/Excel 直接读入。 */
    for (j = 0; j < BAYES_COLS; ++j) {
        if (j > 0) {
            fprintf(stream, "%s", separator);
        }
        fprintf(stream, "%s", COLUMN_NAMES[j]);
    }
    fprintf(stream, "\n");
}

static void print_result_to_stream(FILE *stream, const BayesResult *result, const char *separator)
{
    int i;
    int j;

    print_header(stream, separator);
    for (i = 0; i < result->rows; ++i) {
        for (j = 0; j < BAYES_COLS; ++j) {
            if (j > 0) {
                fprintf(stream, "%s", separator);
            }
            /* 输出 12 位有效数字，便于 MATLAB/Excel 复核时减少舍入误差。 */
            fprintf(stream, "%.12g", result->data[i][j]);
        }
        fprintf(stream, "\n");
    }
}

static void print_result(const BayesResult *result)
{
    print_result_to_stream(stdout, result, " ");
}

static int write_result_csv(const char *file_name, const BayesResult *result)
{
    FILE *fp;

    if (fopen_s(&fp, file_name, "w") != 0 || fp == 0) {
        fprintf(stderr, "Failed to write file: %s\n", file_name);
        return 0;
    }

    print_result_to_stream(fp, result, ",");
    fclose(fp);
    return 1;
}

static void discard_input_line(void)
{
    int ch;

    do {
        ch = getchar();
    } while (ch != '\n' && ch != EOF);
}

static void wait_for_enter(void)
{
    printf("\nPress Enter to exit...");
    fflush(stdout);
    (void)getchar();
}

static int run_one_scenario(int scenario, const char *csv_file, int verbose)
{
    BayesResult result;

    if (!background_chosen(scenario, &result)) {
        fprintf(stderr, "Invalid scenario. Use 1 or 2.\n");
        return 1;
    }

    if (!validate_result(&result, 1.0e-8)) {
        return 2;
    }

    if (verbose) {
        printf("\nScenario %d result:\n", scenario);
    }
    print_result(&result);

    if (!write_result_csv(csv_file, &result)) {
        return 3;
    }

    if (verbose) {
        printf("\nSaved CSV: %s\n", csv_file);
    }

    return 0;
}

int main(int argc, char *argv[])
{
    int num_background;
    int interactive;
    int status;

    interactive = (argc < 2);

    if (argc >= 2) {
        num_background = atoi(argv[1]);
    } else {
        printf("Select scenario:\n");
        printf("  0 = run both scenarios and save both CSV files\n");
        printf("  1 = approach fly-around\n");
        printf("  2 = collision\n");
        printf("Input: ");
        if (scanf_s("%d", &num_background) != 1) {
            fprintf(stderr, "Failed to read scenario number.\n");
            discard_input_line();
            wait_for_enter();
            return 1;
        }
        discard_input_line();
    }

    if (interactive) {
        printf("CSV files will be saved in the current working directory.\n\n");
    }

    if (num_background == 0) {
        status = run_one_scenario(1, "condition1_from_c.csv", interactive);
        if (status == 0) {
            status = run_one_scenario(2, "condition2_from_c.csv", interactive);
        }
    } else if (num_background == 1) {
        status = run_one_scenario(1, "condition1_from_c.csv", interactive);
    } else if (num_background == 2) {
        status = run_one_scenario(2, "condition2_from_c.csv", interactive);
    } else {
        fprintf(stderr, "Invalid scenario. Use 0, 1, or 2.\n");
        status = 1;
    }

    if (interactive) {
        wait_for_enter();
    }

    return status;
}
