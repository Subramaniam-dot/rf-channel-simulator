import numpy as np
from gnuradio import gr
import pmt
from collections import deque
import logging
import os

class custom_file_writer(gr.sync_block):
    def __init__(self, filename='output.dat', num_samples=1024, modulation_scheme="BPSK", 
                 snr=10.0, freq_offset=0.0, auto_write=True, output_dir="./data"):
        gr.sync_block.__init__(self,
            name="custom_file_writer",
            in_sig=[np.complex64],
            out_sig=None)
            
        self.counter = 0
        self.samples_per_file = num_samples
        self.filename = filename
        self.modulation_scheme = modulation_scheme
        self.snr = snr
        self.freq_offset = freq_offset
        self.buffer = deque()
        self.auto_write = auto_write
        self.output_dir = output_dir
        self.writing_enabled = False
        
        # Create output directory if it doesn't exist
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Register message ports
        self.message_port_register_in(pmt.intern("write_trigger"))
        self.message_port_register_in(pmt.intern("reset"))
        self.message_port_register_out(pmt.intern("status"))
        
        # Set message handlers
        self.set_msg_handler(pmt.intern("write_trigger"), self.handle_write_trigger)
        self.set_msg_handler(pmt.intern("reset"), self.handle_reset)
        
        # Setup logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger("custom_file_writer")
        
    def handle_write_trigger(self, msg):
        """Handle write trigger messages"""
        if pmt.is_true(msg):
            self.writing_enabled = True
            self.send_status("Writing Enabled")
        else:
            self.writing_enabled = False
            self.send_status("Writing Disabled")
            
    def handle_reset(self, msg):
        """Reset counter and clear buffer"""
        if pmt.is_true(msg):
            self.counter = 0
            self.buffer.clear()
            self.send_status("Reset Complete")
            
    def send_status(self, message):
        """Send status message through message port"""
        self.message_port_pub(pmt.intern("status"), 
                            pmt.to_pmt(f"{message} (Files: {self.counter})"))
            
    def write_metadata_file(self, filename):
        meta_filename = filename.replace(".dat", ".txt")
        try:
            with open(meta_filename, 'w') as meta_file:
                meta_file.write(f"Modulation Scheme = {self.modulation_scheme}\n")
                meta_file.write(f"Signal to Noise Ratio = {self.snr} dB\n")
                meta_file.write(f"Frequency Offset = {self.freq_offset} Hz\n")
                meta_file.write(f"Number of Samples = {self.samples_per_file}\n")
                meta_file.write(f"File Number = {self.counter}\n")
                meta_file.write(f"Sample Rate = {self.sample_rate} Hz\n")
        except IOError as e:
            self.logger.error(f"Failed to write metadata file: {e}")
            
    def write_to_file(self):
        if len(self.buffer) < self.samples_per_file:
            self.logger.warning(f"Buffer contains only {len(self.buffer)} samples, need {self.samples_per_file}")
            return
            
        # Create full filepath
        filename = os.path.join(self.output_dir, f"{self.filename}_{self.counter}.dat")
        
        try:
            with open(filename, 'wb') as f:
                samples_to_write = list(self.buffer)[:self.samples_per_file]
                samples_array = np.array(samples_to_write, dtype=np.complex64)
                
                # Calculate some statistics
                mean_mag = np.mean(np.abs(samples_array))
                peak_mag = np.max(np.abs(samples_array))
                
                # Write the samples
                samples_array.tofile(f)
                
            self.write_metadata_file(filename)
            
            # Clear written samples from buffer
            for _ in range(self.samples_per_file):
                self.buffer.popleft()
                
            self.counter += 1
            self.send_status(f"Wrote file {self.counter} (Mean: {mean_mag:.2f}, Peak: {peak_mag:.2f})")
            
        except IOError as e:
            self.logger.error(f"Failed to write data file: {e}")
            self.send_status(f"Error writing file: {str(e)}")
            
    def work(self, input_items, output_items):
        if not self.writing_enabled and not self.auto_write:
            return len(input_items[0])
            
        # Add new samples to buffer
        self.buffer.extend(input_items[0])
        
        # Write to file if conditions are met
        if len(self.buffer) >= self.samples_per_file and (self.auto_write or self.writing_enabled):
            self.write_to_file()
            
        return len(input_items[0])