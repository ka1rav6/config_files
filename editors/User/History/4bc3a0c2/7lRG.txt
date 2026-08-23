cmake_minimum_required(VERSION 3.16)

project(SudokuSolver)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(include)

add_executable(SudokuSolver
    src/main.cpp
    src/validation.cpp
    src/sudoku.cpp
    src/xcounter.cpp
    src/rowsolver.cpp
    src/columnsolver.cpp
    src/boxsolver.cpp
    src/sudokusolver.cpp
    src/display.cpp
)