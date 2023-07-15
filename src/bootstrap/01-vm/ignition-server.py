#!/usr/bin/env python
# SPDX-License-Identifier: MIT
#
# Starts a basic HTTPS server for serving the ignition file downloaded
# by our custom ISO of Fedora CoreOS

from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
import logging
import os
from pathlib import Path
import re
import ssl
import subprocess
import tempfile

class Server:
    def __init__(self):
        self.log = logging.getLogger(self.__class__.__name__)
        
        # Extract needed configuration for server
        self.port=int(os.environ['SERVER_PORT'])
        self.ca=f"{ROOT}/{os.environ['IG_CA']}"
        self.cert=f"{ROOT}/{os.environ['IG_CERT']}"
        self.key=f"{ROOT}/{os.environ['IG_KEY']}"
        
    def serve(self):
        log.info(f"Starting webserver on port {self.port}")
        httpd = HTTPServer(('', self.port), SimpleHTTPRequestHandler)

        self.log.info(f"Adding TLS wrapper using:\n"
                f"key={self.key}\n"
                f"cert={self.cert}\n"
                f"ca={self.ca}")
        
        # Need to decrypt the private key
        with tempfile.NamedTemporaryFile() as file:
            subprocess.run(["sops", "--decrypt", f"{self.key}"], stdout=file)
               
            httpd.socket = ssl.wrap_socket (httpd.socket, 
                                            keyfile=file.name, 
                                            certfile=self.cert,
                                            ca_certs=self.ca,
                                            server_side=True)
            self.log.info("Serve...")
            try:
                httpd.serve_forever()
            except:
                self.log.exception("Server terminated")
    
def main():
    server = Server()
    server.serve()

def setup_logging():
    # Setup logging
    console_logger.setFormatter(log_formatter)
    file_logger.setFormatter(log_formatter)
    logging.basicConfig(handlers=[console_logger, file_logger],
                        level=logging.NOTSET)

def reconfigure_logger():
    if "LOG_LEVEL" in os.environ:
        level = int(os.environ["LOG_LEVEL"])
        if level <= 2:
            log.setLevel(logging.NOTSET)
        if level == 3:
            log.setLevel(logging.DEBUG)
        elif level == 4:
            log.setLevel(logging.INFO)
        elif level == 5:
            log.setLevel(logging.WARNING)
        elif level == 6:
            log.setLevel(logging.ERROR)
        elif level == 7:
            log.setLevel(logging.CRITICAL)
        
        if level >= 8:
            log.propagate = False
        else:
            log.propagate = True
            
    if "LOG_CONSOLE" in os.environ:
        if int(os.environ["LOG_CONSOLE"]) == 0:
            log.removeHandler(console_logger)
        else:
            log.addHandler(console_logger)

def load_config():
    all_config_files = f".config/default.config:{os.environ['LOCAL_CONFIG']}"
    log.info(f"Loading configuration: {all_config_files}")
    for cfile in re.finditer(r'[^:]+', all_config_files):
        with open(f"{ROOT}/{cfile.group(0)}") as file:
            log.info(f"Loading from: {file}")
            for line in file:
                if re.match(r'^(\s*#.*)|(\s*)$', line):
                    log.debug(f"Ignoring line: {line.strip()}")
                else:
                    key, val = line.split('=')
                    key = key.strip()
                    val = val.strip()
                    log.info(f"Adding: {key}={val}")        
                    os.environ[key] = val
                    if key == "LOG_LEVEL" or key == "LOG_CONSOLE":
                        reconfigure_logger()

# Get ROOT of this repo
process = subprocess.Popen(["git", "rev-parse", "--show-toplevel"], stdout=subprocess.PIPE)
ROOT = process.communicate()[0].decode("utf-8").strip()

log = logging.getLogger()
log_formatter = logging.Formatter(fmt="%(asctime)s %(levelname)-5s %(message)s", datefmt="%F %H:%M:%S")
console_logger = logging.StreamHandler()
log_filename=f'{ROOT}/.log/{Path(__file__).stem}_{datetime.now().strftime("%F_%H%M%S")}.log'
file_logger = logging.FileHandler(filename=log_filename, encoding='utf-8', mode='a+')
                    
if __name__ == "__main__":
    setup_logging()

    log.info(f"== {Path(__file__).name} Started ==")

    load_config()
    main()
    
    log.info(f"== {Path(__file__).name} Exited gracefully ==")