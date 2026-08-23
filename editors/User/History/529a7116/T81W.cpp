#include "../include/gameState.h"

#include <websocketpp/config/asio_no_tls_client.hpp>
#include <websocketpp/client.hpp>

#include <iostream>
#include <string>
#include <thread>
#include <atomic>

typedef websocketpp::client<websocketpp::config::asio_client> ws_client;
std::atomic<bool> connected(false);
ws_client* global_client = nullptr;
websocketpp::connection_hdl global_hdl;

void on_message(websocketpp::connection_hdl hdl, ws_client::message_ptr msg) {
    std::string payload = msg->get_payload();
    State state = deserializeState(payload);
    std::cout << "\n--- Server State ---\n";
    std::cout << state;
    std::cout << "--------------------\n";
    std::cout << "> " << std::flush;
}
void on_open(websocketpp::connection_hdl hdl) {
    std::cout << "[client] connected to server\n";
    std::cout << "> " << std::flush;
    global_hdl = hdl;
    connected.store(true);
}
void on_close(websocketpp::connection_hdl hdl) {
    std::cout << "[client] disconnected from server\n";
    connected.store(false);
}

void on_fail(websocketpp::connection_hdl hdl) {
    std::cerr << "[client] connection failed\n";
    connected.store(false);
}

void input_loop() {
    std::string line;
    while (std::getline(std::cin, line)) {
        if (!connected.load()) {
            std::cerr << "[client] not connected\n";
            continue;
        }
        if (line.empty()) continue;
        if (line == "quit" || line == "exit") {
            global_client->close(global_hdl, websocketpp::close::status::going_away, "client exit");
            break;
        }

        websocketpp::lib::error_code ec;
        global_client->send(global_hdl, line, websocketpp::frame::opcode::text, ec);
        if (ec) {
            std::cerr << "[client] send error: " << ec.message() << "\n";
        }
    }
}

int main() {
    ws_client client;
    global_client = &client;
    client.set_access_channels(websocketpp::log::alevel::none);
    client.set_error_channels(websocketpp::log::elevel::all);
    client.init_asio();
    client.set_message_handler(&on_message);
    client.set_open_handler(&on_open);
    client.set_close_handler(&on_close);
    client.set_fail_handler(&on_fail);
    websocketpp::lib::error_code ec;
    ws_client::connection_ptr con = client.get_connection("ws://localhost:9002", ec);
    if (ec) {
        std::cerr << "[client] connection error: " << ec.message() << "\n";
        return 1;
    }

    client.connect(con);
    std::thread input_thread(input_loop);
    client.run();
    if (input_thread.joinable())
        input_thread.join();
    return 0;
}
