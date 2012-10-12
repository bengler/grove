# A daemon to keep synchronize security settings from Checkpoint

class SecurityListenerDaemon < Servolux::Server
  NAME = "grove_security_listener"
  def initialize(opts)
    @listener = nil
    super(NAME, opts)
  end

  def before_starting
    @listener = Pebblebed::Security::Listener.new(:app_name => NAME)
    @listener.on_subtree_declared do |event|
      logger.info "Allowing group #{event[:group_id]} privileged access to #{event[:location]}"
      GroupLocation.allow_subtree(event[:group_id], event[:location])
    end
    @listener.on_subtree_removed do |event|
      logger.info "Denying group #{event[:group_id]} privileged access to #{event[:location]}"
      GroupLocation.deny_subtree(event[:group_id], event[:location])
    end
    @listener.on_membership_declared do |event|
      logger.info "Group #{event[:group_id]} added member #{event[:identity_id]}"
      GroupMembership.declare!(event[:group_id], event[:identity_id])
    end
    @listener.on_membership_removed do |event|
      logger.info "Group #{event[:group_id]} removed member #{event[:identity_id]}"
      GroupMembership.remove!(event[:group_id], event[:identity_id])
    end
  end

  def after_starting
    logger.info 'Running'
  end

  def before_stopping
    return unless @listener
    @listener, listener = nil, @listener
    listener.stop
    Thread.pass  # allow the server thread to wind down
  end

  def after_stopping
    logger.info 'Stopped'
  end

  def run
    @listener.start
    sleep
  rescue StandardError => e
    if logger.respond_to?:exception
      logger.exception(e)
    else
      logger.error(e.inspect)
      logger.error(e.backtrace.join("\n"))
    end
  end
end
