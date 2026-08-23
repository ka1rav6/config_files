
#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>


#define FATAL(fmt, ...)                         \
    do {                                        \
        fprintf(stderr, fmt, ##__VA_ARGS__);    \
        perror("");                             \
        exit(EXIT_FAILURE);                     \
    } while (0)