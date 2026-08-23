
#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>

#define FATAL(fmt, ...)                           \
    do {                                          \
        fprintf(stderr, fmt, ##__VA_ARGS__);      \
        fprintf(stderr, ": %s\n", strerror(errno)); \
        exit(EXIT_FAILURE);                       \
    } while (0)
