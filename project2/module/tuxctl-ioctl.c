/*
 * tuxctl-ioctl.c
 *
 * Driver (skeleton) for the mp2 tuxcontrollers for ECE391 at UIUC.
 *
 * Mark Murphy 2006
 * Andrew Ofisher 2007
 * Steve Lumetta 12-13 Sep 2009
 * Puskar Naha 2013
 */

#include <asm/current.h>
#include <asm/uaccess.h>

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/sched.h>
#include <linux/file.h>
#include <linux/miscdevice.h>
#include <linux/kdev_t.h>
#include <linux/tty.h>
#include <linux/spinlock.h>

#include "tuxctl-ld.h"
#include "tuxctl-ioctl.h"
#include "mtcp.h"

#define debug(str, ...) printk(KERN_DEBUG "%s: " str, __FUNCTION__, ## __VA_ARGS__)
int LED_ERROR = 0;
char LED_RESTORE[6];
int button_c, button_b, button_a, button_s, button_r, button_d, button_l, button_u;
const unsigned char LED_display[16] = {0xE7, 0x06, 0xCB, 0x8F, 0x2E, 0xAD, 0xED, 0x86, 0xEF, 0xAF, 0xEE, 0x6D, 0xE1, 0x4F, 0xE9, 0xE8};



/************************ Protocol Implementation *************************/

/* tuxctl_handle_packet()
 * IMPORTANT : Read the header for tuxctl_ldisc_data_callback() in
 * tuxctl-ld.c. It calls this function, so all warnings there apply
 * here as well.
 * handles all packets received by the computer from the Tux controller
 * packet[0] is the first byte of the 3 byte
 */
void tuxctl_handle_packet (struct tty_struct* tty, unsigned char* packet) {
    unsigned a, b, c;

    a = packet[0]; /* Avoid printk() sign extending the 8-bit */
    b = packet[1]; /* values when printing them. */
    c = packet[2];

    /*printk("packet : %x %x %x\n", a, b, c); */

    switch(a){
        case MTCP_ACK:
        {
            LED_ERROR = 0;
            return;
        }

        case MTCP_BIOC_EVENT:
        {
            button_c = (b & 0x08);
            button_b = (b & 0x04);
            button_a = (b & 0x02);
            button_s = (b & 0x01);

            button_r = (c & 0x08);
            button_d = (c & 0x04);
            button_l = (c & 0x02);
            button_u = (c & 0x01);

            return;
        }

        case MTCP_RESET:
        {
            char buf;

            buf = MTCP_BIOC_ON;
            tuxctl_ldisc_put(tty, &buf, 1);

            buf = MTCP_LED_USR;
            tuxctl_ldisc_put(tty, &buf, 1);
            
            if(tuxctl_ldisc_put(tty, LED_RESTORE, 6) > 0){
                LED_ERROR = 1;
            }

            return;
        }

        default:
            return;
        

    }
}

/******** IMPORTANT NOTE: READ THIS BEFORE IMPLEMENTING THE IOCTLS ************
 *                                                                            *
 * The ioctls should not spend any time waiting for responses to the commands *
 * they send to the controller. The data is sent over the serial line at      *
 * 9600 BAUD. At this rate, a byte takes approximately 1 millisecond to       *
 * transmit; this means that there will be about 9 milliseconds between       *
 * the time you request that the low-level serial driver send the             *
 * 6-byte SET_LEDS packet and the time the 3-byte ACK packet finishes         *
 * arriving. This is far too long a time for a system call to take. The       *
 * ioctls should return immediately with success if their parameters are      *
 * valid.                                                                     *
 *                                                                            *
 ******************************************************************************/

int tuxctl_ioctl(struct tty_struct* tty, struct file* file,
                 unsigned cmd, unsigned long arg) {
    switch (cmd) {
        case TUX_INIT:
        {
            char buf;
            char LED_BUF[6];

            buf = MTCP_BIOC_ON;
            tuxctl_ldisc_put(tty, &buf, 1);

            buf = MTCP_LED_USR;
            tuxctl_ldisc_put(tty, &buf, 1);

            LED_ERROR = 0;

            LED_BUF[0] = LED_RESTORE[0] = MTCP_LED_SET;         //opcode
            LED_BUF[1] = LED_RESTORE[1] = TURN_ON_LED;             //set all 4 LEDs on
            LED_BUF[2] = LED_RESTORE[2] = BLANK;                //set the rest as blank
            LED_BUF[3] = LED_RESTORE[3] = BLANK;
            LED_BUF[4] = LED_RESTORE[4] = BLANK;
            LED_BUF[5] = LED_RESTORE[5] = BLANK;

            tuxctl_ldisc_put(tty, LED_BUF, 6);

            return 0;
        }

        case TUX_BUTTONS:
        {   unsigned long lowbit = 11111111;
            // unsigned long ary[8];
           
            if(arg == 0){
                return -EINVAL;
            }
            else{
                unsigned long * buttonval = (unsigned long *) arg;

                if (button_c == 1){                                 //check if the button is pressed
                    lowbit = lowbit - 1000;                         //if pressed, set bit to 0
                }
                if (button_b == 1){
                    lowbit = lowbit - 100;
                }
                if (button_a == 1){
                    lowbit = lowbit - 10;
                }
                if (button_s == 1){
                    lowbit = lowbit - 1;
                }
                if (button_r == 1){
                    lowbit = lowbit - 10000000;
                }
                if (button_l == 1){
                    lowbit = lowbit - 1000000;
                }
                if (button_d == 1){
                    lowbit = lowbit - 100000;
                }
                if (button_u == 1){
                    lowbit = lowbit - 10000;
                }

                *buttonval = lowbit;                                //points to the low byte
                return 0;
            }

        }
        case TUX_SET_LED:
        {
            if(LED_ERROR == 1){
                return -EINVAL;
            }

            else{
                char LED_SETTING[6];
                char HEX[4];                                                    //hex numbers from arg
                int byte4 = (arg>>24)&mask_4b;                            //decimal points byte bitmask
                int byte3 = (arg>>16)&mask_4b;                            //which LED byte bitmask
                int hex_byte = (arg)&(mask_32b);                               //LED Hex number bitmask

                int LED0_on = (byte3 & ONE);
                int LED1_on = ((byte3>>1) & ONE);
                int LED2_on = ((byte3>>2) & ONE);
                int LED3_on = ((byte3>>3) & ONE);

                int hex_val, dec_val;

                LED_SETTING[0] = MTCP_LED_SET;                                  //opcocde
                LED_SETTING[1] = TURN_ON_LED;                                   //turn on all 4 LEDs (initialize)
                                                                                //if not used, leave on but set 7-seg value to 0x00

                // int hex_val_0 = (hex_byte & mask_all);
                // int hex_val_1 = ((hex_byte>>4) & mask_12b);
                // int hex_val_2 = ((hex_byte>>8) & mask_8b);
                // int hex_val_3 = ((hex_byte>>12) & mask_4b);

                // int decimal_0 = (byte4 & ONE);
                // int decimal_1 = ((byte4>>1) & ONE);
                // int decimal_2 = ((byte4>>2) & ONE);
                // int decimal_3 = ((byte4>>3) & ONE);

                // HEX[0] = LED_display[hex_val_0];
                // HEX[1] = LED_display[hex_val_1];
                // HEX[2] = LED_display[hex_val_2];
                // HEX[3] = LED_display[hex_val_3];

                // if(decimal_0 == 1){
                //     HEX[0] = (decimal_mask | HEX[0]);
                // } 
                // if(decimal_1 == 1) {
                //     HEX[1] = (decimal_mask | HEX[1]);
                // } 
                // if(decimal_2 == 1){
                //     HEX[2] = (decimal_mask | HEX[2]);
                // } 
                // if(decimal_3 == 1){
                //     HEX[3] = (decimal_mask | HEX[3]);
                // } 


                if(LED0_on == 1){
                    hex_val = (hex_byte & mask_all);
                    dec_val = (byte4 & ONE);

                    HEX[0] = LED_display[hex_val];

                    if(dec_val == 1){
                    HEX[0] = (decimal_mask | HEX[0]);
                    } 
                    LED_SETTING[2] = HEX[0];
                }
                else{
                    // if(dec_val == 1){                        //if only the decimal point is to be displayed
                    // LED_SETTING[2] = decimal_mask;
                    // }
                    // else{
                    //     LED_SETTING[2] = BLANK;
                    // }
                    LED_SETTING[2] = BLANK;
                }


                if(LED1_on == 1){
                    hex_val = ((hex_byte>>4) & mask_12b);
                    dec_val = ((byte4>>1) & ONE);

                    HEX[1] = LED_display[hex_val];

                    if(dec_val == 1) {
                    HEX[1] = (decimal_mask | HEX[1]);
                    } 
                    LED_SETTING[3] = HEX[1];
                }
                else{
                    LED_SETTING[3] = BLANK;
                }


                if(LED2_on == 1){
                    hex_val = ((hex_byte>>8) & mask_8b);
                    dec_val = ((byte4>>2) & ONE);

                    HEX[2] = LED_display[hex_val];

                    if(dec_val == 1){
                    HEX[2] = (decimal_mask | HEX[2]);
                    } 
                    LED_SETTING[4] = HEX[2];
                }
                else{
                    LED_SETTING[4] = BLANK;
                }


                if(LED3_on == 1){
                    hex_val = ((hex_byte>>12) & mask_4b);
                    dec_val = ((byte4>>3) & ONE);

                    HEX[3] = LED_display[hex_val];

                    if(dec_val == 1){
                    HEX[3] = (decimal_mask | HEX[3]);
                    } 
                    LED_SETTING[5] = HEX[3];
                }
                else{
                    LED_SETTING[5] = BLANK;
                }


                if(tuxctl_ldisc_put(tty, LED_SETTING, 6) == 0){
                    int i;
                    for (i=0; i<6; i++){
                        
                        LED_RESTORE[i] = LED_SETTING[i];
                    }
                }
                return 0;
            }

        }

        default:
            return -EINVAL;
    }
}
