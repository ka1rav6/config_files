
#pragma once

typedef struct{
    int col;
    char row;
}Point;

Point createPoint(int col, char row){
    Point p ={
        .col = col,
        .row = row
    };
    return p;
}