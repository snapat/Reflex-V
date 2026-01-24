#include <iostream>
#include <verilated.h>
#include "Vuart_tx.h"

// PARAMETERS FROM SPECIFICATIONS
// 115,200 Baud @ 12.5 MHz = 108.5 clocks per bit [cite: 14, 63, 71]
const int CLOCKS_PER_BIT = 108;

// Helper to step the system clock
void tick(Vuart_tx* top) {
    top->systemClock = 0; top->eval();
    top->systemClock = 1; top->eval();
}

// --- HELPER: SAMPLER FUNCTION ---
// Advances time by 'n' clocks and returns the majority logic level.
int sample_line(Vuart_tx* top, int clocksToWait) {
    int sum = 0;
    for(int i = 0; i < clocksToWait; i++) {
        tick(top);
        sum += top->serialDataOutput;
    }
    // Return majority logic level
    return (sum > (clocksToWait / 2)) ? 1 : 0;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vuart_tx* uart = new Vuart_tx;

    std::cout << "[TEST] Starting UART Verification (Expanded Camel Case)...\n";
    std::cout << "[INFO] Configuration: " << CLOCKS_PER_BIT << " clocks per bit.\n";

    // ==========================================
    // TEST 1: IDLE STATE VERIFICATION
    // ==========================================
    uart->transmitDataValid = 0; 
    uart->transmitByte      = 0x00;
    
    int idleErrors = 0;
    for(int i = 0; i < 100; i++) {
        tick(uart);
        if (uart->serialDataOutput == 0)   idleErrors++; 
        if (uart->isTransmitActive == 1)   idleErrors++; 
    }

    if (idleErrors == 0) {
        std::cout << "[PASS] Idle State: Line High, Active signal Low.\n";
    } else {
        std::cerr << "[FAIL] Idle State Violation detected.\n";
        return 1;
    }

    // ==========================================
    // TEST 2: DATA INTEGRITY (Character 'A')
    // ==========================================
    uint8_t testChar = 0x41; // 'A' (Binary 0100 0001)
    std::cout << "[TEST] Sending Character: 0x41 (LSB First)...\n";

    uart->transmitDataValid = 1;     
    uart->transmitByte      = testChar;
    tick(uart);             
    uart->transmitDataValid = 0;     

    // --- CHECK 1: START BIT ---
    if (sample_line(uart, CLOCKS_PER_BIT) == 0) {
        std::cout << "[PASS] Start Bit Detected.\n";
    } else {
        std::cerr << "[FAIL] Start Bit Missing.\n"; return 1;
    }

    // --- CHECK 2: DATA BITS (LSB -> MSB) ---
    // Expected for 0x41: 1, 0, 0, 0, 0, 0, 1, 0
    int expectedBits[8] = {1, 0, 0, 0, 0, 0, 1, 0};
    for (int i = 0; i < 8; i++) {
        if (sample_line(uart, CLOCKS_PER_BIT) == expectedBits[i]) {
            // Bit matches
        } else {
            std::cerr << "[FAIL] Bit " << i << " Mismatch.\n";
            return 1;
        }
    }
    std::cout << "[PASS] Data Payload Verified.\n";

    // --- CHECK 3: STOP BIT ---
    if (sample_line(uart, CLOCKS_PER_BIT) == 1) {
        std::cout << "[PASS] Stop Bit Detected.\n";
    } else {
        std::cerr << "[FAIL] Stop Bit Missing.\n"; return 1;
    }

    // --- CHECK 4: HANDSHAKE SIGNALS ---
    tick(uart); // Transition to Cleanup/Idle
    if (uart->isTransmitDone == 1 && uart->isTransmitActive == 0) {
        std::cout << "[PASS] Handshake: Done asserted, Active cleared.\n";
    } else {
        std::cerr << "[FAIL] Handshake Signals failed logic check.\n";
        return 1;
    }

    // ==========================================
    // TEST 3: BACK-TO-BACK STRESS TEST
    // ==========================================
    uart->transmitDataValid = 1;
    uart->transmitByte      = 0x55; 
    tick(uart);
    uart->transmitDataValid = 0;

    for(int i = 0; i < 10; i++) tick(uart);

    if (uart->isTransmitActive == 1 && uart->serialDataOutput == 0) {
        std::cout << "[PASS] Stress Test: Back-to-Back restart successful.\n";
    } else {
        std::cerr << "[FAIL] Stress Test: UART failed to restart.\n";
        return 1;
    }

    std::cout << "------------------------------------------\n";
    std::cout << "[SUCCESS] UART Transmitter Verification Complete.\n";

    delete uart;
    return 0;
}