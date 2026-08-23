
#pragma once

#include <stdio.h>
#include <stdlib.h>
#include 

#define FATAL(msg)                \
    do {                          \
        fprintf(stderr, "%s", msg); \
        perror("");               \
        exit(EXIT_FAILURE);       \
    } while (0)