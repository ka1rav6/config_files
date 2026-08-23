


#define FATAL(msg)                \
    do {                          \
        fprintf(stderr, "%s", msg); \
        perror("");               \
        exit(EXIT_FAILURE);       \
    } while (0)