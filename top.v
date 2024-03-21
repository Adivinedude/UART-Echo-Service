`default_nettype none
`include "uart/uart_include.v"
module top(
    input   wire            clk,
    output  wire            uartTx,
    input   wire            uartRx,
    output  wire    [5:0]   led,
    input   wire            btn1
);
    wire error;
    // tx in/out
    reg     [7:0]       tx_data = 8'hFF;     // Data to send
    wire    [7:0]       rx_data;
    reg                 txWrite = 0;
    //reg                 rxRead  = 0;
    wire                tx_empty;
    wire                tx_almost_empty;
    wire                tx_full;
    wire                tx_almost_full;
    wire                rx_empty;
    wire                rx_almost_empty;
    wire                rx_full;
    wire                rx_almost_full;
    // rx in/out
    reg     [2:0]       config_address = 0;
    reg     [`UART_CONFIG_WIDTH_DELAYFRAMES-1:0]   config_value = 0;
    reg                 config_store_data = 0;

    //Test Modules
    `ifdef TEST_BENCH_RUNNING
        `define UUT_TOP_DELAY 300
    `else
        `define UUT_TOP_DELAY 2812
    `endif

    uart #(
        .DELAY(         `UUT_TOP_DELAY), // 2812), // 27*10^6 / 9600 = 2812.5
        .DATABITS(      8),
        .PARITY(        `UART_PARITY_EVEN),     
        .STOPBIT(       `UART_STOPBITS_2),    
        .RX_BUF_SIZE(   16),
        .TX_BUF_SIZE(   16),
        .DATA_WIDTH(    8)
    )
    UUT_TOP(
        // pins
        .clk(       clk),
        .rst_n(     btn1_ff),
        .rx_pin(    uartRx),
        .tx_pin(    uartTx),
        // rx ports
        .rx_data(   rx_data),  // Data Out
        //.rx_read(   rxRead),       // Word has been read, Pulse high to read the next word
        .rx_read( txWrite ),
        .rx_empty(  rx_empty),      // Rx buffer is empty on HIGH (when low, rxData is valid)
        .rx_almost_empty( rx_almost_empty ),
        .rx_full(   rx_full),       // Rx buffer is full on HIGH
        .rx_almost_full( rx_almost_full),
        // tx ports
        .tx_data(   rx_data),   // Data In
        .tx_write(  txWrite),       // Data ready to store, Pulse high write the next word
        .tx_empty(  tx_empty),      // Tx buffer is empty on HIGH
        .tx_almost_empty( tx_almost_empty),
        .tx_full(   tx_full),       // Rx buffer is full on HIGH (attempts to write data will fail)
        .tx_almost_full( tx_almost_full),
        // config ports
        .config_address(config_address),        // Configuration Register Address - see 'uart_include.v'
        .config_value(config_value),            // Configuration Value
        .config_store_data(config_store_data)   // Configuration Clk. Data stored on posedge

        ,.error(error)
    );

// Setup tick counter and second ticker
    `ifdef TEST_BENCH_RUNNING
        `define tick_c_width 17
        `define tick_reset_value 'd65000;
    `else
        `define tick_c_width $clog2(27000000)-1
        `define tick_reset_value 'd26999999
    `endif
    reg [`tick_c_width:0]   tick_counter    = `tick_reset_value;
    reg                     second_ticker   = 0;
    always @( posedge clk ) begin
        if( !btn1_ff ) begin
            second_ticker   <= 0;
            tick_counter    <= 0;
        end else begin
            if( second_ticker )
                second_ticker <= 0;
            tick_counter <= tick_counter - 1'b1;
            if( tick_counter == 0 ) begin
                tick_counter <= `tick_reset_value;
                second_ticker <= 1;
            end
        end
    end

// synchronize button input
    reg     btn1_1 = 0;
    reg     btn1_ff = 0;
    always @( posedge clk ) begin
        // buffer the reset button.
        btn1_1  <= btn1;
        btn1_ff <= btn1_1;
    end

// drive leds
    reg     [5:0] led_reg = 0;
    assign led = led_reg;
    reg [`tick_c_width:0] rx_timer = 0;
    reg [`tick_c_width:0] tx_timer = 0;
    reg                   rx_led = 0;
    reg                   tx_led = 0;
    always @( posedge clk ) begin
        if( !btn1_ff ) begin
            led_reg <= 0;
        end else begin
            led_reg <= ~{/*tx_led,*/error, rx_led, rx_full, rx_almost_full, rx_almost_empty, rx_empty};
            if( !rx_led ) begin
                if( !uartRx ) begin
                    rx_led <= 1;
                    rx_timer <= tick_counter;
                end
            end else if ( tick_counter == rx_timer ) begin
                rx_led <= 0;
            end
            if( !tx_led ) begin
                if( !uartTx ) begin
                    tx_led <= 1;
                    tx_timer <= tick_counter;
                end
            end else if ( tick_counter == tx_timer ) begin
                tx_led <= 0;
            end
        end
    end

// Echo Service
    reg write_all_data = 0;
    always @( posedge clk ) begin : LABLE_ECHO_SERVICE
        // reset button
        if( !btn1_ff ) begin
             txWrite <= 0;
             write_all_data <= 0;
        end else begin
            if( txWrite && (tx_almost_full || tx_full || rx_almost_empty || rx_empty) ) begin
                txWrite <= 0;
            end else if ( write_all_data ) begin
                if( !tx_full && !rx_empty )
                    txWrite <= 1;
            end
            if( (second_ticker && !rx_empty) || rx_full ) begin
                write_all_data <= 1;
            end else if( rx_empty ) begin
                write_all_data <= 0;
            end
        end
    end
endmodule