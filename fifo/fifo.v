module fifo #(
    parameter width = 4,
    parameter depth = 16
)
(
    input   wire                clk,
    input   wire                rst_n,
    input   wire                re,         // Read Enable
    input   wire                we,         // Write Enable
    input   wire [width-1:0]    dataIn,
    output  wire [width-1:0]    dataOut,
    output  wire                full_flag,
    output  wire                almost_full,
    output  wire                empty_flag,
    output  wire                almost_empty
);

    localparam aw = $clog2(depth);    // address width
    reg     [aw:0]  front   = 0;      // use extra bit in address to test for empty or full
    reg     [aw:0]  back    = 0;

    assign empty_flag   = ( front        == back );
    assign almost_empty = ( front + 1'b1 == back ) || empty_flag;
    assign full_flag    = ( (front[aw] != back[aw]) && (front[aw-1:0] == back[aw-1:0]) );
    assign almost_full  = ( front[aw-1:0] - 1'b1 == back[aw-1:0] ) || full_flag;

    wire    buffer_we;
    assign  buffer_we = we && !full_flag;
    ssram16dp_array #( .width( width ), .depth( depth ) ) 
        buffer( .clk(       clk ), 
                .we(        buffer_we ),
                .raddress(  front[aw-1:0]),
                .waddress(  back[aw-1:0]),
                .dataIn(    dataIn),
                .dataOut(   dataOut)
                );

    `ifdef TEST_BENCH_RUNNING
        reg [width-1:0] last_data_written;
    `endif    
    always @( posedge clk ) begin
        if( !rst_n ) begin
            back    <= 0;
            front   <= 0;
        end else begin
            if( buffer_we ) begin
                back <= back + 1'b1;
            `ifdef TEST_BENCH_RUNNING
                last_data_written <= dataIn;
            `endif 
            end
            if( re && !empty_flag) begin
                front <= front + 1'b1;
            end
        end
    end
endmodule