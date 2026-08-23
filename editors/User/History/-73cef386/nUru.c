#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>

int main(int argc, char** argv){
    int socket_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (socket_fd == -1){
        perror("Socket initialization failed!");
    }

    return EXIT_SUCCESS;
}

