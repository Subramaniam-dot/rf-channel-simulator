"""
Embedded Python Block for Custom File Writer
"""

import numpy as np
from gnuradio import gr
import pmt
from collections import deque
import logging
import os

class blk(gr.sync_block):
    def __init__(self, filename='output', num_samples=2048,
             modulation_scheme="AM", snr=10000.0, freq_offset=1000.0, max_files=500):
        gr.sync_block.__init__(
            self,
            name='Custom File Writer',
            in_sig=[np.complex64],
            out_sig=None)

        # Register message ports
        self.message_port_register_in(pmt.intern("enable_write"))
        self.set_msg_handler(pmt.intern("enable_write"), self.handle_message)
        # Add output message port for write signal
        self.message_port_register_out(pmt.intern("write"))
    
        # Parameters
        self._last_snr = None
        self._last_freq_offset = None
        self.snr = float(snr)
        self.freq_offset = float(freq_offset)
        self.counter = 0
        self.samples_per_file = int(num_samples)
        self.base_filename = str(filename)
        self.modulation_scheme = str(modulation_scheme)
        self.max_files = int(max_files)
        self.buffer = deque()
        self.done = False
        self.enable_write = False
        
        # Setup logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger("custom_file_writer")
        
        # Setup initial directory
        self.setup_directory()
        
        self.logger.info(f"Initialized with SNR={self.snr}, freq_offset={self.freq_offset}")

    def set_snr(self, snr):
        """SNR parameter callback"""
        self.snr = float(snr)
        self.logger.info(f"SNR changed to: {self.snr}")
        self.check_parameters()

    def set_freq_offset(self, freq_offset):
        """Frequency offset parameter callback"""
        self.freq_offset = float(freq_offset)
        self.logger.info(f"Frequency offset changed to: {self.freq_offset}")
        self.check_parameters()

    def check_parameters(self):
        """Check if parameters have changed"""
        if (self._last_snr != self.snr) or (self._last_freq_offset != self.freq_offset):
            self.logger.info(f"New parameter combination detected - SNR: {self.snr}, Freq Offset: {self.freq_offset}")
            self._last_snr = self.snr
            self._last_freq_offset = self.freq_offset
            self.counter = 0
            self.done = False
            self.setup_directory()
            return True
        return False

    def setup_directory(self):
        """Create directory for current parameters"""
        # Remove freq_offset from directory name since it changes for each file
        self.dir_name = f"mod_{self.modulation_scheme}_snr_{self.snr}"
        if not os.path.exists(self.dir_name):
            os.makedirs(self.dir_name)
        self.filename = os.path.join(self.dir_name, self.base_filename)
        self.logger.info(f"Created directory: {self.dir_name}")
	    
    def write_metadata_file(self, filename):
        """Write metadata file with current parameters"""
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
 
    def handle_message(self, msg):
        """Handle enable_write messages"""
        try:
            if pmt.is_pair(msg):
                value = pmt.to_python(pmt.cdr(msg))
            elif pmt.is_bool(msg):
                value = pmt.to_python(msg)
            else:
                value = bool(pmt.to_python(msg))
            
            self.enable_write = value
            
            if self.enable_write:
                # Always check parameters when writing is enabled
                self.check_parameters()
                if not self.done:
                    self.write_to_file()
                else:
                    self.logger.info(f"Already completed {self.max_files} files for current parameters")
        except Exception as e:
            self.logger.error(f"Error in message handler: {e}")

    def write_to_file(self):
        """Write samples to file"""
        if self.done or not self.enable_write:
            return
            
        if len(self.buffer) < self.samples_per_file:
            self.logger.warning(f"Buffer contains only {len(self.buffer)} samples, need {self.samples_per_file}")
            return
            
        # Send write trigger message before writing file
        self.message_port_pub(pmt.intern("write"), pmt.to_pmt("trigger"))
        
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
                self.enable_write = False
                self.logger.info(f"Completed generating {self.max_files} files for {self.dir_name}")
        except IOError as e:
            self.logger.error(f"Failed to write data file: {e}")

    def work(self, input_items, output_items):
        """Process incoming samples"""
        if self.done:
            return len(input_items[0])
            
        self.buffer.extend(input_items[0])
        
        if len(self.buffer) >= self.samples_per_file and self.enable_write and not self.done:
            self.write_to_file()
            
        return len(input_items[0])
