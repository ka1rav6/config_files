#pragma once
#include "point.h"
#include <stdbool.h>

typedef struct { // not for special moves like castling or promotion;
    Point* start;
    bool isCaptured;
    Point* end;
}Move;