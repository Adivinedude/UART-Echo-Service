`default_nettype none
`define width 8
`define depth 32

module test();
    //Test in/out
    localparam              aw = $clog2(`depth)-1;
    reg                     clk         = 0;        // input clock
    reg                     we          = 0;
    reg     [aw:0]          raddress    = 0;
    reg     [aw:0]          waddress    = 0;
    reg     [`width-1:0]    dataIn      = 0;
    wire    [`width-1:0]    dataOut;

    //Test Modules
    ssram16dp_array #(
        .width( `width ),
        .depth( `depth )
    )
    UUT
    (
        .clk(       clk ),
        .we(        we ),
        .raddress(  raddress ),
        .waddress(  waddress ),
        .dataIn(    dataIn ),
        .dataOut(   dataOut )
    );
    
    always begin
      #1 clk <= ~clk;
    end

    // Test Setup
    initial begin
        $dumpfile("UUT.vcd");
        $dumpvars(0, test);
        $display("starting ssram16dp_array_tb.v");
        #5000 $display( "***WARNING*** Forcing simulation to end");
        $finish;
    end

    // Display Results
    always @(posedge clk ) begin
        $display( "%d we:%b\t datain:  %d\t waddy: %d\t dataout: %d\t raddy: %d", $time, we, dataIn, waddress, dataOut, raddress);
    end

    //Test
    reg [15:0] current_test     = 0;
    reg [15:0] current_stage    = 0;

    integer a;
    always @(posedge clk) begin
        current_test <= current_test + 1;

        case( current_stage )
        /*
            <test stage here>: begin
                if( current_test == 0 ) // first instance of test here
                    $display("new test");
                // test code here
                if( current_test == `depth-1 ) begin // Go to next stage here
                    current_stage <= current_stage + 1;
                    current_test <= 0;
                end     
            end
        */
            0: begin
                if( current_test == 0 )
                    $display("Writing");
                for( a = 0; a < `depth; a = a + 1 ) begin
                    if( current_test == a) begin
                        we <= 1;
                        waddress <= a;
                        dataIn <= a;
                    end
                end
                if( current_test == `depth-1 ) begin
                    current_stage <= current_stage + 1;
                    current_test <= 0;
                end     
            end
            1: begin
                if( current_test == 0 ) begin
                    $display("Reading");
                    waddress <= 'bzzzzzzzz;
                    dataIn   <= 'bzzzzzzzz;
                end
                for( a = 0; a < `depth; a =  a + 1 ) begin
                    if(current_test == a) begin
                        we <= 0;
                        raddress <= a;
                    end
                end
                if( current_test == `depth-1 ) begin
                    current_stage <= current_stage + 1;
                    current_test <= 0;
                end     
            end 
            2: begin
                if( current_test == 0 )
                    $display("random access");
                raddress <= $urandom % `depth;
                if( current_test == `depth-1 ) begin
                    current_stage <= current_stage + 1;
                    current_test <= 0;
                end     
            end

            default: begin                      
                #2 $display("Test finished Properly");
                $finish;
            end
        endcase
    end

endmodule