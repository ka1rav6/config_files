#include <iostream>
#include <fstream>
#include "sudoku.h"
#include "xcounter.h"
#include "sudokusolver.h"
#include "display.h"

int main()
{   
    Sudoku s("source.txt");
    if (!s) {
        std::cout<<"The Sudoku is not valid"<<std::endl;
        return 0;
    }
    std::ifstream source("source.txt");
    std::ofstream destination("solution.txt");
    destination << source.rdbuf();
    source.close();
    destination.close();

    if (!s.isValid){
        std::cout<<"The Sudoku is not valid"<<std::endl;
    }
    else{
        sudokuSolver(&s);
        display(&s);
    }
}