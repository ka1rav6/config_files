//
// Created by kairav on 6/7/26.
//

#include "../include/Game.h"



Game::Game(bool mouseCaptured) {
    init();
    LOG_INFO("init function completely executed");
    if (!*this->window)
        LOG_FATAL("Failed to execute Game::init() function. Window not created!");
    if (mouseCaptured) {
        glfwSetInputMode(*this->window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    }
    glfwSetCursorPosCallback(*this->window, Game::mouse_callback);
    glfwSetScrollCallback(*this->window, Game::scroll_callback);
    LOG_INFO("Set all different callbacks successfully!");
}

void Game::init() {
    this->window = Initializer::init(settings.SCR_WIDTH, settings.SCR_HEIGHT, settings.WINDOW_TITLE);
    glfwMakeContextCurrent(*this->window);
    glfwSetWindowUserPointer(* this->window, this);
    glEnable(GL_DEPTH_TEST);

    camera = new Camera(settings.camera_position);
    LOG_INFO("Created window and camera userpointer!");

    glGenVertexArrays(1, &cubeVAO);
    glGenBuffers(1, &VBO);


    glBindVertexArray(cubeVAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    // position attribute
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    // texture coord attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);

    LOG_INFO("About to initialize Sun");
    sun = new Sun(cubeVAO);

}

Game::~Game() {
    delete camera;
    camera = nullptr;
    delete sun;
    sun = nullptr;

    // free all VBOs, VAOs, and EBOs
    glDeleteVertexArrays(1, &cubeVAO);
    glDeleteBuffers(1, &VBO);
    glfwTerminate();

}

void Game::processInput() {
    if (glfwGetKey(*this->window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(*this->window, true);

    if (glfwGetKey(*this->window, GLFW_KEY_W) == GLFW_PRESS)
        camera->ProcessKeyboard(FORWARD, timer.deltaTime);
    if (glfwGetKey(*this->window, GLFW_KEY_S) == GLFW_PRESS)
        camera->ProcessKeyboard(BACKWARD, timer.deltaTime);
    if (glfwGetKey(*this->window, GLFW_KEY_A) == GLFW_PRESS)
        camera->ProcessKeyboard(LEFT, timer.deltaTime);
    if (glfwGetKey(*    this->window, GLFW_KEY_D) == GLFW_PRESS)
        camera->ProcessKeyboard(RIGHT, timer.deltaTime);
}

void Game::mouse_callback(GLFWwindow* window, double xposIn, double yposIn)
{
    Game* game = static_cast<Game*>(glfwGetWindowUserPointer(window));
    if (!game) return;

    float xpos = static_cast<float>(xposIn);
    float ypos = static_cast<float>(yposIn);

    if (game->firstMouse)
    {
        game->settings.lastX = xpos;
        game->settings.lastY = ypos;
        game->firstMouse = false;
    }

    float xoffset = xpos - game->settings.lastX;
    float yoffset = game->settings.lastY - ypos;

    game->settings.lastX = xpos;
    game->settings.lastY = ypos;

    game->camera->ProcessMouseMovement(xoffset, yoffset);
}
void Game::scroll_callback(GLFWwindow* window, double, double yoffset)
{
    Game* game = static_cast<Game*>(glfwGetWindowUserPointer(window));
    if (!game) return;

    game->camera->ProcessMouseScroll(static_cast<float>(yoffset));
}   



void Game::run()
{
    while(isRunning())
    {
        float currentFrame =
            static_cast<float>(glfwGetTime());

        timer.deltaTime =
            currentFrame - timer.lastFrame;

        timer.lastFrame =
            currentFrame;

        processInput();

        glClearColor(
            settings.bgcolor.r,
            settings.bgcolor.g,
            settings.bgcolor.b,
            settings.bgcolor.a
        );

        glClear(
            GL_COLOR_BUFFER_BIT |
            GL_DEPTH_BUFFER_BIT
        );

        glm::mat4 projection =
            glm::perspective(
                glm::radians(camera->Zoom),
                (float)settings.SCR_WIDTH /
                (float)settings.SCR_HEIGHT,
                0.1f,
                1000.0f
            );

        sun->update(*camera);
        sun->render(*camera, projection);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
}