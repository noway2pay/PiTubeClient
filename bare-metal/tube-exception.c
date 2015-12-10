#include "rpi-base.h"
#include "rpi-aux.h"
#include "rpi-gpio.h"
#include "rpi-interrupts.h"
#include "tube-isr.h"

void dump_hex(unsigned int h) {
  int i;
  for (i = 0; i < 8; i++) {   
	int c = h >> 28;
	if (c < 10) {
	  c = '0' + c;
	} else {
	  c = 'A' + c - 10;
	}
	RPI_AuxMiniUartWrite(c);
	h <<= 4;
  }
}

// For some reason printf generally doesn't work here
void dump_info(unsigned int *reg) {
  unsigned int *addr;
  int i;
  int rstlow;
  int led;
  dump_hex((unsigned int)reg);
  RPI_AuxMiniUartWrite('\r');
  RPI_AuxMiniUartWrite('\n');  
  for (i = 0; i <= 13; i++) {
	RPI_AuxMiniUartWrite('r');
	RPI_AuxMiniUartWrite('e');  
	RPI_AuxMiniUartWrite('g');  
	RPI_AuxMiniUartWrite('[');  
	RPI_AuxMiniUartWrite('0' + (i / 10));  
	RPI_AuxMiniUartWrite('0' + (i % 10));  
	RPI_AuxMiniUartWrite(']');
	RPI_AuxMiniUartWrite('=');
	dump_hex(reg[i]);
	RPI_AuxMiniUartWrite('\r');
	RPI_AuxMiniUartWrite('\n');  
  }
  addr = (unsigned int *)(reg[13] & ~3);
  for (i = -4; i <= 4; i++) {
	dump_hex((unsigned int) (addr + i));
	RPI_AuxMiniUartWrite('=');
	dump_hex(*(addr + i));	
	RPI_AuxMiniUartWrite('\r');
	RPI_AuxMiniUartWrite('\n');  
  }
  RPI_AuxMiniUartWrite('H');
  RPI_AuxMiniUartWrite('a');
  RPI_AuxMiniUartWrite('l');
  RPI_AuxMiniUartWrite('t');
  RPI_AuxMiniUartWrite('e');
  RPI_AuxMiniUartWrite('d');
  RPI_AuxMiniUartWrite('\r');
  RPI_AuxMiniUartWrite('\n');

  rstlow = 0;
  led = 0;
  while (1) {
	for (i = 0; i < 1000000; i++) {
	  // look for reset being low
	  if (!(RPI_GetGpio()->GPLEV0 & RST_PIN_MASK)) {
		rstlow = 1;
	  }
	  // then reset on the next rising edge
	  if (rstlow && (RPI_GetGpio()->GPLEV0 & RST_PIN_MASK)) {
		reboot_now();
	  }
	}
	if (led) {
	  LED_OFF();
	} else {
	  LED_ON();
	}
	led = ~led;
  }
}

void undefined_instruction_handler(unsigned int *reg) {
  RPI_AuxMiniUartWrite('*');
  RPI_AuxMiniUartWrite('U');
  RPI_AuxMiniUartWrite('I');
  RPI_AuxMiniUartWrite('*');
  RPI_AuxMiniUartWrite('\r');
  RPI_AuxMiniUartWrite('\n');
  dump_info(reg);
}

void prefetch_abort_handler(unsigned int *reg) {
  RPI_AuxMiniUartWrite('*');
  RPI_AuxMiniUartWrite('P');
  RPI_AuxMiniUartWrite('A');
  RPI_AuxMiniUartWrite('*');
  RPI_AuxMiniUartWrite('\r');
  RPI_AuxMiniUartWrite('\n');
  dump_info(reg);
}

void data_abort_handler(unsigned int *reg) {
  RPI_AuxMiniUartWrite('*');
  RPI_AuxMiniUartWrite('D');
  RPI_AuxMiniUartWrite('A');
  RPI_AuxMiniUartWrite('*');
  RPI_AuxMiniUartWrite('\r');
  RPI_AuxMiniUartWrite('\n');
  dump_info(reg);
}
