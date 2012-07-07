require 'securerandom'
require 'observer'
require 'thread'
require 'erb'
require 'mutex_m'

class ChatsController < ApplicationController
  include ERB::Util

  class Room
    include Observable
    include Mutex_m

    def add_observer(*args)
      synchronize { super }
    end

    def delete_observer(*args)
      synchronize { super }
    end

    def say who, msg
      synchronize do
        changed
        notify_observers('event' => 'say', 'who' => who, 'msg' => msg)
      end
    end

    def nick from, to
      synchronize do
        changed
        notify_observers('event' => 'nick', 'from' => from, 'to' => to)
      end
    end
  end

  ROOM = Room.new

  def show
    session[:id] ||= SecureRandom.urlsafe_base64
    session[:name] ||= session[:id]


    respond_to do |format|
      format.html
      format.json {
        begin
          queue = Queue.new
          ROOM.add_observer queue, :push

          stream = response.stream

          response.headers['Content-Type'] = 'text/event-stream'
          stream.write "retry: 10\n"
          stream.write "event: join\n"
          stream.write "data: #{JSON.dump({'who' => session[:name]})}\n\n"

          while event = queue.pop
            event_name = event.delete('event')
            stream.write "event: #{event_name}\n"
            stream.write "data: #{JSON.dump(event)}\n\n"
          end
        ensure
          # When (or if) the socket disconnects, remove the observer and close
          ROOM.delete_observer queue
          response.stream.close
        end
      }
    end
  end

  def create
    if params[:message] =~ /\A\/nick\s(\w+)/
      old = session[:name]
      session[:name] = $1
      ROOM.nick h(old), h(session[:name])
    else
      ROOM.say h(session[:name]), h(params[:message])
    end

    render :nothing => true
  end
end
