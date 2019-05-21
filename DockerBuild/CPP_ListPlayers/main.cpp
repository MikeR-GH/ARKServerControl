#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

#include <iostream>
#include <string>
#include <regex>

bool parseIPPort(std::string ipport, std::string& ip, int32_t& port)
{
    std::regex regex_base_pattern = std::regex("^([^\\:]*)\\:([^\\:]*)$");
    std::smatch regex_base_match;
    
    if (!std::regex_search(ipport, regex_base_match, regex_base_pattern) || regex_base_match.size() != 3) {
        std::cout << "Error: First argument [IP:PORT] is invalid" << std::endl;
        return false;
    }
    
    std::string str_ip = regex_base_match[1];
    char chr_ip[str_ip.size() + 1];
    strcpy(chr_ip, str_ip.c_str());
    
    std::regex regex_ip_pattern = std::regex("^((?:25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\\.(?:25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\\.(?:25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\\.(?:25[0-5]|2[0-4][0-9]|1?[0-9]{1,2}))$");
    std::cmatch regex_ip_match;
    
    if (!std::regex_match(chr_ip, regex_ip_match, regex_ip_pattern)) {
        std::cout << "Error: Given IP in first argument is invalid." << std::endl;
        return false;
    }
    
    std::string str_port = regex_base_match[2];
    char chr_port[str_ip.size() + 1];
    strcpy(chr_port, str_port.c_str());
    
    std::regex regex_port_pattern = std::regex("^[\\-\\+]?\\d*$");
    std::cmatch regex_port_match;
    
    if (!std::regex_match(chr_port, regex_port_match, regex_port_pattern)) {
        std::cout << "Error: Given Port is not an actual integer" << std::endl;
        return false;
    }
    
    int32_t val_port = std::stoi(str_port);
    
    if (val_port < 0 || val_port > 65535) {
        std::cout << "Error: Given Port is out of range" << std::endl;
        return false;
    }
    
    ip = str_ip;
    port = val_port;
    
    return true;
}

std::string* srp_sendcommand(int32_t sock, std::string command)
{
    // command id is always 770
    /* packet structure:
        4 bytes send_size
        4 bytes send_id
        4 bytes send_type
        n bytes password
        1 byte password 0x00 (null-terminator)
        1 byte body/command 0x00 (null-terminator)
     */
    
    // data definition
    int32_t send_size = 10 + command.length();
    const int32_t send_id = htole32(770);
    const int32_t send_type = htole32(2);
    
    // packet
    int32_t packet_size = (14 + command.length());
    char packet[packet_size + 1];
    memset(packet, 0x00, packet_size);
    
    // pack the packet
    packet[0] = (char)(send_size);
    packet[1] = (char)(send_size >> 8);
    packet[2] = (char)(send_size >> 16);
    packet[3] = (char)(send_size >> 24);
    
    packet[4] = (char)(send_id);
    packet[5] = (char)(send_id >> 8);
    packet[6] = (char)(send_id >> 16);
    packet[7] = (char)(send_id >> 24);
    
    packet[8] = (char)(send_type);
    packet[9] = (char)(send_type >> 8);
    packet[10] = (char)(send_type >> 16);
    packet[11] = (char)(send_type >> 24);
    
    for (int32_t i = 0; i < command.length(); i++) {
        packet[12+i] = command[i];
    }
    
    // Send data and error if necessary
    int32_t sent_bytes = send(sock, packet, packet_size, 0);
    if (sent_bytes != packet_size || sent_bytes == -1) {
        std::cout << "Send of data failed (" << sent_bytes << ")" << std::endl;
        std::cout << "Error [" << errno << "] " << strerror(errno) << std::endl;
        return NULL;
    }
    
    /* Receive */
    
    const int32_t recv_buffer_size = 4096;
    char recv_buffer[recv_buffer_size + 1];
    memset(recv_buffer, 0x00, recv_buffer_size);
    
    int32_t recvd_bytes = recv(sock, recv_buffer, recv_buffer_size, 0);
    
    if (recvd_bytes < 0) {
        std::cout << "Receive of data failed (" << recvd_bytes << ")" << std::endl;
        std::cout << "Error [" << errno << "] " << strerror(errno) << std::endl;
        return NULL;
    } else if (recvd_bytes == 0) {
        std::cout << "Connection closed" << std::endl;
        return NULL;
    }
    
    /* else */
    if (recvd_bytes < 4) {
        std::cout << "Error: Insufficient data response (" << recvd_bytes << "/4 bytes)" << std::endl;
        return NULL;
    }
    
    int32_t recv_packet_size = ((recv_buffer[0]) | (recv_buffer[1] << 8) | (recv_buffer[2] << 16) | (recv_buffer[3] << 24));
    
    /* Validate server response */
    if ((recv_packet_size + 4) > recv_buffer_size) {
        std::cout << "Error: Received given packet size is greater than the actual buffer (" << recv_packet_size << "+4/" << recv_buffer_size << " bytes)" << std::endl;
        return NULL;
    }
    
    if ((recv_packet_size + 4) > recvd_bytes) {
        std::cout << "Error: Received given packet size is greater than the actual received data (" << recv_packet_size << "+4/" << recvd_bytes << " bytes)" << std::endl;
        return NULL;
    }
    
    if (recv_packet_size < 10) {
        std::cout << "Error: Insufficient data response (" << recv_packet_size << "/10 bytes)" << std::endl;
        return NULL;
    }
    
    /* parse ID and Type */
    int32_t recv_packet_id = ((recv_buffer[4]) | (recv_buffer[5] << 8) | (recv_buffer[6] << 16) | (recv_buffer[7] << 24));
    int32_t recv_packet_type = ((recv_buffer[8]) | (recv_buffer[9] << 8) | (recv_buffer[10] << 16) | (recv_buffer[11] << 24));
    
    /* Validate server response */
    if (recv_packet_id != 770) {
        std::cout << "Error: Received wrong response packet id (" << recv_packet_id << "; expected id 770)" << std::endl;
        return NULL;
    }
    if (recv_packet_type != 0) {
        std::cout << "Error: Received wrong packet type (" << recv_packet_type << "; expected type 0)" << std::endl;
        return NULL;
    }
    
    int32_t recv_packet_body_length = (recv_packet_size - 10);
    char recv_packet_body[recv_packet_body_length + 1];
    memset(recv_packet_body, 0x00, recv_packet_body_length);
    
    for (int32_t i = 0; i < recv_packet_body_length; i++) {
        if (recv_buffer[12 + i] == 0x00) {
            std::cout << "Warning: Received null-termination character (0x00) before actual estimated body end (packet offset " << (12 + i) << ")" << std::endl;
            recv_packet_body_length = i;
            break;
        }
        recv_packet_body[i] = recv_buffer[12 + i];
    }
    
    if (recv_buffer[12 + recv_packet_body_length + 1] != 0x00 || recv_buffer[12 + recv_packet_body_length + 2] != 0x00) {
        std::cout << "Warning: Received packet body does not end with expected (2x 0x00) null-terminators" << std::endl;
    }
    
    return new std::string(recv_packet_body, recv_packet_body_length);
}

bool srp_authenticate(int32_t sock, std::string password)
{
    /* packet structure:
        4 bytes send_size
        4 bytes send_id
        4 bytes send_type
        n bytes password
        1 byte password 0x00 (null-terminator)
        1 byte body/password 0x00 (null-terminator)
     */
    
    // data definition
    int32_t send_size = 10 + password.length();
    const int32_t send_id = htole32(1337);
    const int32_t send_type = htole32(3);
    
    // packet
    int32_t packet_size = (14 + password.length());
    char packet[packet_size + 1];
    memset(packet, 0x00, packet_size);
    
    // pack the packet
    packet[0] = (char)(send_size);
    packet[1] = (char)(send_size >> 8);
    packet[2] = (char)(send_size >> 16);
    packet[3] = (char)(send_size >> 24);
    
    packet[4] = (char)(send_id);
    packet[5] = (char)(send_id >> 8);
    packet[6] = (char)(send_id >> 16);
    packet[7] = (char)(send_id >> 24);
    
    packet[8] = (char)(send_type);
    packet[9] = (char)(send_type >> 8);
    packet[10] = (char)(send_type >> 16);
    packet[11] = (char)(send_type >> 24);
    
    for (int32_t i = 0; i < password.length(); i++) {
        packet[12+i] = password[i];
    }
    
    // Send data and error if necessary
    int32_t sent_bytes = send(sock, packet, packet_size, 0);
    if (sent_bytes != packet_size || sent_bytes == -1) {
        std::cout << "Send of data failed (" << sent_bytes << " bytes)" << std::endl;
        std::cout << "Error [" << errno << "] " << strerror(errno) << std::endl;
        return false;
    }
    
    /* Receive */
    
    const int32_t recv_buffer_size = 4096;
    char recv_buffer[recv_buffer_size + 1];
    memset(recv_buffer, 0x00, recv_buffer_size);
    
    int32_t recvd_bytes = recv(sock, recv_buffer, recv_buffer_size, 0);
    
    if (recvd_bytes < 0) {
        std::cout << "Receive of data failed (" << recvd_bytes << " bytes)" << std::endl;
        std::cout << "Error [" << errno << "] " << strerror(errno) << std::endl;
        return false;
    } else if (recvd_bytes == 0) {
        std::cout << "Connection closed" << std::endl;
        return false;
    }
    
    /* else */
    if (recvd_bytes < 4) {
        std::cout << "Error: Insufficient data response (" << recvd_bytes << "/4 bytes)" << std::endl;
        return false;
    }
    
    int32_t recv_packet_size = ((recv_buffer[0]) | (recv_buffer[1] << 8) | (recv_buffer[2] << 16) | (recv_buffer[3] << 24));
    
    /* Validate server response */
    if (recv_packet_size != 10 || recvd_bytes != 14) {
        std::cout << "Error: Recieved packet is not 10/14 bytes long (" << recv_packet_size << "/" << recvd_bytes << " bytes)" << std::endl;
        return false;
    }
    
    /* parse ID and Type */
    int32_t recv_packet_id = ((recv_buffer[4]) | (recv_buffer[5] << 8) | (recv_buffer[6] << 16) | (recv_buffer[7] << 24));
    int32_t recv_packet_type = ((recv_buffer[8]) | (recv_buffer[9] << 8) | (recv_buffer[10] << 16) | (recv_buffer[11] << 24));
    
    /* Validate server response */
    if (recv_packet_type != 2) {
        std::cout << "Error: Recieved wrong packet type (" << recv_packet_type << "; expected type 2)" << std::endl;
        return false;
    }
    
    if (recv_packet_id == -1) {
        std::cout << "Failed to authenticate" << std::endl;
    } else if (recv_packet_id != send_id) {
        std::cout << "Error: Recieved unexpected/invalid packet id (" << recv_packet_id << ")" << std::endl;
        return false;
    }
    
    return true;
}

int listplayers(std::string remote_addr, int32_t remote_port, std::string password, bool displayProfileUrl = false)
{
    // Copy remote_addr to remote_addr_chr
    char remote_addr_chr[remote_addr.size() + 1];
    strcpy(remote_addr_chr, remote_addr.c_str());
    
    /*** Prepare Server-Address ***/
    struct sockaddr_in server_addr;
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(remote_port);
    
    if (inet_pton(AF_INET, remote_addr_chr, &server_addr.sin_addr) != 1) {
        std::cout << "Error: Failed to convert IPv4-Address" << std::endl;
        return 3;
    }
    
    int32_t sock;
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        std::cout << "Connection failed (" << sock << ")" << std::endl;
        std::cout << "Socket Error [" << errno << "] " << strerror(errno) << std::endl;
        return 3;
    }
    
    int32_t con;
    if ((con = connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr))) != 0) {
        std::cout << "Connection failed (" << con << ")" << std::endl;
        std::cout << "Socket Error [" << errno << "] " << strerror(errno) << std::endl;
        return 3;
    }
    
    if (!srp_authenticate(sock, password)) {
        std::cout << "Authentication failed" << std::endl;
        return 5;
    }
    
    /* issue command 'ListPlayers' */
    std::string* cmd_result1 = srp_sendcommand(sock, "ListPlayers");
    if (cmd_result1 == NULL) {
        std::cout << "Failed to issue command" << std::endl;
        close(sock);
        return 6;
    } else {
        std::ostringstream listplayers_replacement_ostream;
        listplayers_replacement_ostream << "$1. ";
        if (displayProfileUrl) {
            listplayers_replacement_ostream << "https://steamcommunity.com/profiles/";
        }
        listplayers_replacement_ostream << "$3 ($2)\n";
        std::string listplayers_replacement = listplayers_replacement_ostream.str();
        
        
        std::regex regex_listplayers_pattern = std::regex("([0-9]+)\\. (.*?)\\, ([0-9]+)");
        std::cout << std::regex_replace(*cmd_result1, regex_listplayers_pattern, listplayers_replacement, std::regex_constants::format_no_copy);
    }
    
    if (close(sock) != 0) {
        std::cout << "Failed to close connection" << std::endl;
        std::cout << "Error [" << errno << "] " << strerror(errno) << std::endl;
    }
    
    return 0;
}

int main(int argc, char const *argv[])
{
    if (argc <= 1 || (argc == 2 && strcmp(argv[1], "--help"))) {
        if (argc <= 1) {
            std::cout << "Error: Missing first argument. IPv4-Address and Port must be given. [IP:PORT]" << std::endl;
            return 1;
        }
        std::cout << argv[0] << " [IP:PORT] [PASSWORD]" << std::endl;
        return 0;
    } else if (argc == 2) {
        std::cout << "Error: Missing second argument. Rcon-Password must be given." << std::endl;
        return 1;
    }
    
    std::string addr_ip;
    int32_t addr_port = 0;
    if (!parseIPPort(argv[1], addr_ip, addr_port)) {
        return 1;
    }
    
    return listplayers(addr_ip, addr_port, argv[2], (argc == 4 && (strcmp(argv[3], "--profile-url") || strcmp(argv[3], "--url"))));
}
