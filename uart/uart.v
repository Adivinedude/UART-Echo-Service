/*
// Top Down View
//     uart \
//         - uart_config
//         \ uart_rx_fifo
//             - uart_rx
//         \ uart_tx_fifo
//             - uart_tx
// This module ties together the rx and tx modules with 2 FIFO buffers for sending and receiving
// data using the uart protocol.
// ToDo: 
//  1) implement flow control
//  2) implement half duplex mode
*/

`default_nettype none
`include "uart/uart_include.v"
module uart
#(
    parameter   COUNTER_WIDTH   = `UART_CONFIG_WIDTH_DELAYFRAMES,
    parameter   DATA_WIDTH      = `UART_CONFIG_WIDTH_DATABITS,
    parameter   MODE            = `UART_FULL_DUPLEX,       
    parameter   DELAY           = 2812, // Buad rate 9600 @ 27MHz
    parameter   DATABITS        = 8,    // 8 Bits per frame
    parameter   PARITY          = `UART_PARITY_NONE,     
    parameter   STOPBIT         = `UART_STOPBITS_1,    
    parameter   FLOW            = `UART_FLOWCTRL_NONE,
    parameter   RX_BUF_SIZE     = `UART_CONFIG_FIFO_DEPTH,
    parameter   TX_BUF_SIZE     = `UART_CONFIG_FIFO_DEPTH
)
(
    // pins
    input   wire                        clk,
    input   wire                        rst_n,
    input   wire                        rx_pin,
    output  wire                        tx_pin,
    // rx ports
    output  wire    [DATA_WIDTH - 1:0]  rx_data,     // Data Out
    input   wire                        rx_read,     // Word has been read, Pulse high to read the next word
    output  wire                        rx_empty,   // Rx buffer is empty on HIGH (when low, rxData is valid)
    output  wire                        rx_almost_empty,
    output  wire                        rx_full,    // Rx buffer is full on HIGH
    output  wire                        rx_almost_full,
    // tx ports
    input   wire    [DATA_WIDTH - 1:0]  tx_data,     // Data In
    input   wire                        tx_write,    // Data ready to store, Pulse high write the next word
    output  wire                        tx_empty,   // Tx buffer is empty on HIGH
    output  wire                        tx_almost_empty,
    output  wire                        tx_full,    // Rx buffer is full on HIGH (attempts to write data will fail)
    output  wire                        tx_almost_full,
    // config ports
    input   wire [2:0]                  config_address,     // Configuration Register Address - see 'uart_include.v'
    input   wire [COUNTER_WIDTH - 1:0]  config_value,       // Configuration Value
    input   wire                        config_store_data   // Configuration Clk. Data stored on posedge

    ,output wire error
);
    assign error = uart_rx_error;
// Wires to connect the config settings to the devices
    wire                        config_mode;
    wire [COUNTER_WIDTH - 1:0]  config_delay;
    wire [4:0]                  config_databits;
    wire [1:0]                  config_parity;
    wire [1:0]                  config_stopbit;
    wire [2:0]                  config_flowctrl;
// Configuration module
    UART_CONFIG_REGISTER #(
        .COUNTER_WIDTH( COUNTER_WIDTH ),
        .MODE(          MODE ),
        .DELAY(         DELAY ),
        .DATABITS(      DATABITS ),
        .PARITY(        PARITY ),
        .STOPBIT(       STOPBIT ),
        .FLOW(          FLOW )
    ) 
    uart_cfg
    (
        .clk(                       clk),
        .address(                   config_address ),
        .value(                     config_value ),
        .store_data(                config_store_data ),
        .UART_CONFIG_DELAY_FRAMES(  config_delay ),
        .UART_CONFIG_MODE(          config_mode ),
        .UART_CONFIG_DATABITS(      config_databits ),
        .UART_CONFIG_PARITY(        config_parity ),
        .UART_CONFIG_STOPBITS(      config_stopbit ),
        .UART_CONFIG_FLOWCTRL(      config_flowctrl )
    );

// Wires to connect to the RX module
    wire    [DATA_WIDTH-1:0]    uart_rx_dataOut;
    wire                        uart_rx_ready;
    wire                        uart_rx_error;
    wire                        uart_rx_write_to_fifo;
// Rx Module
    uart_rx #(.DATA_WIDTH(DATA_WIDTH)) rx(
        .clk(                       clk ),
        .uart_rxpin(                rx_pin ),
        .dataout(                   uart_rx_dataOut ),
        .uart_rx_ready(             uart_rx_ready ),
        .uart_rx_error(             uart_rx_error ),
        .rst_n(                     rst_n ),
        .UART_CONFIG_DELAY_FRAMES(  config_delay ),
        .UART_CONFIG_DATABITS(      config_databits ),
        .UART_CONFIG_PARITY(        config_parity ),
        .UART_CONFIG_STOPBITS(      config_stopbit )
    );
// rx memory
    fifo #(
        .width( DATA_WIDTH ),
        .depth( RX_BUF_SIZE )
    ) 
    rxBuffer (
        .clk(           clk ),
        .rst_n(         rst_n ),
        .re(            rx_read ),
        //.we(            uart_rx_write_to_fifo ),
        .we(            uart_rx_ready ),
        .dataIn(        uart_rx_dataOut ),
        .dataOut(       rx_data ),
        .full_flag(     rx_full ),
        .almost_full(   rx_almost_full),
        .empty_flag(    rx_empty ),
        .almost_empty(  rx_almost_empty)
    );    
    assign uart_rx_write_to_fifo = uart_rx_ready && !uart_rx_error;
    
// Wires to connect Tx Module
    wire    [DATA_WIDTH-1:0]    uart_tx_dataIn;
    wire                        uart_tx_txReady;
    reg                         tx_send = 0;
// Tx Module
    uart_tx #(.DATA_WIDTH(DATA_WIDTH)) tx(
        .clk(                       clk ),
        .uart_txpin(                tx_pin ),
        .datain(                    uart_tx_dataIn ),
        .send_tx(                   tx_send ),
        .uart_tx_ready(             uart_tx_txReady ),
        .rst_n(                     rst_n ),
        .UART_CONFIG_DELAY_FRAMES(  config_delay ),
        .UART_CONFIG_DATABITS(      config_databits ),
        .UART_CONFIG_PARITY(        config_parity ),
        .UART_CONFIG_STOPBITS(      config_stopbit )
    );
// tx memory
    fifo #(
        .width( DATA_WIDTH ),
        .depth( TX_BUF_SIZE )
    )
    txBuffer(
        .clk(           clk ),
        .rst_n(         rst_n ),
        .re(            tx_send),
        .we(            tx_write ),
        .dataIn(        tx_data ),
        .dataOut(       uart_tx_dataIn ),
        .full_flag(     tx_full ),
        .almost_full(   tx_almost_full),
        .empty_flag(    tx_empty ),
        .almost_empty(  tx_almost_empty)
    );
    // Send data stored in tx buffer when its available and tx is ready
    always @( posedge clk ) begin
        if( tx_send ) begin
            tx_send  <= 0;
        end else if( uart_tx_txReady && ~tx_empty ) begin
            tx_send <= 1;
        end
    end
endmodule