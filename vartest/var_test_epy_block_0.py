import numpy as np
from gnuradio import gr
import pmt
import random

class blk(gr.sync_block):
    def __init__(self, samp_rate=32000):  # Add samp_rate parameter
        gr.sync_block.__init__(
            self,
            name='Random Frequency Generator',
            in_sig=None,
            out_sig=None)
        self.samp_rate = samp_rate  # Store samp_rate
        self.message_port_register_in(pmt.intern('trigger'))
        self.message_port_register_out(pmt.intern('freq'))
        self.set_msg_handler(pmt.intern('trigger'), self.handle_trigger)
        
    def handle_trigger(self, msg):
        # Generate random frequency between -samp_rate/2 and +samp_rate/2
        new_freq = random.uniform(-self.samp_rate/2, self.samp_rate/2)
        # Create PMT message
        msg = pmt.cons(pmt.intern("freq"), pmt.from_double(new_freq))
        # Send the message
        self.message_port_pub(pmt.intern('freq'), msg)

    def work(self, input_items, output_items):
        return len(output_items[0])
