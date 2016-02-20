// tube-lib.h

#ifndef TUBE_LIB_H
#define TUBE_LIB_H

#define BITSPERWORD 8

#define CMD_WRITE 0x80
#define CMD_READ  0xC0

#define R1 1
#define R2 2
#define R3 3
#define R4 4

#define R1_STATUS 0
#define R1_DATA   1
#define R2_STATUS 2
#define R2_DATA   3
#define R3_STATUS 4
#define R3_DATA   5
#define R4_STATUS 6
#define R4_DATA   7

#define A_BIT 0x80
#define F_BIT 0x40

void setTubeLibDebug(int d);

void tubeWrite(unsigned char addr, unsigned char byte);

unsigned char tubeRead(unsigned char addr);

unsigned char tubeCmd(unsigned char cmd, unsigned char addr, unsigned char byte);

void sendByte(unsigned char reg, unsigned char byte);

unsigned char receiveByte(unsigned char reg);

void sendString(unsigned char reg, unsigned char terminator, const volatile char *buf);

int receiveString(unsigned char reg, unsigned char terminator, volatile char *buf);

void sendBlock(unsigned char reg, int len, const unsigned char *buf);

void receiveBlock(unsigned char reg, int len, unsigned char *buf);

void sendWord(unsigned char reg, unsigned int word);

unsigned int receiveWord(unsigned char reg);

void enable_MMU_and_IDCaches(void);

void enable_JTAG(void);

void enable_SoftTube(void);

#endif
