require 'json'
require 'celluloid/current'

class Cellumon

  include Celluloid

  class << self
    def start!(name=:cellumon)
      Cellumon.supervise(as: name)
      Celluloid[:cellumon]
    end
  end

  MONITORS = {
    thread_survey: 30,
    thread_report: 15,
    thread_summary: 1,
    memory_count: 13
  }

  def initialize
    @semaphor = {}
    @status = {}
    @timers = {}
    @intervals = MONITORS.dup
  end

  MONITORS.each { |m,i|
    define_method(:"start_#{m}!") { |interval=nil|
      @intervals[m] = interval || MONITORS[m]
      @timers[m] = nil
      @semaphor[m] = Mutex.new
      @status[m] = :initializing
      async.send :"#{m}!"
      ready! m
    }
    define_method(:"stop_#{m}!") {
      stopped! m
      @timers[m].cancel if @timers[m]
    }
  }
    
  def memory_count!
    if ready? :memory_count
      console("Memory usage: #{`pmap #{Process.pid} | tail -1`[10,40].strip}")
      ready! :memory_count
    end    
    @timers[:memory_count] = after(@intervals[:memory_count]) { memory_count! }
  end

  def thread_survey!
    if ready? :thread_survey
      Celluloid.stack_summary
      ready! :thread_survey
    end
    @timers[:thread_survey] = after(@intervals[:thread_survey]) { thread_survey! }
  end

  def thread_summary!
    if ready? :thread_summary
      print " #{Thread.list.count} "
      ready! :thread_summary
    end
    @timers[:thread_summary] = after(@intervals[:thread_summary]) { thread_summary! }
  end

  def thread_report!
    if ready? :thread_report
      threads = Thread.list.inject({}) { |l,t| l[t.object_id] = t.status; l }
      running = threads.select { |id,status| status == 'run' }.count
      sleeping = threads.select { |id,status| status == 'sleep' }.count
      aborting = threads.select { |id,status| status == 'aborting' }.count
      normally_terminated = threads.select { |id,status| status === false }.count
      exception_terminated = threads.select { |id,status| status.nil? }.count
      console "Threads #{threads.count}; " +
        "Running (#{running}) Sleeping (#{sleeping}) Aborting (#{aborting}); " +
        "Terminated: Normally (#{normally_terminated}) Exception (#{exception_terminated})"
      ready! :thread_report
    end
    @timers[:thread_report] = after(@intervals[:thread_report]) { thread_report! }
  end

  def console(message)
    puts "*, [#{Time.now.strftime('%FT%T.%L')}] Cellumon > #{message}"
  end

  private

  def ready! monitor
    @semaphor[monitor].synchronize { @status[monitor] = :ready }
  end

  def running! monitor
    @semaphor[monitor].synchronize { @status[monitor] = :running }
  end

  def stopped! monitor
    @semaphor[monitor].synchronize { @status[monitor] = :stopped }
  end

  def ready? monitor
    @semaphor[monitor].synchronize { @status[monitor] == :ready }
  end

  def output object
    puts JSON.pretty_generate(object)
  end

end
