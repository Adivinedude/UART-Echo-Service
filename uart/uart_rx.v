/* This module implements a multi-sample uart input. 
'uart_rx_ready' will go high for 1 clk cycle when dataout is valid.
dataout will stay valid until the next transmission is complete 
input clock frequency buts be clk_freq > 1 ÷ [1 ÷ (brad_rate × sample_count)]
*/

`include "uart/uart_include.v"
module uart_rx
#(
    parameter COUNTER_WIDTH       = `UART_CONFIG_WIDTH_DELAYFRAMES,
    parameter DATA_WIDTH          = `UART_CONFIG_WIDTH_DATABITS,
    parameter SAMPLE_COUNT        = 16 // number of samples taken per bit of a frame
)
(
    input   wire                    clk,
    input   wire                    uart_rxpin,     // input rx pin
    output  reg [DATA_WIDTH-1:0]    dataout,        // output data, only valid after uart_rx_ready goes high
    output  reg                     uart_rx_ready,  // dataout is valid on HIGH, duration 1 clk cycle
    output  reg                     uart_rx_error,  // Transmission contained a parity error
    input   wire                    rst_n,
    // config settings
    input   wire[COUNTER_WIDTH-1:0] UART_CONFIG_DELAY_FRAMES,  // see 'uart_include.v' for details
    input   wire[4:0]               UART_CONFIG_DATABITS,      
    input   wire[1:0]               UART_CONFIG_PARITY,         
    input   wire[1:0]               UART_CONFIG_STOPBITS
);
    // rx states
    localparam RX_STATE_IDLE        = 5'b00001; `define RX_STATE_IDLE_BIT   0
    localparam RX_STATE_START       = 5'b00010; `define RX_STATE_START_BIT  1
    localparam RX_STATE_READ        = 5'b00100; `define RX_STATE_READ_BIT   2
    localparam RX_STATE_STOP        = 5'b01000; `define RX_STATE_STOP_BIT   3
    reg [3:0]  rxstate              = RX_STATE_IDLE;

    initial begin
        uart_rx_ready   <= 0;
        uart_rx_error   <= 0;
        dataout         <= 0;
    end
// uartRx pin buffer
    reg rxPin_FF_0  = 1;
    reg rxPin_FF    = 1;
    always @( posedge clk ) begin
        rxPin_FF_0  <= uart_rxpin;
        rxPin_FF    <= rxPin_FF_0;
    end
/////////////
// Main Clock
    reg [COUNTER_WIDTH-1:0] rxCounter = 1;
    always @( posedge clk ) begin
        rxCounter <= rxCounter - 1'b1;
        if( rxCounter == 0 || rxstate[`RX_STATE_IDLE_BIT] ) begin
            rxCounter <= UART_CONFIG_DELAY_FRAMES / SAMPLE_COUNT;
        end
    end
///////////////
// Sample Clock
    reg sample_clock = 0;
    always @( posedge clk ) begin
        sample_clock <= 0;
        if( rxCounter == 0 )
            sample_clock <= 1;
    end
////////////
// Bit Clock
    reg [$clog2(SAMPLE_COUNT):0]    sample_counter      = 0;
    reg                             bit_clock           = 0;
    always @( posedge clk ) begin
        bit_clock <= 0;
        if( rxstate[`RX_STATE_IDLE_BIT] ) begin
            sample_counter <= SAMPLE_COUNT;
        end else begin
            if( sample_clock ) begin
                sample_counter <= sample_counter - 1'b1;
            end
            if( sample_counter == 0 ) begin
                bit_clock <= 1;
                sample_counter <= SAMPLE_COUNT;
            end
        end
    end
/////////////////////
// take input samples
    reg [SAMPLE_COUNT-1:0] samples = 'hFFFFFFFF;
    always @(posedge clk) begin
        if( sample_clock )
            samples <= {rxPin_FF, samples[SAMPLE_COUNT-1:1]};
    end
//////////////////////////////////////////////////////////////////////////////////
// calculate value from input samples - pipelined.
    reg [$clog2(SAMPLE_COUNT)-1:0]  sample_iterator = 0;
    reg [$clog2(SAMPLE_COUNT)-1:0]  sample_value    = SAMPLE_COUNT-1;
    reg                             rx_value    = 1;
    always @(posedge clk) begin
        if( rxstate[`RX_STATE_IDLE_BIT] ) begin
            sample_iterator <= SAMPLE_COUNT-1;
        end else if( sample_iterator != 0 ) begin
            sample_iterator <= sample_iterator - 1'b1;
            sample_value    <= sample_value + samples[sample_iterator-1];
        end else begin
            rx_value <= (sample_value >= SAMPLE_COUNT / 2);
            if( sample_clock ) begin
                sample_iterator <= SAMPLE_COUNT-1;
                sample_value    <= 0;
            end
        end
    end
///////////////
// Main Program
    reg [$clog2(DATA_WIDTH):0]      rxBitNumber     = 0;
    reg [DATA_WIDTH - 1:0]          dataIn          = 0;
    reg                             parity          = 0;
    reg [$clog2(DATA_WIDTH):0]      shift_counter   = 0;
    always @( posedge clk ) begin
        uart_rx_ready <= 0;// Toggle uart_rx_ready for 1 tick
        if( rst_n == 0 ) begin
            rxstate <= RX_STATE_IDLE;
            uart_rx_error <= 0;
            dataout <= 0;
        end else begin 
            if( rxstate[`RX_STATE_IDLE_BIT] && !rxPin_FF ) begin  // reset all clock timers as soon as the rx goes for the start bit.
                rxstate <= RX_STATE_START;
            end else begin
                if ( bit_clock )  begin 
                    if( rxstate[`RX_STATE_START_BIT] ) begin
                        if( rx_value == 0 ) begin
                            rxstate         <= RX_STATE_READ;
                            rxBitNumber     <= 0;
                            uart_rx_error   <= 0;
                            dataIn          <= 0;
                            case( UART_CONFIG_PARITY )
                                `UART_PARITY_ODD:   parity <= 1;
                                `UART_PARITY_EVEN:  parity <= 0;
                            endcase
                            shift_counter   <= DATA_WIDTH - UART_CONFIG_DATABITS;
                        end else begin
                            rxstate <= RX_STATE_IDLE;
                        end
                    end else if( rxstate[`RX_STATE_READ_BIT] ) begin
                        rxBitNumber <= rxBitNumber + 1'b1;
                        //update the parity tracker.
                        if( rx_value )
                            parity <= ~parity;
                        // if this is data, shift the input value into the 'dataIn' register
                        if( rxBitNumber < UART_CONFIG_DATABITS ) begin  
                            dataIn <= { rx_value, dataIn[DATA_WIDTH - 1:1] };
                        end
                        // when reading the last data bit 
                        if( rxBitNumber == UART_CONFIG_DATABITS - 1 ) begin
                            if( UART_CONFIG_PARITY == 0 ) begin // if not using parity bit, Goto the STOP_BIT
                                rxstate <= RX_STATE_STOP;
                                rxBitNumber <= 0;
                            end                                 // else allow the read_state to read the parity bit
                        end
                        // when parity is finished, go to the stop state
                        if( rxBitNumber == UART_CONFIG_DATABITS ) begin
                            rxstate <= RX_STATE_STOP;
                            rxBitNumber <= 0;
                        end
                    end
                end // bit_clock
                // align data to output the proper bit width from the oversized register.
                if( rxstate[`RX_STATE_STOP_BIT] ) begin
                    if( shift_counter ) begin
                        shift_counter <= shift_counter - 1'b1;
                        dataIn <= dataIn >> 1;
                    end else begin
                        uart_rx_ready   <= 1;
                        dataout         <= dataIn;
                        rxstate         <= RX_STATE_IDLE;
                        if( UART_CONFIG_PARITY != 0 && parity )
                                uart_rx_error <= 1;
                    end
                end
            end //non-idle state
        end // reset
    end // always   
endmodule