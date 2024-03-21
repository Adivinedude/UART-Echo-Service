`default_nettype none
`include "uart/uart_include.v"
`define TEST_BENCH_RUNNING
module test();
    //Test in/out
    reg                 clk = 0;        // input clock
    reg                 rst_n = 0;
    // tx in/out
    wire                uart_txpin;     // output tx pin
    reg    [15:0]       datain = 0;     // Data to send
    reg                 txwrite = 0;
    reg                 rxread = 0; 
    wire                tx_empty;
    wire                tx_almost_empty;
    wire                tx_full;
    wire                tx_almost_full;
    wire                rx_empty;
    wire                rx_almost_empty;
    wire                rx_full;
    wire                rx_almost_full;
    // rx in/out
    wire   [15:0]       dataout;
    reg     [2:0]       config_address;
    reg     [`UART_CONFIG_WIDTH_DELAYFRAMES-1:0]   config_value;
    reg                 config_store_data;

    //Test Modules
    uart #(
        .DELAY(         300),
        .DATABITS(      8),
        .PARITY(        1),     
        .STOPBIT(       0),    
        .RX_BUF_SIZE(   16),
        .TX_BUF_SIZE(   16)
    )
    UUT(
        // pins
        .clk(               clk),
        .rst_n(             rst_n),
        .rx_pin(            uart_txpin),
        .tx_pin(            uart_txpin),
        // rx ports
        .rx_data(           dataout),      // Data Out
        .rx_read(           rxread),       // Word has been read, Pulse high to read the next word
        .rx_empty(          rx_empty),      // Rx buffer is empty on HIGH (when low, rxData is valid)
        .rx_almost_empty(   rx_almost_empty),
        .rx_full(           rx_full),       // Rx buffer is full on HIGH
        .rx_almost_full(    rx_almost_full),
        // tx ports
        .tx_data(           datain),       // Data In
        .tx_write(          txwrite),      // Data ready to store, Pulse high write the next word
        .tx_empty(          tx_empty),      // Tx buffer is empty on HIGH
        .tx_almost_empty(   tx_almost_empty),
        .tx_full(           tx_full),       // Rx buffer is full on HIGH (attempts to write data will fail)
        .tx_almost_full(    tx_almost_full),
        // config ports
        .config_address(    config_address),    // Configuration Register Address - see 'uart_include.v'
        .config_value(      config_value),      // Configuration Value
        .config_store_data( config_store_data)  // Configuration Clk. Data stored on posedge
    );

    // Test Clock
    always begin
        #1 clk <= ~clk;
    end

    // Test Setup
    initial begin
        $dumpfile("UUT.vcd");
        $dumpvars(0, test);
        $display("starting uart_tb.v");
        #4 rst_n <= 1;
        #400000 $display( "***WARNING*** Forcing simulation to end");
        $finish;
    end

    // Display Results
    reg [15:0] result_counter = 0;
    always @(posedge clk) begin
            if( rxread ) begin
                rxread <= 0;
            end else if( !rx_empty ) begin
                rxread <= 1;
                $display( "%d\t dataout: %d", $time, dataout );
                result_counter <= result_counter + 1;
            end
    end
    // test tracker value
    reg [15:0] current_test = 1;
    // TX Test
    always @(posedge clk) begin
        if( !tx_almost_full && rst_n && current_test <= 50) begin
            $display("Write: %d", current_test );
            current_test <= current_test + 1;
            datain  <= current_test;
            txwrite <= 1;
        end else begin
            txwrite <= 0;
        end

        if( result_counter == 50) begin
            $display("Test finished Properly");
            $finish;
        end 
    end
endmodule