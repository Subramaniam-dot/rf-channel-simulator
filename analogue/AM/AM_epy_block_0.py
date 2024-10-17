import numpy as np
from gnuradio import gr

class custom_file_writer(gr.sync_block):
    def __init__(self, filename='output.dat', num_samples=1024):
        gr.sync_block.__init__(self, name="custom_file_writer", in_sig=[np.complex64], out_sig=None)
        self.counter = 0
        self.samples_per_file = num_samples
        self.filename = filename

        # Create message port for enabling writing
        self.message_port_register_in(gr.pmt.intern("enable_write"))
        self.set_msg_handler(gr.pmt.intern("enable_write"), self.handle_message)

        # Buffer to hold incoming data
        self.buffer = []

    def handle_message(self, msg):
        # Check if the message is a boolean 'true' (1)
        if gr.pmt.is_true(msg):
            self.write_to_file()

    def write_to_file(self):
        # Check if there are enough samples in the buffer
        if len(self.buffer) < self.samples_per_file:
            return  # Not enough data to write

        # Write the specified number of samples to a file
        filename = f"{self.filename}_{self.counter}.dat"
        with open(filename, 'ab') as f:
            # Write the first `num_samples` samples to the file
            f.write(np.array(self.buffer[:self.samples_per_file]).tobytes())
        
        # Remove written samples from buffer
        self.buffer = self.buffer[self.samples_per_file:]  
        
        self.counter += 1

    def work(self, input_items, output_items):
        # Append incoming samples to the buffer
        self.buffer.extend(input_items[0])  # Add new samples to the buffer
        return len(input_items[0])  # Return the number of samples processed

