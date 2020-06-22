#ifndef TUXCTL_H
#define TUXCTL_H

#define TUX_SET_LED _IOR('E', 0x10, unsigned long)
#define TUX_READ_LED _IOW('E', 0x11, unsigned long*)
#define TUX_BUTTONS _IOW('E', 0x12, unsigned long*)
#define TUX_INIT _IO('E', 0x13)
#define TUX_LED_REQUEST _IO('E', 0x14)
#define TUX_LED_ACK _IO('E', 0x15)
#define BLANK 0x00
#define TURN_ON_LED 0x0F
#define mask_4b 0xF
#define mask_8b 0x0F
#define mask_12b 0x00F
#define mask_all 0x000F
#define mask_16b 0x00FF
#define mask_32b 0xFFFF
#define ONE 0x1
#define decimal_mask 0x10
#endif
