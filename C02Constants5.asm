;**************************************************************************************************
;*                                                                                                *
;*              C02 Constants used for the 5.1 release of C02BIOS5 / C02Monitor5                  *
;*                                                                                                *
;*                                                                                                *
;*                                  04/04/2026 (Day/Month/Year)                                   *
;*                                                                                                *
;**************************************************************************************************
;                                                                                                 *
; C02BIOS Version is now at 5.1                                                                   *
; C02Monitor Version is now at 5.1                                                                *
; - All Constants and Variables are now defined in a single source file (this one)                *
;                                                                                                 *
; - Be sure to include this file at the start of any source file that needs it.                   *
;                                                                                                 *
;**************************************************************************************************
;                                                                                                 *
;          - Page Zero locations $00 to $BF (192 bytes) reserved for user applications            *
;                                                                                                 *
;**************************************************************************************************
;
PGZERO_ST       .EQU    $A0                     ;Start of Monitor Page 0 use ($A0-$CF, 48 bytes)
;
BUFF_PG0        .EQU    PGZERO_ST+00            ;Default Page zero location for Monitor buffers
;
INBUFF          .EQU    BUFF_PG0+00             ;Input Buffer - 4 bytes ($A0-$A3)
;
;       - 16-bit variables:
HEXDATAH        .EQU    PGZERO_ST+04            ;Hexadecimal input
HEXDATAL        .EQU    PGZERO_ST+05
COMLO           .EQU    PGZERO_ST+06            ;User command address
COMHI           .EQU    PGZERO_ST+07
INDEXL          .EQU    PGZERO_ST+08            ;Index for address - multiple routines
INDEXH          .EQU    PGZERO_ST+09
TEMP1L          .EQU    PGZERO_ST+10            ;Index for word temp value used by Memdump
TEMP1H          .EQU    PGZERO_ST+11
SRCL            .EQU    PGZERO_ST+12            ;Source address for memory operations
SRCH            .EQU    PGZERO_ST+13
TGTL            .EQU    PGZERO_ST+14            ;Target address for memory operations
TGTH            .EQU    PGZERO_ST+15
LENL            .EQU    PGZERO_ST+16            ;Length address for memory operations
LENH            .EQU    PGZERO_ST+17
;
;       - 8-bit variables and constants:
BUFIDX          .EQU    PGZERO_ST+18            ;Buffer index
BUFLEN          .EQU    PGZERO_ST+19            ;Buffer length
IDX             .EQU    PGZERO_ST+20            ;Temp Indexing
IDY             .EQU    PGZERO_ST+21            ;Temp Indexing
TEMP1           .EQU    PGZERO_ST+22            ;Temp - Code Conversion routines
TEMP2           .EQU    PGZERO_ST+23            ;Temp - Memory/SREC routines
CMDFLAG         .EQU    PGZERO_ST+24            ;Command Flag, bit specific, used by many routines
;
;       - Xmodem transfer variables
OPXMDM          .EQU    PGZERO_ST+25            ;Xmodem Flag variable
CRCHI           .EQU    PGZERO_ST+26            ;CRC hi byte  (two byte variable)
CRCLO           .EQU    PGZERO_ST+27            ;CRC lo byte - Operand in Disassembler
CRCCNT          .EQU    PGZERO_ST+28            ;CRC retry count - Operand in Disassembler
PTRL            .EQU    PGZERO_ST+29            ;Data pointer lo byte - Mnemonic in Disassembler
PTRH            .EQU    PGZERO_ST+30            ;Data pointer hi byte - Mnemonic in Disassembler
BLKNO           .EQU    PGZERO_ST+31            ;Block number
;
BIOS_PG0        .EQU    $C0                     ;Start of BIOS Page 0 usage (64 bytes)
;
; Reserve 8 bytes of Page Zero for DOS/65 usage ($C0 - $C7).
;
;       - BIOS variables, pointers, flags located at top of Page Zero
;
DATABUFF        .EQU    BIOS_PG0+08             ;Data Buffer - 6 bytes ($C8-$CD)
;
BINVALL         .EQU    BIOS_PG0+14             ;Binary Value for HEX2ASC
BINVALH         .EQU    BIOS_PG0+15
;
STRINGL         .EQU    BIOS_PG0+16             ;Pointer for sending a text string low
STRINGH         .EQU    BIOS_PG0+17
;
;       - BRK handler routine
PCL             .EQU    BIOS_PG0+18             ;Program Counter Low index
PCH             .EQU    BIOS_PG0+19             ;Program Counter High index
PREG            .EQU    BIOS_PG0+20             ;Temp Status Reg
SREG            .EQU    BIOS_PG0+21             ;Temp Stack ptr
YREG            .EQU    BIOS_PG0+22             ;Temp Y Reg
XREG            .EQU    BIOS_PG0+23             ;Temp X Reg
AREG            .EQU    BIOS_PG0+24             ;Temp A Reg
;
;       - 28L92 IRQ handler pointers and status
ICNT_A          .EQU    BIOS_PG0+25             ;Input buffer count
IHEAD_A         .EQU    BIOS_PG0+26             ;Input buffer head pointer
ITAIL_A         .EQU    BIOS_PG0+27             ;Input buffer tail pointer
OCNT_A          .EQU    BIOS_PG0+28             ;Output buffer count
OHEAD_A         .EQU    BIOS_PG0+29             ;Output buffer head pointer
OTAIL_A         .EQU    BIOS_PG0+30             ;Output buffer tail pointer
;
ICNT_B          .EQU    BIOS_PG0+31             ;Input buffer count
IHEAD_B         .EQU    BIOS_PG0+32             ;Input buffer head pointer
ITAIL_B         .EQU    BIOS_PG0+33             ;Input buffer tail pointer
OCNT_B          .EQU    BIOS_PG0+34             ;Output buffer count
OHEAD_B         .EQU    BIOS_PG0+35             ;Output buffer head pointer
OTAIL_B         .EQU    BIOS_PG0+36             ;Output buffer tail pointer
;
UART_IRT        .EQU    BIOS_PG0+37             ;SC28L92 Interrupt Status byte
;
;       -RTC DS1318 Values:
; These are the values used for the alternate RTC chip, which is simply a 32-bit interval counter
; which is loaded with EPOCH time and incremented each second as a 32-bit integer.
; This frees up 3 locations in Page Zero.
;
TICKS           .EQU    BIOS_PG0+38             ;Number of timer countdowns = 1 second (100)
SECS_0          .EQU    BIOS_PG0+39             ;Seconds: bits 0-7
SECS_1          .EQU    BIOS_PG0+40             ;Seconds: bits 8-15
SECS_2          .EQU    BIOS_PG0+41             ;Seconds: bits 16-23
SECS_3          .EQU    BIOS_PG0+42             ;Seconds: bits 24-31
;
;       - Delay Timer variables
MSDELAY         .EQU    BIOS_PG0+43             ;Timer delay countdown byte (255 > 0)
SETMS           .EQU    BIOS_PG0+44             ;Set timeout for delay routines - BIOS use only
DELLO           .EQU    BIOS_PG0+45             ;Delay value BIOS use only
DELHI           .EQU    BIOS_PG0+46             ;Delay value BIOS use only
;
;       - Count variables for 10ms benchmark timing
MS10_CNT        .EQU    BIOS_PG0+47             ;10ms Count variable
SECL_CNT        .EQU    BIOS_PG0+48             ;Seconds Low byte count
SECH_CNT        .EQU    BIOS_PG0+49             ;Seconds High byte count
;
;       - Address and pointers for IDE Interface
LBA_ADDR_LOW    .EQU    BIOS_PG0+50             ;LBA Transfer Address low byte
LBA_ADDR_HIGH   .EQU    BIOS_PG0+51             ;LBA Transfer Address high byte
;
LBA_XFER_CNT    .EQU    BIOS_PG0+52             ;LBA Transfer Count 1-xx (check RAM space!)
;
LBA_LOW_BYTE    .EQU    BIOS_PG0+53             ;LBA Block number bits 0-7
LBA_HIGH_BYTE   .EQU    BIOS_PG0+54             ;LBA Block number bits 8-15
LBA_EXT_BYTE    .EQU    BIOS_PG0+55             ;LBA Block number bits 16-23
;
BIOS_XFERL      .EQU    BIOS_PG0+56             ;BIOS Move Routine low byte
BIOS_XFERH      .EQU    BIOS_PG0+57             ;BIOS Move Routine high byte
BIOS_XFERC      .EQU    BIOS_PG0+58             ;BIOS Block Count moved (needs to be set)
;
IDE_STATUS_RAM  .EQU    BIOS_PG0+59             ;IDE RAM-Based Status
;
B_SPARE0        .EQU    BIOS_PG0+60             ;Spare BIOS byte page zero
B_SPARE1        .EQU    BIOS_PG0+61             ;Spare BIOS byte page zero
B_SPARE2        .EQU    BIOS_PG0+62             ;Spare BIOS byte page zero
;
;       - Timer/Counter Match flag for Delay/Benchmark and hardware support
MATCH           .EQU    BIOS_PG0+63             ;Bit 7 used for Delay
                                                ;Bit 6 used for Benchmark
                                                ;Bit 5 used to show IDE drive present
                                                ;Bit 4 used to show RTC chip present
                                                ;Bits 3,2 used for IDE Interrupt Handler
                                                ;Bits 1,0 reserved for future use
;
;**************************************************************************************************
;
; Default for RTC tick count - number of IRQs for 1 second
DF_TICKS        .EQU    100                     ;Timer is 10 milliseconds (100 x 10ms = 1 second)
;
;**************************************************************************************************
;
SOFTVEC         .EQU    $0200                   ;Start of soft vectors
;The Interrupt structure is vector based. During startup, Page $02 is loaded from ROM.
; The soft vectors are structured to allow inserting additional routines either before
; or after the ROM based routines. This allows flexibility and changing of routine priority.
;
;The main set of vectors occupy the first 16 bytes of Page $02. The ROM handler for
; NMI, BRK and IRQ jump to the first 3 vectors. The following 3 vectors are loaded with
; return addresses to the ROM handler for each. The following 2 vectors are the cold and
; warm entry points for the Monitor. After the basic initialization, the monitor is entered.
;
;The following vector set allows inserts, pre or post for NMI/BRK/IRQ. There a total of 8 inserts
; which occupy 16 bytes. They can be used as required.
; Currently, VECINSRT0 will be used if an IDE Controller is detected.
;
NMIVEC0         .EQU    SOFTVEC+00              ;NMI Vector Entry 0
BRKVEC0         .EQU    SOFTVEC+02              ;BRK Vector Entry 0
IRQVEC0         .EQU    SOFTVEC+04              ;IRQ Vector Entry 0
;
NMIRTVEC0       .EQU    SOFTVEC+06              ;NMI Vector Return 0
BRKRTVEC0       .EQU    SOFTVEC+08              ;BRK Vector Return 0
IRQRTVEC0       .EQU    SOFTVEC+10              ;IRQ Vector Return 0
;
CLDMNVEC0       .EQU    SOFTVEC+12              ;Monitor Cold Entry Vector 0
WRMMNVEC0       .EQU    SOFTVEC+14              ;Monitor Warm Entry Vector 0
;
VECINSRT0       .EQU    SOFTVEC+16              ;1st Vector Insert
VECINSRT1       .EQU    SOFTVEC+18              ;2nd Vector Insert
VECINSRT2       .EQU    SOFTVEC+20              ;3rd Vector Insert
VECINSRT3       .EQU    SOFTVEC+22              ;4th Vector Insert
VECINSRT4       .EQU    SOFTVEC+24              ;5th Vector Insert
VECINSRT5       .EQU    SOFTVEC+26              ;6th Vector Insert
VECINSRT6       .EQU    SOFTVEC+28              ;7th Vector Insert
VECINSRT7       .EQU    SOFTVEC+30              ;8th Vector Insert
;
;**************************************************************************************************
;
;Soft Config values below are loaded from ROM and are the default I/O setup Configuration data that
; the INIT_x routines use. As a result, you can write a routine to change the I/O Configuration
; data and use the standard ROM routines to initialize the I/O without restarting or changing ROM
; A Reset (HW or coded) will reinitialize the I/O with the ROM default I/O Configuration.
;
;There are a total of 32 Bytes Configuration data reserved starting at $0220,
; - 22 bytes are reserved for the NXP SC28L92 DUART.
;
SOFTCFG         .EQU    SOFTVEC+32              ;Start of hardware Config parameters
;
LOAD_28L92      .EQU    SOFTCFG+00              ;SC28L92 Soft Config Data
;
; The configuration for the DUART consists of 14 parameters/commands stored in the following
; - memory locations. Note that these are sent in reverse, i.e., $22E thru $220.
;
;       $220    .DB     %00000011       $03     ;Enable OP0/1 for RTS control Port A/B
;       $221    .DB     %00001010       $A0     ;Disable Receiver/Disable Transmitter B
;       $222    .DB     %00001001       $09     ;Enable Receiver/Disable Transmitter A
;       $223    .DB     %00001111       $0F     ;Interrupt Mask Register setup
;       $224    .DB     %11100000       $E0     ;Aux Register setup for Counter/Timer
;       $225    .DB     %01001000       $48     ;Counter/Timer Upper Preset (18432 decimal)
;       $226    .DB     %00000000       $00     ;Counter/Timer Lower Preset
;       $227    .DB     %11001100       $CC     ;Baud Rate clock for B Rcv/Xmt - 115.2K
;       $228    .DB     %11001100       $CC     ;Baud Rate clock for A Rcv/Xmt - 115.2K
;       $229    .DB     %00110000       $30     ;Reset Transmitter B
;       $22A    .DB     %00100000       $20     ;Reset Receiver B
;       $22B    .DB     %00110000       $30     ;Reset Transmitter A
;       $22C    .DB     %00100000       $20     ;Reset Receiver A
;       $22D    .DB     %00000000       $00     ;Interrupt Mask Register setup (clear)
;       $22E    .DB     %11110000       $F0     ;Command Register A - Disable Power Down
;       $22F    .DB     %11111111       $FF     ;Spare Byte
;
; The MR registers of the DUART also have soft config data loaded here, but is separate from the
; - main register config data, as these are all accessed via a single I/O port (auto-indexed).
; - These are also sent in reverse order as above.
;
;       $230    .DB     %00010111       $17     ;Mode Register 2 data
;       $231    .DB     %11010011       $D3     ;Mode Register 1 Data
;       $232    .DB     %11111001       $F9     ;Mode Register 0 Data
;
;       $233    .DB     %00010111       $17     ;Mode Register 2 data
;       $234    .DB     %11010011       $D3     ;Mode Register 1 Data
;       $235    .DB     %11000001       $C1     ;Mode Register 0 Data
;
;       10 additional bytes are reserved for additional soft configuration data.
;
; The Microdrive is initialized and the total LBA count is saved here during startup.
;  It is used by various utilities and allows drive capacity sensing without sending additional
;  commands to the Microdrive. A total of 4 bytes are used for a 32-bit LBA count. These are saved
;  at addresses $23C - $23F. Order is low-word/high-word. Each word is low-byte/high-byte.
; Note: these 4 bytes are allocated from the 10 additional bytes noted above.
;
LOAD_IDE        .EQU    SOFTCFG+28              ;IDE/CF-Card Soft Config Data
;
;       $23C    .DW                             ;Low order LBA count
;       $23E    .DW                             ;High order LBA count
;
;Search Buffer is 16 bytes in length. Used to hold search string for text or hex data
;
SRCHBUFF        .EQU    SOFTCFG+32              ;Located in Page $02 following Hardware Config data
;       $240                                    ;Start of search buffer (16 bytes)
;
;Xmodem/CRC Loader also provides Motorola S19 Record sense and load. Designed to handle the S19
; records from the WDC Assembler/Linker package. This requires a 44 byte buffer to parse each valid
; S1 record, located just before the 132 Byte Xmodem frame buffer. Total Buffer space for the
; Xmodem/CRC Loader is 176 bytes
;
;Valid S-record headers are "S1" and "S9". For S1, the maximum length is "$19" hex. The last S1
; record can be less. S9 record is always the last record with no data. WDC Linker also appends
; a CR/LF to the end of each record for a total of 44 bytes.
;
SRBUFF          .EQU    SOFTCFG+48              ;S-Record buffer, up to 44 bytes in length
;       $250                                    ;Start of S-Record buffer
;
;Xmodem frame buffer. The entire Xmodem frame is buffered here and then checked for proper header
; and frame number, CRC-16 on the data, then moved to user RAM.
;
RBUFF           .EQU    SOFTCFG+92              ;Xmodem temp 132 byte receive buffer
;       $27C                                    ;Start of Receive buffer for Xmodem
;
;Page $02 is completely allocated for Buffers, Config Data and Vector pointers.
; Some of the buffer space can be used as needed, provided any required Monitor functions are NOT
; being used concurrently.
;
;**************************************************************************************************
;
IBUF_A          .EQU    $0300                   ;Console Input Buffer - 128 bytes
OBUF_A          .EQU    $0380                   ;Console Output Buffer - 128 bytes
;
IBUF_B          .EQU    $0400                   ;Alternate Input Buffer - 128 bytes
OBUF_B          .EQU    $0480                   ;Alternate Output Buffer - 128 bytes
;
;**************************************************************************************************
;
;Page $05 is reserved for future hardware / software expansion
;
;**************************************************************************************************
;
;Pages $06 - $07 are used for the IDE device Block Buffer (512 bytes)
LBA_BUFFER      .EQU    $0600                   ;Default IDE Block Buffer address
;
;Pages $07 - $08 are used for the IDE device Boot Buffer (512 bytes)
BOOT_BUFFER     .EQU    $0800                   ;Default IDE Boot Buffer address
;
;**************************************************************************************************
;XMODEM Control Character Constants
SOH             .EQU    $01                     ;Start of Block Header
EOT             .EQU    $04                     ;End of Text marker
ACK             .EQU    $06                     ;Good Block Acknowledge
NAK             .EQU    $15                     ;Bad Block Acknowledged
CAN             .EQU    $18                     ;Cancel character
;
;**************************************************************************************************
;
;**************************************************************************************************
;
;DOS/65 can be called from the Monitor via the Ctrl-B command. - Temporary!
;The start location is just added here for convenience, but should be changed if needed.
;
DOS_65          .EQU    $D400                   ;Default SIM location to Boot DOS/65 (optional)
;
;**************************************************************************************************
;
IOPAGE          .EQU    $FE00                   ;I/O Page Base Start Address
;
;**************************************************************************************************
;
SC28L92_BASE    .EQU    IOPAGE+$00              ;Beginning of Console UART address
;
UART_MODEREG_A  .EQU    SC28L92_BASE+$00        ;MR0/MR1/MR2 Port A sequential (READ/WRITE)
UART_STATUS_A   .EQU    SC28L92_BASE+$01        ;UART Status Register Port A (READ)
UART_CLKSEL_A   .EQU    SC28L92_BASE+$01        ;UART Clock Select Port A (WRITE)
UART_RESERVE_A  .EQU    SC28L92_BASE+$02        ;UART Reserved Port A (READ)
UART_COMMAND_A  .EQU    SC28L92_BASE+$02        ;UART Command Register Port A (WRITE)
UART_RECEIVE_A  .EQU    SC28L92_BASE+$03        ;UART Receive Register Port A (READ)
UART_TRANSMIT_A .EQU    SC28L92_BASE+$03        ;UART Transmit Register Port A (WRITE)
;
UART_PORT_CHG   .EQU    SC28L92_BASE+$04        ;UART Input Port Change Register (READ)
UART_AUXCR      .EQU    SC28L92_BASE+$04        ;UART Aux Command Register (WRITE)
UART_ISR        .EQU    SC28L92_BASE+$05        ;UART Interrupt Status Register (READ)
UART_IMR        .EQU    SC28L92_BASE+$05        ;UART Interrupt Mask Register (WRITE)
;
UART_CNTU       .EQU    SC28L92_BASE+$06        ;Counter/Timer Upper Register (READ)
UART_CNTUP      .EQU    SC28L92_BASE+$06        ;Counter/Timer Upper Preset Register (WRITE)
UART_CNTL       .EQU    SC28L92_BASE+$07        ;Counter/Timer Lower Register (READ)
UART_CNTLP      .EQU    SC28L92_BASE+$07        ;Counter/Timer Lower Preset Register (WRITE)
;
UART_MODEREG_B  .EQU    SC28L92_BASE+$08        ;MR0/MR1/MR2 Port B sequential (READ/WRITE)
UART_STATUS_B   .EQU    SC28L92_BASE+$09        ;UART Status Register Port B (READ)
UART_CLKSEL_B   .EQU    SC28L92_BASE+$09        ;UART Clock Select Port B (WRITE)
UART_RESERVE_B  .EQU    SC28L92_BASE+$0A        ;UART Reserved Port B (READ)
UART_COMMAND_B  .EQU    SC28L92_BASE+$0A        ;UART Command Register Port B (WRITE)
UART_RECEIVE_B  .EQU    SC28L92_BASE+$0B        ;UART Receive Register Port B (READ)
UART_TRANSMIT_B .EQU    SC28L92_BASE+$0B        ;UART Transmit Register Port B (WRITE)
;
UART_MISC       .EQU    SC28L92_BASE+$0C        ;UART Miscellaneous Register Intel (READ/WRITE)
UART_INPUT_PORT .EQU    SC28L92_BASE+$0D        ;UART Input Port Register (READ)
UART_OUT_CFG    .EQU    SC28L92_BASE+$0D        ;UART Ouput Port Config Register (WRITE)
UART_START_CNT  .EQU    SC28L92_BASE+$0E        ;UART Start Counter Command (READ)
UART_SOPR_CMD   .EQU    SC28L92_BASE+$0E        ;UART Set Output Port Bits Register (WRITE)
UART_STOP_CNT   .EQU    SC28L92_BASE+$0F        ;UART Stop Counter Command (READ)
UART_ROPR_CMD   .EQU    SC28L92_BASE+$0F        ;UART Reset Output Port Bits Register (WRITE)
;
;Additional Hardware - DS-1318 RTC
; Replacement for DS15x1 RTC
; - this RTC uses a simple 32-bit counter implemented as 4 bytes
; - this will be setup with EPOCH time as a 32-bit count.
; - this greatly simplifies the BIOS routines to support.
; - the setup will be done by a separate utility application
; - reading the RTC and showing as Day/Month/Year will be done via a loadable application
;
RTC_BASE        .EQU    IOPAGE+$20              ;Start of RTC Regsters
;
RTC_SUB_SEC_0   .EQU    RTC_BASE+0              ;Sub-Seconds 0
RTC_SUB_SEC_1   .EQU    RTC_BASE+1              ;Sub-Seconds 1
;
RTC_SECONDS_0   .EQU    RTC_BASE+2              ;Clock Seconds 0
RTC_SECONDS_1   .EQU    RTC_BASE+3              ;Clock Seconds 1
RTC_SECONDS_2   .EQU    RTC_BASE+4              ;Clock Seconds 2
RTC_SECONDS_3   .EQU    RTC_BASE+5              ;Clock Seconds 3
;
RTC_ALARM_0     .EQU    RTC_BASE+6              ;Alarm Seconds 0
RTC_ALARM_1     .EQU    RTC_BASE+7              ;Alarm Seconds 1
RTC_ALARM_2     .EQU    RTC_BASE+8              ;Alarm Seconds 2
RTC_ALARM_3     .EQU    RTC_BASE+9              ;Alarm Seconds 3
;
RTC_CONTROL_A   .EQU    RTC_BASE+10             ;Control Register A
RTC_CONTROL_B   .EQU    RTC_BASE+11             ;Control Register B
;
RTC_STATUS      .EQU    RTC_BASE+12             ;Status Register
;
; Adding BIOS definitions for 16-bit IDE interface
; uses two addresses for Upper Byte Latch read / write
; uses eight addresses for Command Block Registers
; uses two addresses for Control Block Registers
;
RTC_IDE_BASE    .EQU    IOPAGE+$20              ;
;
IDE_16_READ     .EQU    RTC_IDE_BASE+$14        ;Upper byte Read address
IDE_16_WRITE    .EQU    RTC_IDE_BASE+$15        ;Upper byte Write address
;
; Adding BIOS definitions for IDE Controller (HARD DISK, Flash Module, etc.)
; Hardware Adapter provides a 16-bit IDE Port per:
;  Seagate ATA Interface Reference Manual 36111-001, Rev. C (21st May 1993)
;
; Control Block Registers
IDE_ALT_STATUS  .EQU    RTC_IDE_BASE+$16        ;Alternate Status Register (READ)
IDE_DEV_CTRL    .EQU    RTC_IDE_BASE+$16        ;Device Control Register (WRITE)
IDE_DRV_ADDR    .EQU    RTC_IDE_BASE+$17        ;Drive Address Register (READ)
;
; Command Block Registers
IDE_DATA        .EQU    RTC_IDE_BASE+$18        ;Data Register (R/W)
IDE_ERROR       .EQU    RTC_IDE_BASE+$19        ;Error Register (READ)
IDE_FEATURE     .EQU    RTC_IDE_BASE+$19        ;Feature Register (WRITE)
IDE_SCT_CNT     .EQU    RTC_IDE_BASE+$1A        ;Sector Count Register
IDE_SCT_NUM     .EQU    RTC_IDE_BASE+$1B        ;Sector Number Register
IDE_CYL_LOW     .EQU    RTC_IDE_BASE+$1C        ;Cylinder Low Register
IDE_CYL_HIGH    .EQU    RTC_IDE_BASE+$1D        ;Cylinder High Register
IDE_DRV_HEAD    .EQU    RTC_IDE_BASE+$1E        ;Drive/Head Register
IDE_STATUS      .EQU    RTC_IDE_BASE+$1F        ;Status Register (READ)
IDE_COMMAND     .EQU    RTC_IDE_BASE+$1F        ;Command Register (WRITE)
;
;**************************************************************************************************
;
        .END
