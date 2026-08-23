#ifndef PLAYER_H
#define PLAYER_H


//includes
#include "point.h"

class Player{
    Point position;
    unsigned int uid;
    float x_vel = 10;
    float y_vel = 10;
    Player();
    ~Player();
    void connectToServer();
    void disconnect();
    
};

#endif
