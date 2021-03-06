// spi.h

#ifndef SPI_H
#define SPI_H

#include "rpi-gpio.h"

typedef unsigned char u8;
typedef unsigned char u32;
typedef volatile unsigned int v32;
#define REG32(in) *((v32*) (in))

// SPI0 ADDRESS
#define SPI0_CONTROL 	REG32(RPI_GPIO_BASE + 0x4000)
#define SPI0_FIFO    	REG32(RPI_GPIO_BASE + 0x4004)
#define SPI0_CLK     	REG32(RPI_GPIO_BASE + 0x4008)
#define SPI0_DLEN    	REG32(RPI_GPIO_BASE + 0x400C)
#define SPI0_LTOH    	REG32(RPI_GPIO_BASE + 0x4010)
#define SPI0_DC      	REG32(RPI_GPIO_BASE + 0x4014)

// Bitfields in spi_C
#define SPI_C_LEN_LONG	25
#define SPI_C_DMA_LEN	24
#define SPI_C_CSPOL2		23
#define SPI_C_CSPOL1		22
#define SPI_C_CSPOL0		21
#define SPI_C_RX			20
#define SPI_C_RXR			19
#define SPI_C_TXD			18
#define SPI_C_RXD			17
#define SPI_C_DONE		16
#define SPI_C_LEN			13
#define SPI_C_REN			12
#define SPI_C_ADCS		11
#define SPI_C_INTR		10
#define SPI_C_INTD		 9
#define SPI_C_DMAEN		 8
#define SPI_C_TA		 	 7
#define SPI_C_CSPOL		 6
#define SPI_C_CLEAR_RX	 5
#define SPI_C_CLEAR_TX	 4
#define SPI_C_CPOL		 3
#define SPI_C_CPHA		 2
#define SPI_C_CS1			 1
#define SPI_C_CS0			 0

extern void wait(unsigned int delay);
extern void spi_begin(void);
extern void spi_transfer(u8* TxBuff, u8* RxBuff, u32 Length);
extern void spi_send(u8* TxBuff, u32 Length);
extern void spi_end(void);
#endif
