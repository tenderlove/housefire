require 'securerandom'
require 'observer'
require 'thread'
require 'erb'

class ChatsController < ApplicationController
  include ERB::Util

  class Room
    include Observable

    def say event
      changed
      notify_observers(event)
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

          response.headers['Content-Type'] = 'text/event-stream'
          while event = queue.pop
            response.stream.write "retry: 100\n"
            response.stream.write "data: #{JSON.dump(event)}\n\n"
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
      ROOM.say('from' => h(old), 'to' => h(session[:name]))
    else
      ROOM.say('who' => h(session[:name]), 'msg' => h(params[:message]))
    end

    render :nothing => true
  end
end
