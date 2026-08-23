// debugger.c
#include "debugger.h"


void logger(const char *msg) {
    FILE *file = fopen("logs.txt", "a");

    if (file == NULL) {
        return;
    }

    // Get current time
    time_t now = time(NULL);
    struct tm *t = localtime(&now);

    // Write timestamp + message
    fprintf(
        file,
        "[%02d-%02d-%04d %02d:%02d:%02d] %s\n",
        t->tm_mday,
        t->tm_mon + 1,
        t->tm_year + 1900,
        t->tm_hour,
        t->tm_min,
        t->tm_sec,
        msg
    );

    fclose(file);
}