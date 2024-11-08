import numpy as np
from gnuradio import gr
import pmt
import logging
class blk(gr.sync_block):
    """Random Number Generator"""
    def __init__(self, min_val=0, max_val=1):
        gr.sync_block.__init__(
            self,
            name='Random Number Generator',
            in_sig=None,
            out_sig=None)
        
        self.min_val = float(min_val)
        self.max_val = float(max_val)
        
        # Message ports
        self.message_port_register_in(pmt.intern('trigger'))
        self.message_port_register_out(pmt.intern('rand_out'))
        self.set_msg_handler(pmt.intern('trigger'), self.handle_trigger)
        
        # Setup logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger("random_num_gen")
    
    def set_min_val(self, min_val):
        """Callback to update minimum value"""
        self.min_val = float(min_val)
        
    def set_max_val(self, max_val):
        """Callback to update maximum value"""
        self.max_val = float(max_val)
        
    def handle_trigger(self, msg):
        # Generate new random number
        rand_num = np.random.uniform(self.min_val, self.max_val)
        
        # Create message
        msg = pmt.from_double(rand_num)
        
        # Send the message
        self.message_port_pub(pmt.intern('rand_out'), msg)
        
        # Log
        self.logger.info(f"Sending random number: {rand_num}")

    def work(self, input_items, output_items):
        return 0
