require 'json'
require 'celluloid/current'

class Cellumon

  include Celluloid

  class << self
    def start!(name=:cellumon)
      puts "* Starting Cellumon"
      Cellumon.supervise(as: name)
    end
  end

  INTERVALS = {
    :thread_survey => 30,
    :thread_report => 15,
    :thread_summary => 1
  }

  def initialize
    @semaphor = {}
    @status = {}

    INTERVALS.each { |monitor, interval|
      @semaphor[monitor] = Mutex.new
      @status[monitor] = :initializing
      async.send :"#{monitor}!"
      ready! monitor
    }
  end

    def thread_survey!
      if ready? :thread_survey
        output Celluloid.stack_summary
        ready! :thread_survey
      end
      after(INTERVALS[:thread_survey]) { thread_survey! }
    end

  def thread_summary!
    if ready? :thread_summary
      print " #{Thread.list.count} "
      ready! :thread_summary
    end
    after(INTERVALS[:thread_summary]) { thread_summary! }
  end

  def thread_report!
    if ready? :thread_report
      threads = Thread.list.inject({}) { |l,t| l[t.object_id] = t.status; l }
      puts "> Status: Threads #{threads.count}"
      puts "* Running: #{threads.select { |id,status| status == 'run' }.count}"
      puts "* Sleeping: #{threads.select { |id,status| status == 'sleep' }.count}"
      puts "* Aborting: #{threads.select { |id,status| status == 'aborting' }.count}"
      puts "* Terminated Normally: #{threads.select { |id,status| status === false }.count}"
      puts "* Terminated by Exception: #{threads.select { |id,status| status.nil? }.count}"
      ready! :thread_report
    end
    after(INTERVALS[:thread_report]) { thread_report! }
  end

  private

  def ready! monitor
    @semaphor[monitor].synchronize { @status[monitor] = :ready }
  end

  def running! monitor
    @semaphor[monitor].synchronize { @status[monitor] = :running }
  end

  def ready? monitor
    @semaphor[monitor].synchronize { @status[monitor] == :ready }
  end

  def output object
    puts JSON.pretty_generate(object)
  end

end
