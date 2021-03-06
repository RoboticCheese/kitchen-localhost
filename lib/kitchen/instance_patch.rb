# Encoding: UTF-8
#
# Author:: Jonathan Hartman (<j@p4nt5.com>)
#
# Copyright (C) 2015, Jonathan Hartman
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'kitchen'
require 'kitchen/instance'
require_relative 'driver/localhost'
require_relative 'platform/localhost'
require_relative 'transport/localhost'

module Kitchen
  # Monkey patch the Kitchen::Instance class with the default configs for the
  # Localhost driver/transport.
  #
  # @author Jonathan Hartman <j@p4nt5.com>
  class Instance
    class << self
      #
      # Define a Mutex at the class level so we can prevent instances using
      # the Localhost driver from colliding.
      #
      # @return [Mutex]
      #
      def lock
        @lock ||= Mutex.new
      end
    end

    alias old_test test

    #
    # If using the Localhost driver, don't start the test phase until we can
    # get a lock on the class-level Mutex.
    #
    # (see Instance#test)
    #
    def test(destroy_node = :passing)
      if driver.class == Kitchen::Driver::Localhost
        debug("[Localhost] Waiting for a lock before #{to_str} can proceed...")
        self.class.lock.synchronize do
          debug("[Localhost] Lock obtained for #{to_str}; proceeding...")
          old_test(destroy_node)
          debug("[Localhost] Test complete for #{to_str}; releasing lock...")
        end
      else
        old_test(destroy_node)
      end
    end

    alias old_setup_transport setup_transport

    #
    # If using the Localhost driver, force usage of the Localhost transport.
    #
    # (see Instance#setup_transport)
    #
    def setup_transport
      if driver.class == Kitchen::Driver::Localhost
        @transport = Kitchen::Transport::Localhost.new
      end
      old_setup_transport
    end

    #
    # If using the Localhost driver, use the custom Platform class to figure
    # out whether we need to use PowerShell or not.
    #
    # (see Instance#platform)
    #
    def platform
      if driver.class == Kitchen::Driver::Localhost && \
         @platform.class != Kitchen::Platform::Localhost
        @platform = Kitchen::Platform::Localhost.new(
          name: @platform.name,
          os_type: @platform.os_type,
          shell_type: @platform.shell_type
        )
      end
      @platform
    end
  end
end
