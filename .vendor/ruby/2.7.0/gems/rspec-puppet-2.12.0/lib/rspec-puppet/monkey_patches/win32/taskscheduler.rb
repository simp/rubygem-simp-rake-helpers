# Create our dummy Win32::TaskScheduler with the consts defined from
# https://github.com/djberg96/win32-taskscheduler/blob/ole/lib/win32/taskscheduler.rb

require 'rspec-puppet/monkey_patches/windows/taskschedulerconstants'

module RSpec
  module Puppet
    module Win32
      class TaskScheduler
        include Windows::TaskSchedulerConstants

        DAYS_IN_A_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

        IDLE = IDLE_PRIORITY_CLASS
        NORMAL = NORMAL_PRIORITY_CLASS
        HIGH = HIGH_PRIORITY_CLASS
        REALTIME = REALTIME_PRIORITY_CLASS
        BELOW_NORMAL = BELOW_NORMAL_PRIORITY_CLASS
        ABOVE_NORMAL = ABOVE_NORMAL_PRIORITY_CLASS

        ONCE = TASK_TIME_TRIGGER_ONCE
        DAILY = TASK_TIME_TRIGGER_DAILY
        WEEKLY = TASK_TIME_TRIGGER_WEEKLY
        MONTHLYDATE = TASK_TIME_TRIGGER_MONTHLYDATE
        MONTHLYDOW = TASK_TIME_TRIGGER_MONTHLYDOW

        ON_IDLE = TASK_EVENT_TRIGGER_ON_IDLE
        AT_SYSTEMSTART = TASK_EVENT_TRIGGER_AT_SYSTEMSTART
        AT_LOGON = TASK_EVENT_TRIGGER_AT_LOGON
        FIRST_WEEK = TASK_FIRST_WEEK
        SECOND_WEEK = TASK_SECOND_WEEK
        THIRD_WEEK = TASK_THIRD_WEEK
        FOURTH_WEEK = TASK_FOURTH_WEEK
        LAST_WEEK = TASK_LAST_WEEK
        SUNDAY = TASK_SUNDAY
        MONDAY = TASK_MONDAY
        TUESDAY = TASK_TUESDAY
        WEDNESDAY = TASK_WEDNESDAY
        THURSDAY = TASK_THURSDAY
        FRIDAY = TASK_FRIDAY
        SATURDAY = TASK_SATURDAY
        JANUARY = TASK_JANUARY
        FEBRUARY = TASK_FEBRUARY
        MARCH = TASK_MARCH
        APRIL = TASK_APRIL
        MAY = TASK_MAY
        JUNE = TASK_JUNE
        JULY = TASK_JULY
        AUGUST = TASK_AUGUST
        SEPTEMBER = TASK_SEPTEMBER
        OCTOBER = TASK_OCTOBER
        NOVEMBER = TASK_NOVEMBER
        DECEMBER = TASK_DECEMBER

        INTERACTIVE = TASK_FLAG_INTERACTIVE
        DELETE_WHEN_DONE = TASK_FLAG_DELETE_WHEN_DONE
        DISABLED = TASK_FLAG_DISABLED
        START_ONLY_IF_IDLE = TASK_FLAG_START_ONLY_IF_IDLE
        KILL_ON_IDLE_END = TASK_FLAG_KILL_ON_IDLE_END
        DONT_START_IF_ON_BATTERIES = TASK_FLAG_DONT_START_IF_ON_BATTERIES
        KILL_IF_GOING_ON_BATTERIES = TASK_FLAG_KILL_IF_GOING_ON_BATTERIES
        RUN_ONLY_IF_DOCKED = TASK_FLAG_RUN_ONLY_IF_DOCKED
        HIDDEN = TASK_FLAG_HIDDEN
        RUN_IF_CONNECTED_TO_INTERNET = TASK_FLAG_RUN_IF_CONNECTED_TO_INTERNET
        RESTART_ON_IDLE_RESUME = TASK_FLAG_RESTART_ON_IDLE_RESUME
        SYSTEM_REQUIRED = TASK_FLAG_SYSTEM_REQUIRED
        RUN_ONLY_IF_LOGGED_ON = TASK_FLAG_RUN_ONLY_IF_LOGGED_ON

        FLAG_HAS_END_DATE = TASK_TRIGGER_FLAG_HAS_END_DATE
        FLAG_KILL_AT_DURATION_END = TASK_TRIGGER_FLAG_KILL_AT_DURATION_END
        FLAG_DISABLED = TASK_TRIGGER_FLAG_DISABLED

        MAX_RUN_TIMES = TASK_MAX_RUN_TIMES

        FIRST = TASK_FIRST
        SECOND = TASK_SECOND
        THIRD = TASK_THIRD
        FOURTH = TASK_FOURTH
        FIFTH = TASK_FIFTH
        SIXTH = TASK_SIXTH
        SEVENTH = TASK_SEVENTH
        EIGHTH = TASK_EIGHTH
        NINETH = TASK_NINETH
        TENTH = TASK_TENTH
        ELEVENTH = TASK_ELEVENTH
        TWELFTH = TASK_TWELFTH
        THIRTEENTH = TASK_THIRTEENTH
        FOURTEENTH = TASK_FOURTEENTH
        FIFTEENTH = TASK_FIFTEENTH
        SIXTEENTH = TASK_SIXTEENTH
        SEVENTEENTH = TASK_SEVENTEENTH
        EIGHTEENTH = TASK_EIGHTEENTH
        NINETEENTH = TASK_NINETEENTH
        TWENTIETH = TASK_TWENTIETH
        TWENTY_FIRST = TASK_TWENTY_FIRST
        TWENTY_SECOND = TASK_TWENTY_SECOND
        TWENTY_THIRD = TASK_TWENTY_THIRD
        TWENTY_FOURTH = TASK_TWENTY_FOURTH
        TWENTY_FIFTH = TASK_TWENTY_FIFTH
        TWENTY_SIXTH = TASK_TWENTY_SIXTH
        TWENTY_SEVENTH = TASK_TWENTY_SEVENTH
        TWENTY_EIGHTH = TASK_TWENTY_EIGHTH
        TWENTY_NINTH = TASK_TWENTY_NINTH
        THIRTYETH = TASK_THIRTYETH
        THIRTY_FIRST = TASK_THIRTY_FIRST
        LAST = TASK_LAST
      end
    end
  end
end

begin
  require 'win32/taskscheduler'
rescue LoadError
  module Win32
    TaskScheduler = RSpec::Puppet::Win32::TaskScheduler
  end
end
