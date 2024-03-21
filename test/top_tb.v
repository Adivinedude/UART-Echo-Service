`default_nettype none
`include "uart/uart_include.v"
`define TEST_BENCH_RUNNING
`define how_many_to_send 16

module test();
    //Test in/out
    reg                 clk = 0;        // input clock
    wire                txPin;          // output tx pin
    wire                rxPin;// = 1;
    wire    [5:0]       led;
    reg                 btn1 = 1;

    reg                 send_tx = 0;
    reg     [7:0]       dataIn = 1;
    wire                txReady;

    uart_tx #(.DATA_WIDTH(8)) tx(
        .clk(                       clk ),
        .uart_txpin(                rxPin ),
        .datain(                    dataIn ),
        .send_tx(                   send_tx ),
        .uart_tx_ready(             txReady ),
        .rst_n(                     btn1 ),
        .UART_CONFIG_DELAY_FRAMES(  300 ),
        .UART_CONFIG_DATABITS(      8 ),
        .UART_CONFIG_PARITY(        2 ),
        .UART_CONFIG_STOPBITS(      2 )
    );
    //Test Modules
    top UUT(
        // pins
        .clk(       clk ),
        .uartRx(    rxPin ),
        .uartTx(    txPin ),
        .led(       led ),
        .btn1(      btn1)
    );

`ifdef TEST_BENCH_RUNNING
    // Test Clock
    always begin
        #1 clk <= ~clk;
    end

    // Test Setup
    initial begin
        $dumpfile("UUT.vcd");
        $dumpvars(0, test);
        $display("starting top_tb.v");
        #1 btn1 <= 0;
        #10 btn1 <= 1;
        #1000000 $display( "***WARNING*** Forcing simulation to end");
        $finish;
    end
    always @( negedge UUT.UUT_TOP.rx.uart_rx_ready )
        $display( "%d Recv: %h", $time, UUT.UUT_TOP.rx.dataout);

    always @( negedge UUT.UUT_TOP.tx.send_tx ) begin
        $display( "%d Tx: %h", $time, UUT.UUT_TOP.tx.datain );
        if( UUT.UUT_TOP.tx.datain == `how_many_to_send )
            #20000 $finish;
    end
`endif

    reg [15:0] clk_counter = 0;
    always @(posedge clk) begin : main_loop
        clk_counter <= clk_counter + 1;
        if( dataIn == `how_many_to_send + 'd1 ) begin
            send_tx <= 0;
            disable main_loop;
        end
        if( txReady && !send_tx  ) begin
            $display("%d Sending: %h", $time, dataIn );
            send_tx <= 1;
        end else
            send_tx <= 0;
        if( send_tx )
            dataIn <= dataIn + 1'b1;
    end

    integer rx_count = 0;
    integer tx_count = 0;
    always @( posedge UUT.UUT_TOP.rx.uart_rx_ready or negedge UUT.UUT_TOP.rx.rst_n) begin
        if( !UUT.UUT_TOP.rx.rst_n )
            rx_count = 0;
        else
            rx_count = rx_count + 1;
    end
    always @( posedge UUT.UUT_TOP.tx.uart_tx_ready or negedge UUT.UUT_TOP.tx.rst_n) begin
        if( !UUT.UUT_TOP.tx.rst_n )
            tx_count = 0;
        else
            tx_count = tx_count + 1;
    end

endmodule