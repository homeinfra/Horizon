#!/usr/bin/env python
# SPDX-License-Identifier: MIT

"""
Starts a basic HTTPS server for serving the ignition file used by Fedora CoreOS.

We use a custom ISO configured to download this file using the current config.
"""
from datetime import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
import logging
import os
from pathlib import Path
import re
import ssl
import subprocess
import tempfile
from dotenv import load_dotenv

def main():
  """Entry point for the ignition server."""

  log_config = LoggerConfig()
  logging.info("== %s Started ==", Path(__file__).name)
  load_config(log_config)

  Server().serve()

  logging.info("== %s Exited gracefully ==", Path(__file__).name)


class Server: #noqa
  """Class implementing the server."""

  def __init__(self):
    """Read configuration."""
    self.__log = logging.getLogger(self.__class__.__name__)

    # Extract needed configuration for server
    self.__port = int(os.environ['SERVER_PORT'])
    self.__ca = f"{ROOT}/{os.environ['IG_CA']}"
    self.__cert = f"{ROOT}/{os.environ['IG_CERT']}"
    self.__key = f"{ROOT}/{os.environ['IG_KEY']}"

  def serve(self):
    """Start the server."""
    self.__log.info("Starting webserver on port %d", self.__port)

    httpd = HTTPServer(('', self.__port), SimpleHTTPRequestHandler)

    self.__log.info("Adding TLS wrapper using:\nkey=%s\ncert=%s\nca=%s",
                    self.__key, self.__cert, self.__ca)

    # Need to decrypt the private key
    with tempfile.NamedTemporaryFile() as file:
      subprocess.run(["sops", "--decrypt", f"{self.__key}"], stdout=file, check=True)

      context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
      context.load_verify_locations(self.__ca)
      context.load_cert_chain(self.__cert, file.name)
      httpd.socket = context.wrap_socket(httpd.socket, server_side=True)

      self.__log.info("Serve...")
      try:
        httpd.serve_forever()
      except BaseException: # noqa
        self.__log.exception("Server terminated")


class LoggerConfig: #noqa
  """Logger Configuration."""

  def __init__(self):
    """Configure the root logger."""
    self.__filename = f'{ROOT}/.log/{Path(__file__).stem}_' \
                      f'{datetime.now().strftime("%F_%H%M%S")}.log'
    self.__console = logging.StreamHandler()
    self.__file = logging.FileHandler(filename=self.__filename, encoding='utf-8', mode='a+')
    logging.basicConfig(handlers=[self.__console, self.__file], level=logging.NOTSET,
                        datefmt="%F %H:%M:%S", format="%(asctime)s [%(levelname)-6s] %(message)s")

    # Levels as defined by logger-shell
  def _set_level(self, level):
    if level <= 2:
      logging.root.setLevel(logging.NOTSET)
    if level == 3:
      logging.root.setLevel(logging.DEBUG)
    elif level == 4:
      logging.root.setLevel(logging.INFO)
    elif level == 5:
      logging.root.setLevel(logging.WARNING)
    elif level == 6:
      logging.root.setLevel(logging.ERROR)
    elif level == 7:
      logging.root.setLevel(logging.CRITICAL)


  def reconfigure(self):
    """Force a reconfiguration of the logger."""
    if "LOG_LEVEL" in os.environ:
      level = int(os.environ["LOG_LEVEL"])
      self._set_level(level)

      if "LOG_CONSOLE" in os.environ:
        if int(os.environ["LOG_CONSOLE"]) == 0:
          logging.root.removeHandler(self.__console)
        else:
          logging.root.addHandler(self.__console)

def load_config(log_config):
  """Load project configuration."""
  filename=f"{ROOT}/.config/default.env"
  logging.info("Loading configuration from: %s", filename)
  load_dotenv(filename, override=True)

  all_config_files = os.environ['LOCAL_CONFIG']
  for cfile in re.finditer(r'[^:]+', all_config_files):
    filename=f"{ROOT}/{cfile.group(0)}"
    logging.info("Loading configuration from: %s", filename)
    with tempfile.NamedTemporaryFile() as file:
      subprocess.run(["sops", "--decrypt", filename], stdout=file, check=True)
      load_dotenv(file.name, override=True)

  log_config.reconfigure()


# Get ROOT of this repo
with subprocess.Popen(["git", "rev-parse", "--show-toplevel"], stdout=subprocess.PIPE) as process:
  ROOT = process.communicate()[0].decode("utf-8").strip()

# Entry point
if __name__ == "__main__":
  main()
