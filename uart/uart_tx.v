`include "uart/uart_include.v"
module uart_tx
#(
    parameter COUNTER_WIDTH       = `UART_CONFIG_WIDTH_DELAYFRAMES,
    parameter DATA_WIDTH          = `UART_CONFIG_WIDTH_DATABITS
)
(
    input   wire                    clk,            // input clock
    output  reg                     uart_txpin,     // output tx pin
    input   wire [DATA_WIDTH-1:0]   datain,         // Data to send
    input   wire                    send_tx,        // Trigger to start sending data
    output  reg                     uart_tx_ready,  // flag, HIGH when ready for new data. LOW when sending
    input   wire                    rst_n,
    // config settings
    input   wire[COUNTER_WIDTH-1:0] UART_CONFIG_DELAY_FRAMES,   // see 'uart_include.v' for details
    input   wire[4:0]               UART_CONFIG_DATABITS,
    input   wire[1:0]               UART_CONFIG_PARITY,
    input   wire[1:0]               UART_CONFIG_STOPBITS
`ifdef UART_TX_SEND_ERROR_FOR_DEBUGGING
    ,input   wire                    send_error_for_debug      // debug feature to send bad parity bit 
`endif     
);
    // tx states
    localparam TX_STATE_IDLE        = 4'b0001;   `define TX_STATE_IDLE_BIT   0
    localparam TX_STATE_WRITE       = 4'b0010;   `define TX_STATE_WRITE_BIT  1
    localparam TX_STATE_PARITY      = 4'b0100;   `define TX_STATE_PARITY_BIT 2
    localparam TX_STATE_STOP        = 4'b1000;   `define TX_STATE_STOP_BIT   3
    localparam txBitNumber_width    = $clog2(DATA_WIDTH);
    reg [3:0]  txstate              = TX_STATE_IDLE;
    initial begin
        uart_txpin = 1;
    end

// Main Clock
    reg [COUNTER_WIDTH-1:0] txCounter = 0;
    always @( posedge clk ) begin
        if( txstate[`TX_STATE_IDLE_BIT] ) begin
            txCounter <= UART_CONFIG_DELAY_FRAMES;
        end else begin
            txCounter <= txCounter - 1'b1;
            if( txCounter == 0 ) begin
                if( txstate[`TX_STATE_STOP_BIT] ) begin
                    txCounter <= UART_CONFIG_DELAY_FRAMES / 2;
                end else begin
                    txCounter <= UART_CONFIG_DELAY_FRAMES;
                end
            end
        end
    end
// Bit Clock
    reg bit_clock = 0;
    always @( posedge clk ) begin
        bit_clock <= 0;
        if( txCounter == 0 )
            bit_clock <= 1;
    end
// Main program  
    reg                         parity = 0;
    reg [DATA_WIDTH-1:0]        txData  = 0;                // data being sent
    reg [txBitNumber_width:0]   txBitNumber   = 0;          // current bit being transmitted

    always @(posedge clk) begin
        if( rst_n == 0) begin                       // reset condition
            txstate         <= TX_STATE_IDLE;
            uart_txpin      <= 1;
            uart_tx_ready   <= 0;
        end else begin         
            // Waiting for the 'send_tx' to go HIGH then start sending data
            if( txstate[`TX_STATE_IDLE_BIT] ) begin
                uart_tx_ready <= 1;
                if( send_tx == 0 ) begin                    // Idle State
                    uart_txpin      <= 1;                   // Set TX to idle state (HIGH)
                end else begin             
                    txstate         <= TX_STATE_WRITE;      // Start the transmission
                    txData          <= datain;              // Store the data to be sent
                    txBitNumber     <= 0;                   // Reset current bit being sent
                    case( UART_CONFIG_PARITY )
                        `UART_PARITY_ODD:   parity <= 1;
                        `UART_PARITY_EVEN:  parity <= 0;
                    endcase                    
                    uart_txpin      <= 0;                   // Begin sending start bit
                    uart_tx_ready   <= 0;                   // Set the ready flag to LOW (not ready for new data)
                end
            end else begin
                if( bit_clock ) begin
                    // Each state is complete when we get here.
                    if( txstate[`TX_STATE_WRITE_BIT] ) begin   // start bit is finished. Start sending data
                        // Send the next bit
                        if (txBitNumber != UART_CONFIG_DATABITS) begin 
                            if( txData[txBitNumber] )
                                parity <= ~parity;                      // update parity bit
                            uart_txpin  <= txData[txBitNumber];         // update output pin
                            txBitNumber <= txBitNumber + 1'b1;          // increment bit counter
                        end else begin  // When all bits have been sent.
                            txBitNumber <= 0;                           // Reset bit counter for use in stopbit state   
                            // If not using a parity bit begin sending stop bit
                            if( UART_CONFIG_PARITY == 0 ) begin  
                                txstate     <= TX_STATE_STOP;       // Enter Stop State       
                                uart_txpin  <= 1;                   // Begin sending stop bit 
                            end else begin // Begin sending parity bit
                                txstate     <= TX_STATE_PARITY;
                                `ifdef UART_TX_SEND_ERROR_FOR_DEBUGGING
                                    if( send_error_for_debug ) begin        // corrupt the parity bit
                                        parity = ~parity;         // for debug only
                                        $display( "forcing error " );
                                    end   
                                `endif
                                uart_txpin <= parity;                            
                            end
                        end 
                    end else if( txstate[`TX_STATE_PARITY_BIT] ) begin
                        txstate <= TX_STATE_STOP;
                        uart_txpin <= 1;
                    end else if( txstate[`TX_STATE_STOP_BIT] ) begin
                        txBitNumber <= txBitNumber + 1'b1;  // This was reset at the end of the write state, used to track the number of stop bits sent
                        case ( UART_CONFIG_STOPBITS )
                            0: begin    // the first stop bit will be at normal bit_clock speed.
                                txstate <= TX_STATE_IDLE;
                            end
                            1: begin    // 1.5 stop bits    After the first stop bit the bit_clock period is halfed
                                if( txBitNumber == 1 )
                                    txstate <= TX_STATE_IDLE;
                            end
                            2: begin    // 2 stop bits
                                if( txBitNumber == 2 )
                                    txstate <= TX_STATE_IDLE;
                            end
                            default:
                                txstate <= TX_STATE_IDLE;
                        endcase               
                    end
                end // end counter expired logic
            end // end idle logic
        end // end reset logic
    end // end always block
endmodule