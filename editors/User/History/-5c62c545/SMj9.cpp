#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

int main()
{
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(800, 600, "FIRST TRY", NULL, NULL);
    if (window == NULL){
        std::cout << "Failed to create a window" << std::endl;
        glfwTerminate();
        return 1;
    }

    // MUST COME BEFORE GLAD
    glfwMakeContextCurrent(window);

    // NOW GLAD CAN WORK
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)){
        std::cout << "Failed to initialize GLAD" << std::endl;
        return 1;
    }

    glViewport(0, 0, 800, 600);

    return 0;
}
