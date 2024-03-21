//`ifdef UART_CONFIG_V
//`else
    //`define UART_CONFIG_V

// This module stores and provides instance access to uart configuration settings.
    `include "uart/uart_include.v"
    module UART_CONFIG_REGISTER
    #(
        parameter   COUNTER_WIDTH   = `UART_CONFIG_WIDTH_DELAYFRAMES,
        parameter   MODE            = `UART_FULL_DUPLEX,       
        parameter   DELAY           = 2812, // Buad rate 9600
        parameter   DATABITS        = 8,    // 8 Bits per frame
        parameter   PARITY          = `UART_PARITY_NONE,     
        parameter   STOPBIT         = `UART_STOPBITS_1,    
        parameter   FLOW            = `UART_FLOWCTRL_NONE       
    )
    ( 
        //store config
        input   wire                        clk,
        input   wire [2:0]                  address,
        input   wire [COUNTER_WIDTH - 1:0]  value,
        input   wire                        store_data,
        
        //retreve config
        output  reg [COUNTER_WIDTH - 1:0]               UART_CONFIG_DELAY_FRAMES    = DELAY,
        output  reg                                     UART_CONFIG_MODE            = MODE,
        output  reg[4:0]                                UART_CONFIG_DATABITS        = DATABITS,
        output  reg[1:0]                                UART_CONFIG_PARITY          = PARITY,
        output  reg[1:0]                                UART_CONFIG_STOPBITS        = STOPBIT,
        output  reg[2:0]                                UART_CONFIG_FLOWCTRL        = FLOW
    );
    
    always@(posedge clk) begin
        if( store_data ) begin
            case(address)
                `UART_CONFIG_ADDRESS_MODE:
                    UART_CONFIG_MODE <= value[0];

                `UART_CONFIG_ADDRESS_DELAYFRAMES:
                    UART_CONFIG_DELAY_FRAMES <= value;
                
                `UART_CONFIG_ADDRESS_DATABITS:
                    UART_CONFIG_DATABITS <= value[4:0];

                `UART_CONFIG_ADDRESS_PARITY:
                    UART_CONFIG_PARITY <= value[1:0];
                
                `UART_CONFIG_ADDRESS_STOPBITS:
                    UART_CONFIG_STOPBITS <= value[1:0];
                
                `UART_CONFIG_ADDRESS_FLOWCTRL:
                    UART_CONFIG_FLOWCTRL <= value[2:0];
            endcase
        end
    end
    
    endmodule
//`endif