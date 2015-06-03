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
      running = threads.select { |id,status| status == 'run' }.count
      sleeping = threads.select { |id,status| status == 'sleep' }.count
      aborting = threads.select { |id,status| status == 'aborting' }.count
      normally_terminated = threads.select { |id,status| status === false }.count
      exception_terminated = threads.select { |id,status| status.nil? }.count
      puts "> Threads #{threads.count} ... Running (#{running}) Sleeping (#{sleeping}) Aborting (#{aborting}) Terminated: Normally (#{normally_terminated}) Exception (#{exception_terminated})"
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
