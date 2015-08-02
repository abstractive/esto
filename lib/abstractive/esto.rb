require 'json'
require 'colorize'
require 'abstractive'
require 'abstractive/timespans'
require 'abstractive/actor'

class Abstractive::Esto < Abstractive::Actor

  extend Forwardable
  def_delegators :"Abstractive::TimeSpans", :duration, :readable_duration

  class << self
    def start!(options={})
      name = options.delete(:name) || :esto
      Abstractive::Esto.supervise(as: name, args: [options])
      Celluloid[name]
    end
  end

  MONITORS = {
    uptime: 90,
    thread_survey: 30,
    thread_report: 15,
    thread_summary: 3,
    memory_count: 13,
    threads_and_memory: 45
  }

  def initialize(options={})
    @semaphor = {}
    @status = {}
    @timers = {}
    @short = options.fetch(:short, false)
    @debug = options.fetch(:debug, false)
    @logger = options.fetch(:logger, nil)
    @declare = options.fetch(:declare, false)
    @intervals = MONITORS.dup
    @options = options
    @running = Hitimes::Interval.now
    async.start
  end

  def start
    if @options[:monitors].is_a?(Array)
      debug("Monitors:") if @debug
      @options[:monitors].each { |monitor|
        debug("* #{monitor} every #{readable_duration(MONITORS[monitor])}.") if @debug
        send("start_#{monitor}!")
      }
    else
      debug("No preconfigured monitors.") if @debug
    end
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
    
  def uptime!
    trigger!(:uptime) { console "#{(@short ? "U" : "Uptime")}: #{readable_duration(@running.duration_so_far)}" }
  end
    
  def memory_count!
    trigger!(:memory_count) { console memory }
  end

  def thread_survey!
    trigger!(:thread_survey) { Celluloid.stack_summary }
  end

  def thread_summary!
    trigger!(:thread_summary) { print " #{Thread.list.count} " }
  end

  def thread_report!
    trigger!(:thread_report) { console threads }
  end

  def threads_and_memory!
    trigger!(:threads_and_memory) { console "#{threads}; #{memory}" }
  end

  private

  def threads
    threads = Thread.list.inject({}) { |l,t| l[t.object_id] = t.status; l }
    r = threads.select { |id,status| status == 'run' }.count
    s = threads.select { |id,status| status == 'sleep' }.count
    a = threads.select { |id,status| status == 'aborting' }.count
    nt = threads.select { |id,status| status === false }.count
    te = threads.select { |id,status| status.nil? }.count
    "#{@short ? "T:" : "Threads "}#{threads.count.to_s.bold}: #{r.to_s.green}r #{s.to_s.cyan}s #{a.to_s.yellow.bold}a #{nt.to_s.light_red}nt #{te.to_s.red.bold}te"
  end

  def memory
    total = `pmap #{Process.pid} | tail -1`[10,40].strip[0..-1].to_i
    gb = (total / (1024 * 1024)).floor
    mb = total / 1024
    #de Fuzzy math but fine for now.
    "#{@short ? "M:" : "Memory: "}#{'%0.2f' % "#{gb}.#{mb}"}gb"
  end

  def trigger!(monitor)
    puts "trigger: #{monitor}" if @debug
    if ready?(monitor)
      result = yield
      ready! monitor
    end
    @timers[monitor].cancel rescue nil
    @timers[monitor] = after(@intervals[monitor]) { send("#{monitor}!") }
    result
  rescue => ex
    exception(ex, "Abstractive::Esto > Failure to trigger: #{monitor}") if @debug
  end

  [:debug,:console].each { |m|
    define_method(m) {|message, options={}|
      super(message, options.merge(reporter: "Abstractive::Esto", declare: @declare))
    }
  }

  [:ready, :running, :stopped].each { |state|
    define_method("#{state}!") { |monitor|
      @semaphor[monitor].synchronize { @status[monitor] = state }
    }
    define_method("#{state}?") { |monitor|
      @semaphor[monitor].synchronize { @status[monitor] == state }
    }
  }

end
