#include "../include/gameState.h"

#include <websocketpp/config/asio_no_tls.hpp>
#include <websocketpp/server.hpp>

#include <iostream>
#include <string>
#include <mutex>
#include <thread>
#include <vector>
#include <sstream>

typedef websocketpp::server<websocketpp::config::asio> ws_server;

State game_state;
std::mutex state_mutex;


int main() {
    initializePosition(game_state);
    game_state.flags.first.color = 'R';
    game_state.flags.second.color = 'B';
    std::cout << "[server] initial state:\n" << game_state << "\n";
    ws_server server;
    server.set_access_channels(websocketpp::log::alevel::none);
    server.set_error_channels(websocketpp::log::elevel::all);
    server.init_asio();
    server.set_reuse_addr(true);
    server.set_message_handler(
        [&server](websocketpp::connection_hdl hdl, ws_server::message_ptr msg) {
            on_message(&server, hdl, msg);
        }
    );

    server.set_open_handler([](websocketpp::connection_hdl hdl) {
        std::cout << "[server] client connected\n";
    });

    server.set_close_handler([](websocketpp::connection_hdl hdl) {
        std::cout << "[server] client disconnected\n";
    });

    server.listen(9002);
    server.start_accept();

    std::cout << "[server] listening on port 9002 with 8 threads\n";

    const int NUM_THREADS = 8;
    std::vector<std::thread> threads;
    for (int i = 0; i < NUM_THREADS - 1; i++) {
        threads.emplace_back([&server]() {
            server.run();
        });
    }

    server.run();

    for (auto& t : threads) {
        t.join();
    }

    return 0;
}
