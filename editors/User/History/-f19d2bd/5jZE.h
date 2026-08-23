#ifndef PLAYER_H
#define PLAYER_H


//includes
#include "Point.h"

class Player{
public:
    Point position;
    Player();
    Player(int id, float x, float y);
    Player(int id, Point pos);
    ~Player();
    void connectToServer(const int PORT);
    void disconnect();
    void moveUp();
    void moveDown();
    void moveRight();
    void moveLeft();
    unsigned int getId() const { 
        return uid;
    }

    friend std::ostream& operator<<(std::ostream& os, const Player& f) {
        return os << "Unique ID: " << f.uid << " Position: " << f.position << " " << "\n";
    }    
    friend std::istream& operator>>(std::istream& is, Player& f) {
        return is >> f.position >> f.uid;
    }

private:
    unsigned int uid;
    float x_vel = 10;
    float y_vel = 10;

    
};

#endif
