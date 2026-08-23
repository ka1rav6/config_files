cmake_minimum_required(VERSION 3.10)
project(rule_engine C)

find_library(YYJSON_LIB yyjson REQUIRED)

add_executable(engine
    src/factdb.c
    src/factdb.h
    src/rule.c
    src/rule.h
    src/ConditionTree.h
    src/ConditionTree.c
    src/testFuncs.c
    src/jsonParser.c
    src/jsonParser.h
    src/semanticChecker.c
    src/semanticChecker.h
    src/uthash.h
    src/engine.c
    src/engine.h
    src/ActionEntry.c
    src/ActionEntry.h
    src/arena.c
    src/arena.h
    src/common.h
)

# Debug + gprof profiling
target_compile_options(engine PRIVATE
    -g
    -O0
    -pg
)

target_link_options(engine PRIVATE
    -pg
)

target_link_libraries(engine PRIVATE
    ${YYJSON_LIB}
)

# Valgrind target
find_program(VALGRIND_EXECUTABLE valgrind)

if(VALGRIND_EXECUTABLE)
    add_custom_target(
        valgrind
        COMMAND ${VALGRIND_EXECUTABLE}
                --leak-check=full
                --show-leak-kinds=all
                --track-origins=yes
                --verbose
                $<TARGET_FILE:engine>
        DEPENDS engine
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
endif()