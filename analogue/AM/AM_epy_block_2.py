import numpy as np
from gnuradio import gr
import pmt

class blk(gr.sync_block):
    def __init__(self):
        gr.sync_block.__init__(
            self,
            name='Message Copy',
            in_sig=None,
            out_sig=None)
            
        self.message_port_register_in(pmt.intern('in'))
        self.message_port_register_out(pmt.intern('out0'))
        self.message_port_register_out(pmt.intern('out1'))
        self.set_msg_handler(pmt.intern('in'), self.handle_msg)
        
    def handle_msg(self, msg):
        # Copy message to both output ports
        self.message_port_pub(pmt.intern('out0'), msg)
        self.message_port_pub(pmt.intern('out1'), msg)

    def work(self, input_items, output_items):
        return len(output_items[0])
