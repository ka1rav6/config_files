#ifndef BOXSOLVER_H
#define BOXSOLVER_H

#include "sudoku.h"

class Sudoku; 

class BoxSolver{
    public:
        BoxSolver(Sudoku *s){
            this->s = s;
        }
        ~BoxSolver() = default;
        Sudoku* s;

        void Box1(char a);
        void Box2(char a);
        void Box3(char a);
        void Box4(char a);
        void Box5(char a);
        void Box6(char a);
        void Box7(char a);
        void Box8(char a);
        void Box9(char a);
};

#endif