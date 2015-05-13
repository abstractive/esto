$LOAD_PATH.push(File.expand_path("../../lib/", __FILE__))
require 'system_monitor'

SystemMonitor.start!

sleep