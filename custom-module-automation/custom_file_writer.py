import numpy as np
from gnuradio import gr
import pmt
from collections import deque
import logging
import os

class custom_file_writer(gr.sync_block):
    def __init__(self, filename='output.dat', num_samples=1024, 
                 modulation_scheme="BPSK", snr=10.0, freq_offset=0.0, max_files=500):
        gr.sync_block.__init__(self,
            name="custom_file_writer",
            in_sig=[np.complex64],
            out_sig=None)
        
        self.counter = 0
        self.samples_per_file = num_samples
        self.base_filename = filename
        self.modulation_scheme = modulation_scheme
        self.snr = snr
        self.freq_offset = freq_offset
        self.buffer = deque()
        self.max_files = max_files
        self.done = False
        
        # Create directory structure
        self.setup_directory()
        
        # Register message port
        self.message_port_register_in(pmt.intern("enable_write"))
        self.set_msg_handler(pmt.intern("enable_write"), self.handle_message)
        
        # Setup logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger("custom_file_writer")

    def setup_directory(self):
        # Create a directory structure based on parameters
        self.dir_name = f"mod_{self.modulation_scheme}_snr_{self.snr}_freq_{self.freq_offset}"
        if not os.path.exists(self.dir_name):
            os.makedirs(self.dir_name)
        self.filename = os.path.join(self.dir_name, self.base_filename)

    def handle_message(self, msg):
        if pmt.is_true(msg) and not self.done:
            self.write_to_file()

    def write_metadata_file(self, filename):
        meta_filename = filename.replace(".dat", ".txt")
        try:
            with open(meta_filename, 'w') as meta_file:
                meta_file.write(f"Modulation Scheme = {self.modulation_scheme}\n")
                meta_file.write(f"Signal to Noise Ratio = {self.snr} dB\n")
                meta_file.write(f"Frequency Offset = {self.freq_offset} Hz\n")
                meta_file.write(f"Number of Samples = {self.samples_per_file}\n")
                meta_file.write(f"File Number = {self.counter + 1} of {self.max_files}\n")
        except IOError as e:
            self.logger.error(f"Failed to write metadata file: {e}")

    def write_to_file(self):
        if self.done:
            return

        if len(self.buffer) < self.samples_per_file:
            self.logger.warning(f"Buffer contains only {len(self.buffer)} samples, need {self.samples_per_file}")
            return
            
        filename = f"{self.filename}_{self.counter}.dat"
        try:
            with open(filename, 'wb') as f:
                samples_to_write = list(self.buffer)[:self.samples_per_file]
                f.write(np.array(samples_to_write, dtype=np.complex64).tobytes())
                
            self.write_metadata_file(filename)
            
            for _ in range(self.samples_per_file):
                self.buffer.popleft()
            
            self.counter += 1
            self.logger.info(f"Writing to {self.dir_name}: File {self.counter} of {self.max_files}")
            
            if self.counter >= self.max_files:
                self.done = True
                self.logger.info(f"Completed generating {self.max_files} files for {self.dir_name}")
                
        except IOError as e:
            self.logger.error(f"Failed to write data file: {e}")

    def work(self, input_items, output_items):
        if self.done:
            return len(input_items[0])
            
        self.buffer.extend(input_items[0])
        
        if len(self.buffer) >= self.samples_per_file and not self.done:
            self.write_to_file()
            
        return len(input_items[0])