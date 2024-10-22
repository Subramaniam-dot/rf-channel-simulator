import numpy as np
from gnuradio import gr
import gr.pmt as pmt
from collections import deque
import logging

class custom_file_writer(gr.sync_block):
    def __init__(self, filename='output.dat', num_samples=1024, modulation_scheme="BPSK", snr=10, freq_offset=0.0):
        gr.sync_block.__init__(self, name="custom_file_writer", in_sig=[np.complex64], out_sig=None)

        self.counter = 0
        self.samples_per_file = num_samples
        self.filename = filename
        self.modulation_scheme = modulation_scheme
        self.snr = snr
        self.freq_offset = freq_offset

        self.buffer = deque()
        self.message_port_register_in(pmt.intern("enable_write"))
        self.set_msg_handler(pmt.intern("enable_write"), self.handle_message)

        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger("custom_file_writer")

    def handle_message(self, msg):
        if pmt.is_true(msg):
            self.write_to_file()

    def write_metadata_file(self, filename):
        meta_filename = filename.replace(".dat", ".txt")
        with open(meta_filename, 'w') as meta_file:
            meta_file.write(f"Modulation Scheme = {self.modulation_scheme}\n")
            meta_file.write(f"Signal to Noise Ratio = {self.snr} dB\n")
            meta_file.write(f"Frequency Offset = {self.freq_offset}\n")

    def write_to_file(self):
        if len(self.buffer) < self.samples_per_file:
            return

        filename = f"{self.filename}_{self.counter}.dat"
        with open(filename, 'ab') as f:
            samples_to_write = list(self.buffer)[:self.samples_per_file]
            f.write(np.array(samples_to_write).tobytes())
        self.write_metadata_file(filename)

        for _ in range(self.samples_per_file):
            self.buffer.popleft()
        self.counter += 1

    def work(self, input_items, output_items):
        self.buffer.extend(input_items[0])
        return len(input_items[0])
