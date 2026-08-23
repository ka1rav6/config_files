#ifndef PLAYER_H
#define PLAYER_H


//includes
#include "Point.h"

class Player{
public:
    Point position;
    Player();
    ~Player();
    void connectToServer();
    void disconnect();
private:
    unsigned int uid;
    float x_vel = 10;
    float y_vel = 10;
    
};

#endif
