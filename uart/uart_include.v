`ifdef UART_INCLUDE_V
`else
`define UART_INCLUDE_V
    // Settings
    `define UART_FULL_DUPLEX                0
    `define UART_HALF_DUPLEX                1
    `define UART_PARITY_NONE                0
    `define UART_PARITY_ODD                 1
    `define UART_PARITY_EVEN                2
    `define UART_STOPBITS_1                 0
    `define UART_STOPBITS_1_5               1
    `define UART_STOPBITS_2                 2
    `define UART_FLOWCTRL_NONE              0
    `define UART_FLOWCTRL_RTS               1
    `define UART_FLOWCTRL_CTS               2
    `define UART_FLOWCTRL_RTS_CTS           3

    // Setting addresses
    `define UART_CONFIG_ADDRESS_MODE        0   // 0 FULL Duplex, 1 Half Duplex
    `define UART_CONFIG_ADDRESS_DELAYFRAMES 1   // buad rate
    `define UART_CONFIG_ADDRESS_DATABITS    2   // 1-16 bytes
    `define UART_CONFIG_ADDRESS_PARITY      3   // 0 none, 1 odd, 2 even
    `define UART_CONFIG_ADDRESS_STOPBITS    4   // 0  1sb, 1  1.5sb, 2  2sb
    `define UART_CONFIG_ADDRESS_FLOWCTRL    5   // 0  none, 1 RTS, 2 CTS, 3 RTS_CTS

    // Setting register widths
    `define UART_CONFIG_WIDTH_DELAYFRAMES   13
    `define UART_CONFIG_WIDTH_DATABITS      16
    `define UART_CONFIG_FIFO_DEPTH          64

    // ToDo: impliment single register configuration for modules. 
    // removes multi-line port intalization for modules utilizing these registers
    `define UART_CONFIG_BITS_MODE           [0:0]
    `define UART_CONFIG_BITS_DATABITS       [5:1]
    `define UART_CONFIG_BITS_PARITY         [7:6]
    `define UART_CONFIG_BITS_STOPBITS       [9:8]
    `define UART_CONFIG_BITS_FLOWCTRL       [12:10]
    `define UART_CONFIG_BITS_DELAYFRAMES    [29:13]
`endif