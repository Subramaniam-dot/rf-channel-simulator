import numpy as np
from gnuradio import gr
import pmt
import random
import logging

class blk(gr.sync_block):
    def __init__(self, samp_rate=32000, num_files=200):
        gr.sync_block.__init__(
            self,
            name='Random Frequency Generator',
            in_sig=None,
            out_sig=None)
        self.samp_rate = samp_rate
        self.num_files = num_files
        self.current_file = 0
        # Pre-generate all frequencies
        self.frequencies = np.random.uniform(-self.samp_rate/2, self.samp_rate/2, self.num_files)
        self.message_port_register_in(pmt.intern('trigger'))
        self.message_port_register_out(pmt.intern('freq'))
        self.set_msg_handler(pmt.intern('trigger'), self.handle_trigger)
        
        # Setup logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger("random_freq_gen")
        
    def handle_trigger(self, msg):
        # Get the pre-generated frequency for current file
        new_freq = self.frequencies[self.current_file % self.num_files]
        
        # Create PMT message
        msg = pmt.cons(pmt.intern("freq"), pmt.from_double(new_freq))
        
        # Send the message
        self.message_port_pub(pmt.intern('freq'), msg)
        
        # Log the sent frequency
        self.logger.info(f"Sending frequency {new_freq} Hz for file {self.current_file + 1}")
        
        # Increment counter
        self.current_file += 1
        
        # If we've used all frequencies, generate new ones
        if self.current_file >= self.num_files:
            self.current_file = 0
            self.frequencies = np.random.uniform(-self.samp_rate/2, self.samp_rate/2, self.num_files)
            self.logger.info("Generated new set of frequencies")

    def work(self, input_items, output_items):
        return len(output_items[0])
