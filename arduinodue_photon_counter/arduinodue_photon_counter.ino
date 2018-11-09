
/*
 Test Sketch for an Arduino DUE board, 
 Period/Duty Cycle measurements on PWM signals.
 Created by Anatoly Kuzmenko, August 2015
 Released into the public domain.
 k_anatoly@hotmail.com
*/

// Name - Port - Pin(DUE board) 
// TIOA1 = PA2 = AD7


char in_Byte;
volatile uint16_t pos = 0;
volatile uint32_t tmr_RB[2048];  
volatile uint32_t read_s = 0;  

         int debug_osm = 0; // debug over serial monitor 

void setup()
{
  SerialUSB.begin (115200); 
  Btmr_setup();         
  pio_TIOA1();  // IN, AN - 7 (max 3.3V -> keep safe !!!).

}

void loop() 
{

    if( read_s && debug_osm ) {
      SerialUSB.write((uint8_t *)tmr_RB, 8192); 
      read_s = 0;
    }

    if( SerialUSB.available() > 0 ) {
    in_Byte = SerialUSB.read();
    if( in_Byte == 'd' ) { //debug           
      debug_osm = 1 - debug_osm;
      if (debug_osm) {
        pos=0;
      }
      }
    }  

}

void TC1_Handler(void)
{
if ((TC_GetStatus(TC0, 1) & TC_SR_LDRBS) == TC_SR_LDRBS) {

  //tmr_RA = TC0->TC_CHANNEL[1].TC_RA; //falling edge?
  pos=pos+1;
  tmr_RB[pos] = TC0->TC_CHANNEL[1].TC_RB;
  if (pos==2048) {
    pos=0;
    read_s = 1;
    };
  }
}

void Btmr_setup()  // Counter
{
  pmc_enable_periph_clk (TC_INTERFACE_ID + 0 *3 + 1);

  TcChannel * t = &(TC0->TC_CHANNEL)[1];
  t->TC_CCR = TC_CCR_CLKDIS;
  t->TC_IDR = 0xFFFFFFFF;   
  t->TC_SR;   

  t->TC_CMR = TC_CMR_TCCLKS_TIMER_CLOCK1

             | TC_CMR_LDRA_RISING     
             | TC_CMR_LDRB_FALLING    
             | TC_CMR_ABETRG          
             | TC_CMR_ETRGEDG_FALLING;
             
  t->TC_CCR = TC_CCR_CLKEN | TC_CCR_SWTRG; 

  t->TC_IER =  TC_IER_LDRBS;
  t->TC_IDR = ~TC_IER_LDRBS;

  NVIC_DisableIRQ(TC1_IRQn);
  NVIC_ClearPendingIRQ(TC1_IRQn);
  NVIC_SetPriority(TC1_IRQn, 0); 
  NVIC_EnableIRQ(TC1_IRQn);
}

void pio_TIOA1() 
{
  PIOA->PIO_PDR = PIO_PA2A_TIOA1;  
  PIOA->PIO_IDR = PIO_PA2A_TIOA1;
}
