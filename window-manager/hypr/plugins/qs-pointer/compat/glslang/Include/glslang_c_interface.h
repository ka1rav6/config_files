/* Stand-in for glslang's C header, used only when the real one (glslang-dev)
 * is not installed. Hyprland's render/ShaderLoader.hpp includes it for one
 * default argument and two members; qs-pointer never touches the shader
 * loader, so these declarations are all that is needed (same layout as the
 * real ones regardless). Values match glslang's glslang_c_shader_types.h. The
 * Makefile adds this folder with -idirafter, so a real copy always wins. */
#pragma once
typedef enum {
    GLSLANG_STAGE_VERTEX,
    GLSLANG_STAGE_TESSCONTROL,
    GLSLANG_STAGE_TESSEVALUATION,
    GLSLANG_STAGE_GEOMETRY,
    GLSLANG_STAGE_FRAGMENT,
    GLSLANG_STAGE_COMPUTE,
} glslang_stage_t;

#include <stddef.h>

typedef struct glsl_include_result_s {
    const char* header_name;
    const char* header_data;
    size_t      header_length;
} glsl_include_result_t;

typedef glsl_include_result_t* (*glsl_include_local_func)(void* ctx, const char* header_name, const char* includer_name, size_t include_depth);
typedef glsl_include_result_t* (*glsl_include_system_func)(void* ctx, const char* header_name, const char* includer_name, size_t include_depth);
typedef int (*glsl_free_include_result_func)(void* ctx, glsl_include_result_t* result);

typedef struct glsl_include_callbacks_s {
    glsl_include_system_func      include_system;
    glsl_include_local_func       include_local;
    glsl_free_include_result_func free_include_result;
} glsl_include_callbacks_t;
