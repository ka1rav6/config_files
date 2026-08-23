#include "../include/Player.h"


Player::Player(float x, float y){
    this->position.x = x;
    this->position.y = y;
    // this->connectToServer(PORT);
    this->uid = 
}
Player::~Player(){
    delete this;
}
