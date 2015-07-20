require 'json'
require 'celluloid/current'

class Cellumon

  include Celluloid

  class << self
    def start!(options={})
      name = options.fetch(:name, :cellumon)
      monitors = options.delete(:monitors)
      return unless monitors.is_a? Array
      Cellumon.supervise(as: name, args: [options])
      monitors.each { |monitor| Celluloid[name].send("start_#{monitor}!") }
      Celluloid[name]
    end
  end

  MONITORS = {
    thread_survey: 30,
    thread_report: 15,
    thread_summary: 1,
    memory_count: 13
  }

  def initialize(options={})
    @semaphor = {}
    @status = {}
    @timers = {}
    @logger = options.fetch(:logger, nil)
    @mark = options.fetch(:mark, false)
    @intervals = MONITORS.dup
  end

  def mark
    @mark ? "Cellumon > " : ""
  end

  MONITORS.each { |m,i|
    define_method(:"start_#{m}!") { |interval=nil|
      async.send(:"starting_#{m}")
    }
    define_method(:"starting_#{m}") { |interval=nil|
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
      total = `pmap #{Process.pid} | tail -1`[10,40].strip[0..-1]
      console("Memory usage: #{memory(total)}")
      ready! :memory_count
    end    
    @timers[:memory_count] = after(@intervals[:memory_count]) { memory_count! }
  end

  def memory(total)
    total = total.to_i
    gb = (total / (1024 * 1024)).to_i
    mb = total % gb
    "#{'%0.2f' % "#{gb}.#{mb}"}gb" #de Very fuzzy math but fine for now.
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
      r = threads.select { |id,status| status == 'run' }.count
      s = threads.select { |id,status| status == 'sleep' }.count
      a = threads.select { |id,status| status == 'aborting' }.count
      nt = threads.select { |id,status| status === false }.count
      te = threads.select { |id,status| status.nil? }.count
      console "Threads #{threads.count}: #{r}r #{s}s #{a}a #{nt}nt #{te}te"
      ready! :thread_report
    end
    @timers[:thread_report] = after(@intervals[:thread_report]) { thread_report! }
  end

  def console(message)
    if @logger && @logger.respond_to?(:console)
      @logger.console("#{mark}#{message}", reporter: "Cellumon")
    else
      message = "*, [#{Time.now.strftime('%FT%T.%L')}] #{mark}#{message}"
      STDERR.puts message
      STDOUT.puts message
    end
  end

  private

  [:ready, :running, :stopped].each { |state|
    define_method("#{state}!") { |monitor|
      @semaphor[monitor].synchronize { @status[monitor] = state }
    }
    define_method("#{state}?") { |monitor|
      @semaphor[monitor].synchronize { @status[monitor] == state }
    }
  }

  def output object
    puts JSON.pretty_generate(object)
  end

end
