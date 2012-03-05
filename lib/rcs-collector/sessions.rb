#
#  Session Manager, manages all the cookies
#

require_relative 'evidence_manager'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'uuidtools'

module RCS
module Collector

class SessionManager
  include Singleton
  include RCS::Tracer

  def initialize
    @sessions = {}
  end

  def create(bid, ident, instance, subtype, k)

    # create a new random cookie
    #cookie = SecureRandom.random_bytes(8).unpack('H*').first
    cookie = UUIDTools::UUID.random_create.to_s

    # backward compatibility fix because symbian 7.x has an internal buffer of 32 chars
    # Giovanna owes me a beer... :)
    cookie = cookie.slice(0..31) if subtype == 'symbian'

    # store the sessions
    @sessions[cookie] = {:bid => bid,
                         :ident => ident,
                         :instance => instance,
                         :subtype => subtype,
                         :key => k,
                         :cookie => cookie,
                         :time => Time.now,
                         :count => 0,
                         :total => 0}

    return cookie
  end

  def check(cookie)
    return false if @sessions[cookie].nil?

    # update the time of the session (to avoid timeout)
    @sessions[cookie][:time] = Time.now

    return true
  end

  def get(cookie)
    return @sessions[cookie]
  end

  def delete(cookie)
    @sessions.delete(cookie)
  end

  # default timeout is 2 hours
  # this timeout is calculated from the last time the cookie was
  # checked, it will fail during a sync only if a request (i.e. log transfer)
  # takes more than 2 hours
  def timeout(delta = 7200)
    trace :debug, "Session Manager timing out entries..." if @sessions.length > 0
    # save the size of the hash before deletion
    size = @sessions.length
    # search for timed out sessions
    @sessions.each_pair do |key, sess|
      if Time.now - sess[:time] >= delta then
        trace :info, "Session Timeout for [#{sess[:cookie]}]"
        
        # update the status accordingly
        DB.instance.sync_timeout sess
        EvidenceManager.instance.sync_timeout sess

        # delete the entry
        @sessions.delete key
      end
    end
    trace :info, "Session Manager timed out #{size - @sessions.length} sessions" if size - @sessions.length > 0
  end

  def length
    return @sessions.length
  end
end #SessionManager

end #Collector::
end #RCS::