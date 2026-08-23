#pragma once
#include "point.h"
#include <stdbool.h>

typedef struct { // not for special moves like castling promotion or 
    Point start;

    Point end;
}Move;