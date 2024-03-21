`default_nettype none
//`timescale 1ns/500ps

// `define UART_TX_SEND_ERROR_FOR_DEBUGGING

module test();
    //Test in/out
    reg                 clk = 0;        // input clock
    reg                 rst = 0;
    // tx in/out
    wire                uart_txpin;     // output tx pin
    reg    [7:0]        datain = 0;     // Data to send
    reg                 send_tx = 0;    // Trigger to start sending data
    wire                uart_tx_ready;  // ready flag, HIGH when ready for new data. LOW when sending
    reg                 send_error = 0;
    // rx in/out
    wire   [7:0]        dataout;
    wire                Error;
    wire                uart_rx_ready;  
    // config settings
    reg   [12:0]  UART_CONFIG_DELAY_FRAMES  = 300;
    reg   [4:0]   UART_CONFIG_DATABITS      = 8;
    reg   [1:0]   UART_CONFIG_PARITY        = 0;
    reg   [1:0]   UART_CONFIG_STOPBITS      = 0;
    reg   [2:0]   UART_CONFIG_FLOWCTRL      = 0;

    // test tracker value
    reg [15:0] current_test = 1;

    //Test Modules
    uart_tx #(.DATA_WIDTH(8)) uut_tx(
        .clk( clk ),
        .uart_txpin( uart_txpin ),
        .datain( datain ),
        .send_tx( send_tx ),
        .uart_tx_ready( uart_tx_ready ),
        .rst_n( rst ),
        .UART_CONFIG_DELAY_FRAMES(  UART_CONFIG_DELAY_FRAMES ),
        .UART_CONFIG_DATABITS(      UART_CONFIG_DATABITS ),
        .UART_CONFIG_PARITY(        UART_CONFIG_PARITY ),
        .UART_CONFIG_STOPBITS(      UART_CONFIG_STOPBITS )
`ifdef UART_TX_SEND_ERROR_FOR_DEBUGGING
        ,.send_error_for_debug(    send_error  )
`endif
        );

    uart_rx #(.DATA_WIDTH(8)) uut_rx(
        .clk( clk ),
        .uart_rxpin( uart_txpin ),
        .dataout( dataout ),
        .uart_rx_ready( uart_rx_ready ),
        .uart_rx_error( Error ),
        .rst_n( rst ),
        .UART_CONFIG_DELAY_FRAMES(  UART_CONFIG_DELAY_FRAMES ),
        .UART_CONFIG_DATABITS(      UART_CONFIG_DATABITS ),
        .UART_CONFIG_PARITY(        UART_CONFIG_PARITY ),
        .UART_CONFIG_STOPBITS(      UART_CONFIG_STOPBITS )
        );

    // Test Clock
    always begin
        #1 clk <= ~clk;
    end

    // Test Setup
    initial begin
        $dumpfile("UUT.vcd");
        $dumpvars(0, test);
        $display("starting uart_rx_tx_tb.v");
        #5 rst <= 1;
        #100000 $display( "***WARNING*** Forcing simulation to end");
        $finish;
    end

    // Display Results
    always @(posedge uart_rx_ready) begin
        $display( "%d\t dataout: %d\t Error: %b", $time, dataout, Error );
    end
    // TX Test
    always @(posedge uart_tx_ready) begin
        current_test <= current_test + 1;
        case( current_test )
            0: $display("***Error*** You can not set current_test to 0zero");
            1:  begin
                UART_CONFIG_PARITY        <= 1;
                UART_CONFIG_STOPBITS      <= 2;
                datain                    = 8'b00000001;
                send_tx <= 1;
                $display("%d\t datain: %d", $time, datain );
            end
            default: begin
                datain  = current_test;//$urandom % 255;
                send_tx <= 1;
                $display("%d\t datain: %d", $time, datain );
                // send_error <= ~send_error;
            end
        endcase
        if( current_test > 50 ) begin
            $display("Test finished Properly");
            #16 $finish;
        end        
        //if( current_test > 0 )
        //    $display( "Starting Test %d", current_test);

    end

    // send_tx Reset - Keep it held high until the tx module has received it
    always @(posedge clk) begin
      if( uart_tx_ready == 0 )
        send_tx <= 0;
    end

endmodule