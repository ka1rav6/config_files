#include "../include/Player.h"


Player::Player(int id, float x, float y){
    this->position.x = x;
    this->position.y = y;
    // this->connectToServer(PORT);
    this->uid = id;
}
Player::~Player(){
    delete this;
}
void Player::moveX(){
    this->position.x += x_vel;
}
void Player::moveY(){
    this->position.y += y_vel;
}
