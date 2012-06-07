require 'io/console'
require 'ward'

class WardCommand
  private_class_method :new 

  def self.run(args)
    command = new(args)
  end

  def initialize(args)
    exit(run(args))
  end

private
  def run(args)
    if args.length < 1
      usage
      return 1
    end

    begin
      handle_command(args)
    rescue => error
      puts error.message
      return 2
    end

    return 0
  end

  def handle_command(args)
    command = args[0]
    if command =~ /\Ahelp\z/i
      # TODO: Implement.
    end

    case command
      when /\A(set|new|add)\z/i
        args.shift
        set(args)

      when /\A(get|show)\z/i
        args.shift
        get(args)

      when /\A(del|delete|rm)\z/i
        args.shift
        delete(args)
    end
  end

  def set(args)
    opts = {}

    case args.length
      # ward new
      # ward set
      when 0
        opts.merge!(prompt_all())

      # ward set bar.com
      # ward set foo@bar.com
      when 1
        opts.merge!(parse_username_domain(args[0]))
        if opts[:username].nil?
          opts.merge!(prompt_password_username_nick())
        else
          opts.merge!(prompt_password_nick())
        end

      # ward set bar.com p4ssw0rd
      # ward set foo@bar.com p4ssw0rd
      when 2
        opts.merge!(parse_username_domain(args[0]))
        opts.merge!(:password => args[1])

      # ward set bar.com p4ssw0rd gmail
      # ward set foo@bar.com p4ssw0rd gmail
      when 3
        opts.merge!(parse_username_domain(args[0]))
        opts.merge!(:password => args[1], :nick => args[2])
    end

    ward = get_ward()
    created = ward.set(opts)

    if created
      print 'Created '
    else
      print 'Updated '
    end
    
    puts "password for #{format_id(opts)}."
  end

  def get(args)
    if args.length != 1
      raise 'Invalid argument.'
    end

    # ward get fb
    # ward get bar.com
    # ward get foo@bar.com
    id = parse_id(args[0])

    ward = get_ward()
    password = ward.get(id)

    if password.nil?
      puts "No password for #{format_id(id)}."
    else
      puts password
    end
  end

  def delete(args)
    if args.length != 1
      raise 'Invalid argument.'
    end

    # ward del fb
    # ward del bar.com
    # ward del foo@bar.com
    id = parse_id(args[0])

    ward = get_ward()
    deleted = ward.delete(id)

    if deleted
      puts "Deleted password for #{format_id(id)}."
    else
      puts "No password for #{format_id(id)}."
    end
  end

  def format_id(opts)
    return nil if opts.nil? || opts.empty?

    username = opts[:username]
    domain = opts[:domain]
    nick = opts[:nick]

    return nil if domain.nil? && nick.nil?

    if username.nil? && domain.nil?
      "#{nick}"
    else
      if username.nil?
        nick.nil? ? domain : "#{domain} (#{nick})"
      else
        nick.nil? ? "#{username}@#{domain}" : "#{username}@#{domain} (#{nick})"
      end
    end
  end

  def parse_id(string)
    opts = parse_username_domain(string)
    if opts[:domain] =~ /\./
      opts
    else
      { :nick => opts[:domain] }
    end
  end

  def parse_username_domain(string)
    opts = {}

    if string =~ /@/
      parts = string.split('@')
      opts[:username], opts[:domain] = parts.map(&:strip)
    else
      opts[:domain] = string.strip
    end

    return opts
  end

  def prompt_all
    {}.merge!(prompt_domain())
      .merge!(prompt_password())
      .merge!(prompt_username())
      .merge!(prompt_nick())
  end

  def prompt_password_username_nick
    {}.merge!(prompt_password())
      .merge!(prompt_username())
      .merge!(prompt_nick())
  end

  def prompt_password_nick
    {}.merge!(prompt_password())
      .merge!(prompt_nick())
  end

  def prompt_domain
    print 'Domain: '
    { :domain => $stdin.gets.strip }
  end

  def prompt_password
    begin
      print 'Password: '
      password = get_password()

      print 'Password (verify): '
      verify = get_password()

      if verify != password
        puts 'Passwords do not match.'
        raise
      end
    rescue
      retry
    end

    { :password => password }
  end

  def prompt_username
    print 'Username (optional): '
    username = $stdin.gets.strip
    if !username.empty?
      { :username => username }
    else
      {}
    end
  end

  def prompt_nick
    print 'Alias (optional): '
    nick = $stdin.gets.strip
    if !nick.empty?
      { :nick => nick }
    else
      {}
    end
  end

  def get_password
    $stdin.noecho { |stdin|
      password = stdin.gets.sub(/[\r\n]+\z/, '')
      puts

      return password
    }
  end

  def get_ward
    begin
      print 'Master password: '
      master_password = get_password()
      ward = Ward.new(store_filename(), master_password)
    rescue MasterPasswordError
      puts 'Incorrect master password.'
      retry
    end

    return ward
  end

  def usage
    $stderr.puts $usage
  end

  def store_filename
    File.join(Dir.home, '.ward')
  end

  # TODO: Fix
  $usage = <<USAGE
  Usage: ward <command> [options]
    
    ward new
    ward set
    ward get
    ward del
    ward help
USAGE

end