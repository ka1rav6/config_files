#ifndef PLAYER_H
#define PLAYER_H


//includes
#include "Point.h"

class Player{
public:
    Point position;
    Player(int id, float x, float y);
    ~Player();
    void connectToServer(const int PORT);
    void disconnect();
    void moveX();
    void moveY();
private:
    unsigned int uid;
    float x_vel = 10;
    float y_vel = 10;
    
};

#endif
