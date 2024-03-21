//`timescale 1ns/100ps
`default_nettype none
`define width 8
`define depth 16
`define TEST_BENCH_RUNNING

module test();
    //Test in/out
    reg                             clk         = 0;        // input clock
    reg                             rst_n       = 0;
    reg                             re          = 0;
    reg                             we          = 0;
    reg     [`width-1:0]            dataIn      = 0;
    wire    [`width-1:0]            dataOut;
    wire                            full_flag;
    wire                            almost_full;
    wire                            empty_flag;
    wire                            almost_empty;
    //Test Modules
    fifo #(
        .width( `width ),
        .depth( `depth )
    )
    UUT
    (
        .clk(           clk ),
        .rst_n(         rst_n ),
        .re(            re ),
        .we(            we ),
        .dataIn(        dataIn ),
        .dataOut(       dataOut ),
        .full_flag(     full_flag ),
        .almost_full(   almost_full),
        .empty_flag(    empty_flag ),
        .almost_empty(  almost_empty)
    );

    reg [15:0] tick_counter = 0;
    always begin
      #1 clk <= ~clk;
      tick_counter = tick_counter + 1;
    end

    // Test Setup
    initial begin
        $dumpfile("UUT.vcd");
        $dumpvars(0, test);
        $display("starting fifo_tb.v");
        $display("width: %d \t depth: %d", `width, `depth);
        #5000 $display( "***WARNING*** Forcing simulation to end");
        $finish;
    end

    // Display Results
    always @(posedge clk ) begin
        $display( "%d rst_n:%b\t re:%b\t we:%b\t datain: %d\t dataout: %d\t ff: %b\t ef: %b",
            tick_counter, rst_n, re, we, dataIn, dataOut, full_flag, empty_flag);
    end

    //Test
    reg [15:0] current_test     = 0;
    reg [15:0] current_stage    = 0;

    integer a;
    reg [7:0] r_w_test_len = 5;
    always @(posedge clk) begin
        current_test <= current_test + 1;

        case( current_stage )
        /*  // reuse this block for each test stage
            1: begin
                if( current_test == 0 )
                    $display("new test");
                // test code here
                if( current_test == `depth-1 ) begin
                    current_stage <= current_stage + 1;
                    current_test <= 0;
                end
            end
        */
            0: begin    // reset device
                #1 rst_n <= 1;
                current_stage <= current_stage + 1; // next stage
                current_test <= 0;
            end

            1: begin    // write till full
                if( current_test == 0 ) begin
                    $display("Writing");
                    we <= 1;    // enable writing
                end
                if( almost_full ) begin   // stop when full
                    we <= 0;
                    current_stage <= current_stage + 1; // next stage
                    current_test <= 0;
                end else begin
                    dataIn <= current_test;
                end
            end
            2: begin    // read till empty
                if( current_test == 0 ) begin
                    $display("Reading");
                    dataIn   <= 'bzzzzzzzz;
                    re <= 1;
                end
                if( almost_empty ) begin  // stop when empty
                    re <= 0;
                    current_stage <= current_stage + 1; // next stage
                    current_test <= 0;
                end
            end
            3: begin
                if( current_test == 0 ) begin   // write all zeros to memory
                    $display("clearing Data and resetting");
                    we <= 1;
                    dataIn <= 0;
                end
                if( full_flag ) begin   // stop when full and reset fifo
                    we <= 0;
                    rst_n <= 0;
                end
                if( rst_n == 0 ) begin
                    rst_n <= 1; // end reset
                    current_stage <= current_stage + 1; // next stage
                    current_test <= 0;
                end
            end
            4: begin
                if( current_test == 0 ) begin
                    $display("reading while writing. Loading %d data units", r_w_test_len);
                    we <= 1;
                    re <= 0;
                end
                if( we )
                    dataIn <= current_test;
                if( current_test == r_w_test_len ) begin
                    re <= 1;
                    $display("reading while writing");
                end
                if( current_test == `depth )    // stop at some point
                    we <= 0;

                if( empty_flag && current_test > `depth ) begin  // wait till empty
                    re <= 0;
                    current_stage <= current_stage + 1; // next stage
                    current_test <= 0;
                end
            end
            default: begin
                $display("Test finished Properly");
                $finish;
            end
        endcase
    end

endmodule