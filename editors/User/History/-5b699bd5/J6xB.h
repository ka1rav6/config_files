//
// Created by kairav on 6/7/26.
//

#ifndef MAIN_GAME_GAME_H
#define MAIN_GAME_GAME_H
#include <string>
#include "../include/common.h"
#include "../include/Scene.h"
#include "../include/systems/Renderer.h"
#include "../include/systems/MyImgui.h"
#include "../include/systems/Editor.h"


struct Settings {
    // basic screen settings
    const glm::vec4 bgcolor = glm::vec4(0.53f, 0.81f, 0.92f, 1.0f); // Sky blue;
    const char* WINDOW_TITLE = "CTF IIITD";
    const int SCR_WIDTH = 1600;
    const int SCR_HEIGHT = 1200;

    // Camera settings:
    glm::vec3 camera_position = glm::vec3(0.0f, 1.0f, 4.0f);
    float lastX = (float)SCR_WIDTH / 2.0f;
    float lastY = (float)SCR_HEIGHT / 2.0f;
};
struct Timer {
    float deltaTime = 0.0f;	// time between current frame and last frame
    float lastFrame = 0.0f;
};

class Game {
public:
    Game(bool mouseCaptured);
    Game(Settings settings);
    ~Game();
    void run();
    void cleanup();
    void draw() const;
    bool isRunning() const {
        return !glfwWindowShouldClose(window);
    };
private:
    void processInput() const;
    static void mouse_callback(GLFWwindow* window, double xpos, double ypos);
    static void scroll_callback(GLFWwindow* window, double xoffset, double yoffset);
    static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods);
    static void mouse_button_callback(GLFWwindow* window, int button, int action, int mods);
    void setEditorMode(bool enabled);

    void init();
    Settings settings;
    GLFWwindow *window;
    Camera *camera;
    Timer timer;
    bool firstMouse = true;
    bool editorMode = false;
    Scene *scene;
    Renderer *renderer;
    unsigned int cubeVAO, VBO;
    ImGuiIO* io = nullptr;
    Editor *editor;
};
// cube vertices: (taken from learnopenGL directly for now)
constexpr float vertices[] = {
    -0.5f, -0.5f, -0.5f,  0.0f, 0.0f,
     0.5f, -0.5f, -0.5f,  1.0f, 0.0f,
     0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
     0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
    -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,
    -0.5f, -0.5f, -0.5f,  0.0f, 0.0f,

    -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
     0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
     0.5f,  0.5f,  0.5f,  1.0f, 1.0f,
     0.5f,  0.5f,  0.5f,  1.0f, 1.0f,
    -0.5f,  0.5f,  0.5f,  0.0f, 1.0f,
    -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,

    -0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
    -0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
    -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
    -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
    -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
    -0.5f,  0.5f,  0.5f,  1.0f, 0.0f,

     0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
     0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
     0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
     0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
     0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
     0.5f,  0.5f,  0.5f,  1.0f, 0.0f,

    -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,
     0.5f, -0.5f, -0.5f,  1.0f, 1.0f,
     0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
     0.5f, -0.5f,  0.5f,  1.0f, 0.0f,
    -0.5f, -0.5f,  0.5f,  0.0f, 0.0f,
    -0.5f, -0.5f, -0.5f,  0.0f, 1.0f,

    -0.5f,  0.5f, -0.5f,  0.0f, 1.0f,
     0.5f,  0.5f, -0.5f,  1.0f, 1.0f,
     0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
     0.5f,  0.5f,  0.5f,  1.0f, 0.0f,
    -0.5f,  0.5f,  0.5f,  0.0f, 0.0f,
    -0.5f,  0.5f, -0.5f,  0.0f, 1.0f
};


#endif //MAIN_GAME_GAME_H